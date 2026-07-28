# End-to-End Capstone — production-grade version

A complete, git-driven application stack that mimics a **real production setup** so
you can see all the moving parts in one place. It's the more advanced sibling of the
simple [Week 4, Day 5 capstone](../../../docs/week-04/day-26.md): where that one runs
everything on a single EC2 with docker-compose, this one adds a **VPC, an ALB with
HTTP→HTTPS and a real ACM certificate, three EC2 instances, ECR, SSM Parameter Store,
reusable Terraform modules, dev/prod environments, and a fully gated CI/CD pipeline**.

> **Educational, not turn-key.** The point is the *shape* of a production system. It
> stands up real, billable AWS resources — there's a teardown at the end. Run it.

## Architecture

```text
                          Internet
                             │  https://app.<env>.example.com
                             ▼
              ┌───────────────────────────────────────────────┐
              │                 VPC (10.0.0.0/16)              │
              │                                                │
              │   public-a (AZ-a) ┌─────────┐ public-b (AZ-b) │
              │      NAT ◀─────────│   ALB   │────────┐        │
              │                    │ :80→:443│        │        │
              │                    └────┬────┘  (spans 2 AZs)  │
              │                         │ :443 ACM cert        │
              │   ─────────────────────┼──────────────────────│
              │   private-a (AZ-a)      │      private-b (AZ-b)│
              │            ┌────────────┴───────────┐  (spare) │
              │            ▼                        ▼          │
              │      ┌──────────┐             ┌──────────┐     │
              │      │  app-0   │             │  app-1   │     │
              │      │ nginx:80 │             │ nginx:80 │     │
              │      │  + node  │             │  + node  │     │
              │      └────┬─────┘             └────┬─────┘     │
              │           └──────────┬─────────────┘          │
              │                      ▼ :5432                   │
              │                ┌──────────┐                   │
              │                │    db    │  postgres:16      │
              │                │ (1 inst) │  named volume     │
              │                └──────────┘                   │
              └───────────────────────────────────────────────┘

  Images: ECR   ·   DB secret: SSM Parameter Store   ·   Access: SSM (no SSH)
```

- **2 app instances** — each runs `frontend` (nginx serving the UI, proxying `/api`)
  + `backend` (Node/Express) as containers. The ALB load-balances across them.
- **1 db instance** — a dedicated Postgres container. Both app instances share it, so
  there's no split-brain. (A real system would use **RDS** here — see *Next steps*.)
- **All three instances are private** (no public IP, no SSH). Management is over **AWS
  SSM Session Manager**; the ALB is the only public entry point.

> **Single-AZ compute, on purpose.** The ALB requires two AZs, so the VPC has public +
> private subnets in two AZs, but all three instances live in `private-a`. Spreading
> them across AZs is a one-line change (`private_subnet_ids[1]`) left as an exercise.

## Repository layout

```
end-to-end/
├── docker-compose.yml      # LOCAL DEV: run the whole app on your laptop
├── frontend/               # static UI + nginx.conf + Dockerfile
├── backend/                # Node/Express API + tests + Dockerfile
├── db/init.sql             # schema + seed
├── terraform/
│   ├── modules/            # vpc · security-groups · ecr · acm · alb · ec2
│   └── envs/{dev,prod}/     # wire the modules; own state key + tfvars per env
├── ansible/
│   ├── inventory/*.aws_ec2.yml   # dynamic inventory by tag (per env)
│   └── roles/{common,database,app}/
└── .github/workflows/
    ├── backend-ci.yml      # paths: backend/**   → lint · test · build
    ├── frontend-ci.yml     # paths: frontend/**  → build · nginx -t
    ├── terraform-ci.yml    # paths: terraform/** → fmt · validate · plan (PR)
    ├── ansible-ci.yml      # paths: ansible/**   → ansible-lint · syntax-check
    └── cd.yml              # merge→dev, or "Run workflow" to pick env; tf apply → push ECR → ansible
```

Each CI workflow is **path-scoped**, so a frontend-only PR runs only `frontend-ci`,
a Terraform-only PR runs only `terraform-ci`, and so on — not every job every time.
None of them push images or touch AWS state; that's exclusively `cd.yml`, which only
runs on merge to `main`.

## Run it locally (no AWS needed)

The whole app on your machine — the fastest way to see it work:

```bash
cp .env.example .env
docker compose up --build
# open http://localhost:8080  → add an item, watch it persist
curl localhost:8080/api/healthz     # {"status":"ok","db":"up"}
```

Backend checks on their own:

```bash
cd backend && npm ci && npm run lint && npm test
```

## How a change ships (git → live)

1. **Open a PR.** Only the CI workflows for what you touched run (thanks to `paths`
   filters): `backend-ci` (lint+test+build), `frontend-ci` (build + `nginx -t`),
   `terraform-ci` (validate + `plan` for dev *and* prod), `ansible-ci` (lint +
   syntax-check). The plan shows exactly what would change. **No images are pushed.**
