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
      app-instance-1  app-instance-2         ← nginx :80  ──/api──▶ backend :3000
            └──────┬──────┘
                   ▼ :5432
             db-instance                     ← postgres:16 (shared by both app nodes)

  Images: ECR · DB creds: SSM Parameter Store · Deploy: SSH · public instances, no NAT
```

- **2 app instances** behind the ALB, each running `frontend` + `backend` containers.
- **1 db instance** running Postgres, shared by both app nodes (a real system would use **RDS**).
- Single-AZ compute on purpose — the ALB just needs two AZs; instances sit in `public-a`.

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

## Deploy to AWS — step by step

**One-time AWS setup** (per account): an **S3 bucket** for Terraform state · a **Route53 hosted
zone** for your domain · an **EC2 key pair** · an **OIDC IAM role** GitHub can assume
([guide](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-aws)),
allowing EC2/VPC/ALB/ACM/ECR + the state bucket + `ssm:GetParameter` on `/demo-app/*` + `kms:Decrypt`.

1. **Copy this folder into a fresh GitHub repo** — workflows must sit at the repo **root**.

2. **Add GitHub variables + secrets** (Settings → Secrets and variables → Actions), and create
   a **`prod` Environment** with a required reviewer (gates prod deploys):

   | Variables | Secrets |
   |-----------|---------|
   | `AWS_REGION` — e.g. `us-east-1` | `SSH_PRIVATE_KEY` — matches the key pair |
   | `AWS_ROLE_ARN` — the OIDC role ARN | `DB_USERNAME`, `DB_PASSWORD` |

3. **Point Terraform at your account** in `terraform/envs/<env>/`:
   `backend.tf` → S3 `bucket`; `terraform.tfvars` → `hosted_zone_name`, `app_domain`, `key_name`.

4. **Provision the base infra** (VPC, ALB, ACM, ECR, SSM, EC2):

   ```bash
   cd terraform/envs/dev
   export TF_VAR_db_username=appuser TF_VAR_db_password=<pick-one>
   terraform init && terraform apply
   ```

5. **Build + push the images** to the ECR repos Terraform just created:

   ```bash
   REG=$(terraform output -raw backend_ecr_url); REG=${REG%%/*}
   aws ecr get-login-password | docker login --username AWS --password-stdin "$REG"
   docker build -t "$REG/demo-app-dev-backend:latest"  ../../../backend  && docker push "$REG/demo-app-dev-backend:latest"
   docker build -t "$REG/demo-app-dev-frontend:latest" ../../../frontend && docker push "$REG/demo-app-dev-frontend:latest"
   ```

6. **Deploy the containers** with Ansible, over SSH:

   ```bash
   cd ../../../ansible && ansible-galaxy collection install -r requirements.yml
   ansible-playbook -i inventory/dev.aws_ec2.yml site.yml \
     --private-key ~/.ssh/<your-key>.pem \
     -e env_name=dev -e ecr_registry="$REG" -e image_tag=latest
   ```

7. **Open `https://<app_domain>`** — the frontend loads and `/api/items` reads/writes Postgres.

> **Or let CI/CD do steps 4–6:** push to `main` → `cd.yml` deploys **dev** automatically; run the
> **CD** workflow and pick `prod` for the gated prod deploy.

## Teardown

```bash
cd terraform/envs/dev && terraform destroy    # and envs/prod if you deployed it
```

The ALB + EC2 bill hourly — **destroy when done.**

## Hardening (what a real system adds)

RDS instead of db-on-EC2 · instances in **private subnets** (bastion/SSM) with `ssh_ingress_cidr`
tightened from `0.0.0.0/0` · both AZs + an ASG · WAF on the ALB · image/IaC scanning (Trivy, `tfsec`).
See [Day 7 · Security Best Practices](../../../docs/week-04/day-28.md).
