# Day 5 · The End-to-End Project — Bootstrap App & Infra

> The individual CI/CD pieces — tests, images, Terraform, Ansible — converge here into **the project** you'll put on your résumé: a real **three-tier app** (frontend · backend · Postgres) running on **production-shaped AWS** — a VPC, an ALB with HTTPS, ECR, and a small fleet of EC2 — provisioned by **Terraform**, deployed by **Ansible**, and driven entirely from **GitHub Actions**. No `terraform apply` from your laptop; you **bootstrap the whole thing from the pipeline**.

!!! info "One repo, the whole system"
    App code + infrastructure code + configuration code + pipelines, together in one repo. Set a few secrets, then **run one workflow** — it provisions the infra, builds and pushes the images, and deploys the containers. That's the end-to-end project.

!!! danger "This builds real, billable AWS resources"
    A VPC, an ALB, and several EC2 instances — billable beyond the free tier. There's a **teardown** at the end; run it when you're done.

The complete, runnable project is the reference for this whole day:
[`examples/demo-app`](https://github.com/rbalman/devops-month/tree/main/examples/demo-app). Its `README`
has the exact commands; this page is the walkthrough of **what it is and how to bootstrap it**.

## Learning Objectives

- Lay out an **end-to-end repo**: app, infrastructure, configuration, and pipelines together
- Read the **production-shaped architecture** — VPC + ALB (HTTP→HTTPS, ACM) + ECR + EC2, reusable Terraform **modules** with **dev/prod** environments
- **Bootstrap** the system from nothing: one-time AWS setup → GitHub secrets/variables/environment → run the pipeline
- Provision infra with **Terraform** and deploy containers with **Ansible** — all from **GitHub Actions**, keyless via **OIDC** (no local applies)
- **Lab:** stand up the whole app end to end and reach it over **HTTPS**

---

## Prerequisites

- **Days 1–4 complete** — CI, images pushed to a registry, Terraform-in-CI (incl. the **OIDC role**), Ansible-in-CI
- An **S3 bucket** for Terraform state (Week 3), a **Route53 hosted zone** for a domain you own, and an **EC2 key pair**
- The reference project: [`examples/demo-app`](https://github.com/rbalman/devops-month/tree/main/examples/demo-app)

---

## Theory · ~25 min

### 1. Meet the architecture

Three tiers on production-shaped infrastructure — not one box, but the moving parts a real deployment has:

```text
                 Internet
                    │ https://<app_domain>
                    ▼
          ALB  :80 → :443 (ACM)              ← public subnets, 2 AZs
            ├─────────────┬─────────────
            ▼             ▼
      app-instance-1  app-instance-2         ← nginx :80 ──/api──▶ backend :3000
       (public-a)      (public-b)              one app node per AZ
            └──────┬──────┘
                   ▼ :5432
             db-instance                     ← postgres:16 (shared by both app nodes)

  Images: ECR · DB creds: SSM Parameter Store · Deploy: SSH
```

- **frontend** — nginx serving the static UI and proxying `/api` to the backend.
- **backend** — the Node/Express API from Day 1, reading its DB connection from the environment.
- **postgres** — a dedicated Postgres container on its own instance, shared by both app nodes.
- Two **app instances** sit behind an **ALB** (one per AZ) that terminates **TLS** with an **ACM** certificate; images come from **ECR**; the DB password lives in **SSM Parameter Store**.

!!! note "Why this shape?"
    It's the smallest layout that still has the real pieces — a load balancer, HTTPS, multiple nodes, a registry, managed secrets. A production system would go further (RDS, private subnets, autoscaling); those are the [Security](day-28.md) day and the *Advanced Topics* below.

### 2. One repo, four kinds of code

```text
demo-app/
├── frontend/  backend/  db/        # the app (+ db/init.sql schema)
├── terraform/
│   ├── modules/                    # vpc · ecr · acm · alb · ec2
│   └── envs/{dev,prod}/            # wire the modules; own state key + tfvars
├── ansible/                        # roles that deploy the containers over SSH
└── .github/workflows/              # backend-ci · frontend-ci · terraform-ci · ansible-ci · cd
```

App code, infrastructure code, configuration code, **and** the pipelines that ship them — versioned together. Reusable **modules** are consumed by per-environment folders (`dev`, `prod`), each with its own state and sizing.

### 3. How it's driven — CI and the deploy stages

**CI** runs on PRs, **path-scoped**: `backend-ci`, `frontend-ci`, `terraform-ci`, `ansible-ci` — lint, test, build, `terraform validate/plan`, `ansible-lint`. A frontend-only PR runs only `frontend-ci`.

**The deploy is three workflows you run manually, in order:**

| Stage | Workflow | Does |
|---|---|---|
| 1 | **`deploy-infra`** | `terraform apply` — provisions the VPC, ALB, **ECR**, SSM, EC2 |
| 2 | **`backend-ci` / `frontend-ci`** | build & push the images to ECR |
| 3 | **`deploy-app`** | `ansible` — pulls the images and runs the containers over SSH |

Everything authenticates to AWS with **OIDC** — a short-lived token per run, **no stored keys**. Region and the role ARN are **repo variables** (set once); DB creds and the SSH key are **secrets**. Prod is gated by a GitHub **Environment** with a required reviewer.

### 4. Bootstrapping order — why three stages

There's a chicken-and-egg: images can't be pushed until **ECR exists**, and Ansible can't deploy until the **images exist** and the **instances are up**. So the order is fixed:

```text
terraform apply   →   build + push images (ECR)   →   ansible deploy (SSH)
   (infra)                 (registry has tags)            (containers run)
```

Keeping the three as **separate workflows** makes that order explicit — and lets you re-run just one stage (redeploy without re-provisioning, say).

---

## Lab · ~50 min — bootstrap the demo-app

You'll stand up the entire app from an empty repo. The [`demo-app` README](https://github.com/rbalman/devops-month/tree/main/examples/demo-app) has the exact commands for each step; here's the shape of it.

!!! important "Reuse what you built in Days 1–4"
    Terraform state goes in your **S3 bucket**; AWS auth uses the **OIDC role** for this repo. Same building blocks — now wired into one project.

### 1. One-time AWS setup

Create these once (per account): an **S3 bucket** for state · a **Route53 hosted zone** for your domain · an **EC2 key pair** · a **GitHub OIDC role**.

!!! warning "OIDC role permissions"
    For the demo, attach **`AdministratorAccess`** to the role — simplest, and it just works. **Don't do this for a production app** — it's wildly over-privileged; scope it to only the services it uses.

### 2. Put the project in your own repo

Create a new empty repo on GitHub, then copy the example into it (workflows must sit at the repo **root**):

```bash
git clone https://github.com/rbalman/devops-month.git
cp -R devops-month/examples/demo-app demo-app && cd demo-app
# then init it as a git repo and set 'origin' to your new repo
```

### 3. Set up GitHub for the pipeline

In your new repo's **Settings**:

- **Environments** → create **`prod`** with a **required reviewer** (the approval gate; `dev` needs none).
- **Secrets and variables → Actions** → add repo-level:
  **variables** `AWS_REGION`, `AWS_ROLE_ARN`; **secrets** `SSH_PRIVATE_KEY`, `DB_USERNAME`, `DB_PASSWORD`.

### 4. Point Terraform at your account, then push

Edit `terraform/envs/<env>/`: `backend.tf` → your state **bucket**; `terraform.tfvars` → `hosted_zone_name`, `app_domain`, `key_name`. Commit and push.

### 5. Run the three deploy stages

Under **Actions → Run workflow → `dev`**, in order — **no local commands**:

1. **`Deploy Infra`** — `terraform apply` stands up the VPC, ALB, ECR, SSM, and EC2.
2. **`Backend`** + **`Frontend`** — build & push the images to the ECR repos it just created.
3. **`Deploy App`** — Ansible finds the instances, pulls the images, and runs the containers.

### 6. See it live

Open **`https://<app_domain>`** — the frontend loads, `/api/items` reaches the backend, and the backend reads/writes Postgres. TLS is terminated at the ALB with your ACM cert.

### 7. Ship to prod

Run the same three workflows with `environment: prod` — the **Deploy Infra** and **Deploy App** stages each **pause for your reviewer's approval** before running.

!!! success "This is your capstone"
    A complete application — frontend, backend, database — on real AWS infrastructure, provisioned by Terraform and deployed in containers by Ansible, **all from one pipeline you triggered**. Day 6 adds monitoring; Day 7 hardens it. Keep this repo; it's your portfolio centerpiece.

!!! danger "Teardown"
    ```bash
    cd terraform/envs/dev && terraform destroy   # and envs/prod if you deployed it
    ```
    The ALB and EC2 bill hourly — **destroy when you're done** (keep it if you're going straight to Day 6).

---

## Advanced Topics

- **Managed database** — swap the Postgres-on-EC2 for **RDS** when you need backups/HA → [RDS module](https://registry.terraform.io/modules/terraform-aws-modules/rds/aws/latest)
- **Private subnets + bastion/SSM** — take the instances off the public internet and tighten SSH
- **Autoscaling** — replace fixed instances with an **Auto Scaling Group** across AZs
- **Build once, promote** — build an image once and promote the same digest `dev → prod`
- **Pull-based GitOps** — once you learn Kubernetes, **Argo CD**/**Flux** reconcile git → cluster continuously → [Argo CD](https://argo-cd.readthedocs.io/) · [Flux](https://fluxcd.io/)

---

## Assignment — the capstone deliverable

Ship the end-to-end project and document it as a portfolio piece.

**What must work:**

1. **Your own repo** with `frontend/`, `backend/`, `db/`, `terraform/`, `ansible/`, and the workflows — no secrets committed.
2. A green **CD run** provisions the infra (OIDC, no stored keys), pushes the images to ECR, and deploys all three containers — **no local commands**.
3. **`https://<app_domain>`** serves the frontend; `/api/items` reaches the backend; the backend **reads/writes Postgres**.
4. **Destroy + rebuild** reproduces the whole app from the repo.

**Document** in your `README.md`: an architecture diagram (redraw the one above), a "how it works" trace from *Run workflow* to live, and a runbook (deploy / roll back / tear down).

**Submit:** repo link, a green CD run (all steps), screenshots of the app over HTTPS and a successful destroy→rebuild, and a ½-page write-up of **what broke and how you debugged it**.

---

## Further Reading

**Reference**

- [Automate Terraform with GitHub Actions](https://developer.hashicorp.com/terraform/tutorials/automation/github-actions) · [Configuring OpenID Connect in AWS](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-aws)
- [`community.docker.docker_compose_v2`](https://docs.ansible.com/ansible/latest/collections/community/docker/docker_compose_v2_module.html) · [Postgres Docker image](https://hub.docker.com/_/postgres)
- [The Twelve-Factor App](https://12factor.net/) — the config/deploy principles behind this design