2. **Merge to `main`.** `cd.yml` auto-deploys **dev** (the single `deploy` job, with
   `environment=dev`, image tag = commit SHA):
   - `terraform apply` provisions/updates the VPC, ALB, ACM, ECR, SSM, and instances.
   - images are built and **pushed to ECR** (tagged with the commit SHA).
   - **Ansible** connects to the instances over SSM and deploys the containers —
     pulling images from ECR (via each instance's IAM role) and reading the DB
     password from **SSM Parameter Store**.
3. **Ship to prod on demand.** Actions → **CD** → **Run workflow** → pick
   `environment: prod` (and optionally an `image_tag` to promote a specific build).
   The same job runs against `envs/prod`, but because the job's `environment` resolves
   to the protected **`prod`** GitHub Environment, it **waits for a required reviewer**
   before anything is applied.
4. Visit `https://app.<env>.example.com` — the ALB terminates TLS and routes to an app
   instance; the frontend calls `/api/items`; the backend reads/writes Postgres.
   **You never opened a terminal or touched a server.**

## Before it will run (prerequisites)

Fill in every `CHANGEME`. You need, once per AWS account:

| What | Where | Notes |
|------|-------|-------|
| **S3 state bucket** | `terraform/envs/*/backend.tf` | Reuse the Week 3 bucket. Separate state key per env. |
| **OIDC role** | `.github/workflows/*` (`ROLE_ARN`) | Trust this repo; allow EC2/VPC/ALB/ACM/ECR/SSM + the state bucket + `ssm:GetParameter` on `/end-to-end/*` + `kms:Decrypt` for SecureString. |
| **Route53 hosted zone** | `terraform/envs/*/terraform.tfvars` | Set `hosted_zone_name` + `app_domain`. The zone must already exist; Terraform creates the ACM cert, DNS validation, and the alias record. |
| **SSM transfer bucket** | `cd.yml` (`SSM_BUCKET`), `ansible/group_vars/all.yml` | An S3 bucket the Ansible SSM connection uses to shuttle files. Reuse the state bucket. |
| **`prod` environment** | GitHub repo settings | Create an Environment named `prod` with a required reviewer — the CD job's `environment: prod` trips this gate. (`dev` can stay unprotected.) |

The **DB password is never entered anywhere** — Terraform generates it (`random_password`)
and stores it in SSM as a `SecureString`; Ansible reads it at deploy time.

## Deploy / operate manually

CI/CD is the intended path, but you can drive it by hand:

```bash
# provision
cd terraform/envs/dev && terraform init && terraform apply

# build + push images (registry URL comes from a TF output)
REG=$(terraform output -raw backend_ecr_url); REG=${REG%%/*}
aws ecr get-login-password | docker login --username AWS --password-stdin "$REG"
# ...docker build/push backend + frontend...

# deploy the containers over SSM
cd ../../../ansible
ansible-galaxy collection install -r requirements.yml
ansible-playbook -i inventory/dev.aws_ec2.yml site.yml \
  -e env_name=dev -e ecr_registry="$REG" -e image_tag=latest \
  -e ansible_aws_ssm_bucket_name=<your-bucket>
```

Runbook:

- **Roll back** — `git revert` the commit and merge; the pipeline re-applies the prior state.
- **Redeploy only** — re-run `cd.yml` (Terraform is a no-op if infra is unchanged).
- **Reconcile drift** — stop a container or delete an instance, then re-run the pipeline;
  Terraform recreates missing infra and Ansible redeploys.

## Teardown (do this to stop billing)

```bash
cd terraform/envs/prod && terraform destroy   # if you deployed prod
cd ../dev && terraform destroy
```

The NAT gateway, ALB, and EC2 instances bill by the hour — **destroy when you're done.**

## Security caveats (what a real system would harden)

This is deliberately a *starting point*. Before it's production-ready you'd want to:

- Move Postgres to **RDS** (backups, HA, patching) instead of a single EC2.
- Spread instances across **both AZs** and add an Auto Scaling Group.
- Add **WAF** on the ALB, VPC endpoints for ECR/SSM (drop the NAT), and stricter SG egress.
- Scan images and IaC (Trivy, `tfsec`) in CI, and pin base images by digest.

These are exactly the themes of [Day 7 · Security Best Practices](../../../docs/week-04/day-28.md).

## Next steps / advanced

- **Build once, promote** — instead of per-env ECR + rebuild, build one image and promote
  the same digest dev → prod.
- **Pull-based GitOps** — Argo CD / Flux (Kubernetes-native, continuous reconciliation).
- **Monitoring** — layer on Prometheus/Loki/Grafana as in [Day 6](../../../docs/week-04/day-27.md).
