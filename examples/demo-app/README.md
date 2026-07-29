# Demo App — production-grade AWS reference

A tiny 3-tier app — static **frontend** (nginx) → **backend** (Node/Express) → **Postgres** —
wired up the way a real system is: **VPC + ALB (HTTP→HTTPS, ACM) + ECR + 3 EC2**, built from
**reusable Terraform modules** (dev/prod), deployed as containers by **Ansible over SSH**, and
driven by **GitHub Actions** with keyless **OIDC**.

> Educational — it stands up real, **billable** AWS resources. There's a teardown at the end; run it.

## Architecture

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
             db-instance                     ← postgres:16 (public-a; shared by both app nodes)

  Images: ECR · DB creds: GitHub secrets → Ansible · Deploy: SSH · public instances, no NAT
```

- **2 app instances** behind the ALB, **one per AZ** (public-a / public-b), each running
  `frontend` + `backend` containers.
- **1 db instance** running Postgres in public-a, shared by both app nodes (a real system
  would use **RDS**).

## Layout

```
demo-app/
├── docker-compose.yml   # local dev (all three containers)
├── frontend/  backend/  db/init.sql
├── terraform/{modules,envs/{dev,prod}}   # each security group lives with its resource
├── ansible/{inventory,roles/{common,database,app}}
└── .github/workflows/   # backend-ci · frontend-ci · terraform-ci · ansible-ci · infra · deploy
```

CI is **path-scoped** (a frontend PR runs only `frontend-ci`, etc.). The deploy is **three
separate stages** you run in order: **`deploy-infra`** (Terraform) → **`backend-ci`/`frontend-ci`**
(build & push images to ECR) → **`deploy-app`** (Ansible). Each is manual (*Run workflow*).

## Run locally (no AWS)

```bash
cp .env.example .env && docker compose up --build
# http://localhost:8080  →  add an item ;  curl localhost:8080/api/healthz
```

## Deploy to AWS

> ⚠️ **This spins up real, billable AWS resources.** Follow the [Teardown](#teardown) at the end.

### Prerequisites — create these once (per AWS account)

| # | What | How |
|---|------|-----|
| 1 | **S3 bucket** for Terraform state | `aws s3 mb s3://YOUR-tf-state-bucket` |
| 2 | **Route53 hosted zone** for a domain you own | usually already exists; otherwise create one in Route53 |
| 3 | **EC2 key pair** (SSH into the instances) | `aws ec2 create-key-pair --key-name demo-app --query KeyMaterial --output text > demo-app.pem && chmod 600 demo-app.pem` |
| 4 | **GitHub OIDC role** (keyless AWS auth) | follow the [official guide](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-aws) |

> 🔑 **OIDC role permissions.** Attach the AWS-managed **`AdministratorAccess`** policy — simplest, and it just works for this demo.
>
> ⚠️ **Don't do this for a production app.** `AdministratorAccess` is wildly over-privileged; scope the role down to only the services it actually uses.

### Steps

**1 · Put this project in its own repo** — the workflows must live at the repo **root**.

First **create a new empty repository on GitHub** (e.g. `demo-app`). Then copy this example out of
the course repo and wire it to yours:

```bash
git clone https://github.com/rbalman/devops-month.git
cp -R devops-month/examples/demo-app demo-app && cd demo-app
# then initialize it as a git repo and set 'origin' to your new GitHub repo
```

**2 · Set up GitHub for the pipeline** — all in your new repo's **Settings**:

- **Environments** → create one named **`prod`** with a **required reviewer**. This is the prod
  approval gate; `dev` needs no environment.
- **Secrets and variables → Actions** → add these **repository-level** entries (shared by dev & prod):

```bash
gh variable set AWS_REGION   --body "us-east-1"
gh variable set AWS_ROLE_ARN --body "arn:aws:iam::<account-id>:role/<oidc-role>"
gh secret   set SSH_PRIVATE_KEY < demo-app.pem
gh secret   set DB_USERNAME   --body "appuser"
gh secret   set DB_PASSWORD   --body "<pick-a-strong-password>"
```

**3 · Point Terraform at your account, then push.** Edit `terraform/envs/<env>/`:

- `backend.tf` → your S3 state `bucket`
- `terraform.tfvars` → `hosted_zone_name`, `app_domain`, `key_name`

Commit and push so your config + workflows land in the repo:

```bash
git add -A && git commit -m "configure demo-app" && git push -u origin main
```

Now deploy in **three ordered stages** — for each, go to the **Actions** tab, open the named
workflow, and click **Run workflow → `dev`**:

**4 · Provision the infra** — run the **Deploy Infra** workflow. It stands up the VPC, ALB, ACM,
**ECR**, and EC2. Must come first — the next stage pushes images into the ECR it creates.

**5 · Build & push the images** — run the **Backend** and **Frontend** workflows; their `build-push`
job publishes the images to ECR.

**6 · Deploy the app** — run the **Deploy App** workflow. Ansible finds the instances, pulls the
images from ECR, and starts the containers over SSH.

> 🚀 **Prod** runs the same workflows with **`prod`** — the infra and app stages each pause for a
> reviewer's approval first.

**7 · Open `https://<app_domain>`** 🎉 — the frontend loads and `/api/items` reads/writes Postgres.

## Teardown

```bash
cd terraform/envs/dev && terraform destroy    # and envs/prod if you deployed it
```

The ALB + EC2 bill hourly — **destroy when done.**

## Hardening (what a real system adds)

RDS instead of db-on-EC2 · instances in **private subnets** (bastion/SSM) with `ssh_ingress_cidr`
tightened from `0.0.0.0/0` · an Auto Scaling Group across AZs · WAF on the ALB · image/IaC
scanning (Trivy, `tfsec`).
See [Day 7 · Security Best Practices](../../docs/week-04/day-28.md).
