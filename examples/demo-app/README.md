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

  Images: ECR · DB creds: SSM Parameter Store · Deploy: SSH · public instances, no NAT
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
└── .github/workflows/   # backend-ci · frontend-ci · terraform-ci · ansible-ci · cd
```

CI is **path-scoped** (a frontend PR runs only `frontend-ci`, etc.). On merge to `main`,
`backend-ci`/`frontend-ci` build+push their image to ECR, and `cd.yml` provisions + deploys.

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
git init -b main && git add . && git commit -m "demo-app"
git remote add origin https://github.com/<you>/demo-app.git
```

**2 · Add the CI/CD config** — via the GitHub UI (*Settings → Secrets and variables → Actions*) or the CLI:

```bash
gh variable set AWS_REGION   --body "us-east-1"
gh variable set AWS_ROLE_ARN --body "arn:aws:iam::<account-id>:role/<oidc-role>"
gh secret   set SSH_PRIVATE_KEY < demo-app.pem
gh secret   set DB_USERNAME   --body "appuser"
gh secret   set DB_PASSWORD   --body "<pick-a-strong-password>"
```

> 🛡️ Also create a **`prod` Environment** (*Settings → Environments*) with a **required reviewer** —
> that's what makes prod deploys wait for approval.

**3 · Point Terraform at your account** — edit `terraform/envs/<env>/`:

- `backend.tf` → your S3 state `bucket`
- `terraform.tfvars` → `hosted_zone_name`, `app_domain`, `key_name`

**4 · Deploy with GitHub Actions** — no local `terraform`/`docker`/`ansible` needed. Push your
config, then run the **CD** workflow manually:

```bash
git commit -am "configure demo-app" && git push -u origin main
gh workflow run cd.yml -f environment=dev            # or: Actions → CD → Run workflow
```

CD runs the whole pipeline: `terraform apply` provisions the infra (VPC, ALB, ACM, ECR, SSM, EC2) →
the **frontend + backend images are built and pushed to ECR** → **Ansible** deploys the containers
over SSH. Follow it under the repo's **Actions** tab.

> 🚀 **Ship to prod:** same workflow with `environment=prod` — it waits for your reviewer to approve.

**5 · Open `https://<app_domain>`** 🎉 — the frontend loads and `/api/items` reads/writes Postgres.

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
