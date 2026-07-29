# Day 3 · Terraform in CI/CD — Automating IaC with GitHub Actions

> Running `terraform apply` from your laptop (Week 3) is fine to learn on, but it doesn't scale: whose laptop is the source of truth? Who reviewed the change? What if two people apply at once? Moving Terraform **into the pipeline** fixes all of that — the same `fmt → validate → plan → apply` flow, but run by GitHub Actions on a clean machine, reviewed like code, and authenticated to AWS with **no stored keys** via OIDC. The example is kept deliberately small: one tiny Terraform config, so the focus is the *automation*, not the infrastructure.

!!! info "Where this fits"
    This applies the CI/CD pattern to **Terraform**. Running **Ansible** from CI is covered in [Ansible in CI/CD](day-25.md), and [GitOps & the End-to-End Project](day-26.md) combines them to provision and deploy the whole app.

## Learning Objectives

- Explain **why** IaC belongs in a pipeline, not on developer laptops
- Authenticate GitHub Actions to AWS with **OIDC** — keyless, short-lived credentials
- Run the **`fmt → validate → plan → apply`** flow as a workflow
- Post the **plan on a pull request** and **apply on merge**
- **Lab:** a minimal Terraform config applied by GitHub Actions, end to end

---

## Prerequisites

- **Week 3 complete** — Terraform basics, the S3 remote backend (Day 21)
- An AWS account where you can create an **IAM OIDC provider + role**
- A **new, dedicated GitHub repo** for this lab (e.g. `terraform-ci`) — this day doesn't reuse the sample-app repo

---

## Theory · ~30 min

### 1. Why run Terraform in CI

Applying from a laptop has real problems that a pipeline fixes:

| Laptop apply | Pipeline apply |
|---|---|
| Whose state/version is authoritative? | One clean runner, pinned versions — reproducible |
| Changes land unreviewed | Every change is a **PR** with a visible `plan` |
| Long-lived AWS keys on many machines | **OIDC** — short-lived creds, nothing stored |
| Two applies can clash | Serialized runs + **state locking** (Day 21) |
| "It worked on mine" | Same environment every time |

The goal: **nobody runs `apply` locally.** Terraform changes flow through git like any other code.

### 2. The Terraform pipeline

The same four commands you already know, now as pipeline stages with a review gate in the middle:

```text
  PR opened ──▶ fmt -check ──▶ validate ──▶ plan ──▶ post plan as PR comment
                                                          │  (human reviews)
  merge to main ─────────────────────────────────▶ apply
```

- **`fmt -check`** fails if code isn't formatted — a cheap style gate.
- **`validate`** catches syntax/type errors before touching AWS.
- **`plan`** on the PR shows *exactly* what will change — reviewed before it's real.
- **`apply`** runs only after merge to `main`.

### 3. OIDC — keyless AWS auth (the proper setup)

!!! tip "📺 Watch — *Authenticate GitHub Actions with AWS Using OIDC — No Secrets Needed*"
    A hands-on walkthrough of exactly this setup — the IAM OIDC provider, the role, and its trust policy.

    [![Authenticate GitHub Actions with AWS Using OIDC](https://img.youtube.com/vi/Sdzd4N6L5Hg/hqdefault.jpg){ width="360" }](https://youtu.be/Sdzd4N6L5Hg)

Day 2 introduced OIDC; here's the full picture. You create two things in AWS **once**:

1. An **IAM OIDC identity provider** trusting `token.actions.githubusercontent.com`.
2. An **IAM role** whose *trust policy* allows your repo to assume it, with a *permissions policy* scoped to what Terraform manages.

The trust policy — note the `sub` condition pins it to **your repo** so no other repo can assume the role:

```json
{
  "Effect": "Allow",
  "Principal": { "Federated": "arn:aws:iam::<acct>:oidc-provider/token.actions.githubusercontent.com" },
  "Action": "sts:AssumeRoleWithWebIdentity",
  "Condition": {
    "StringEquals": { "token.actions.githubusercontent.com:aud": "sts.amazonaws.com" },
    "StringLike":  { "token.actions.githubusercontent.com:sub": "repo:<you>/terraform-ci:*" }
  }
}
```

At run time the workflow presents a signed token, AWS verifies it against the trust policy, and hands back a **15-minute** credential. No access keys ever exist to leak.

!!! tip "Scope the sub condition tighter in production"
    `repo:<you>/terraform-ci:*` allows any branch/PR. Real setups pin to a branch (`...:ref:refs/heads/main`) or an **environment** (`...:environment:production`) so only trusted contexts can touch AWS.

### 4. Remote state in CI is mandatory

A GitHub runner is **ephemeral** — it's destroyed after the job. Local state would vanish with it. So a CI-run config **must** use a remote backend (the **S3 backend** from Day 21) — that's where state lives between runs, and where locking prevents two runs clashing.

### 5. CI hygiene for Terraform

Small flags that matter in automation:

- **`-input=false`** — never prompt (there's no human at the terminal).
- **`-no-color`** — clean logs/PR comments.
- **`-auto-approve`** on apply — the review already happened on the PR.
- Save the plan (`-out=tfplan`) and apply *that exact plan* for true safety (see Advanced Topics).

---

## Lab · ~45 min

Automate a **tiny** Terraform config with GitHub Actions: `plan` on PRs, `apply` on merge, authenticated by OIDC. The infra is intentionally trivial — a single **EC2 instance** (a `t3.micro`, free-tier-eligible) — so all your attention is on the pipeline.

!!! note "Runnable version in the repo"
    The complete project is at [`examples/cicd/terraform-ci`](https://github.com/rbalman/devops-month/tree/main/examples/cicd/terraform-ci) — copy it into a fresh `terraform-ci` repo; the steps below walk through what's in it.

!!! important "Reuse your S3 backend"
    Use the state bucket from [Day 21, Section 3](../week-03/day-21.md#3-remote-backend-s3-the-modern-way). This config gets its own key: `ci-demo/terraform.tfstate`.

### 1. Create the OIDC role

In the AWS console (IAM → Identity providers → Add provider → OpenID Connect):

- Provider URL: `https://token.actions.githubusercontent.com`, Audience: `sts.amazonaws.com`.
- Then create a **role** for web identity using that provider, with the trust policy from [Section 3](#3-oidc-keyless-aws-auth-the-proper-setup) and a permissions policy allowing **EC2** (plus access to your state bucket).

Note the **role ARN**.

### 2. The Terraform config

This lab lives in its **own repo** — create an empty `terraform-ci` on github.com and clone it (don't reuse the sample-app repo). Copy the **`terraform/`** folder from the reference project — [`examples/cicd/terraform-ci/terraform/`](https://github.com/rbalman/devops-month/tree/main/examples/cicd/terraform-ci/terraform) — into it. It's a single `t3.micro` EC2 instance wired to the S3 backend; open **`terraform/main.tf`** and set the backend `bucket` to your state bucket (its key is `ci-demo/terraform.tfstate`).

!!! tip "Commit the lock file"
    After `terraform init`, commit the generated **`.terraform.lock.hcl`** — it pins the exact provider version so your machine and the CI runner resolve the same AWS provider. Only `.terraform/` and `*.tfstate` belong in `.gitignore`.

### 3. The workflow — plan on PR, apply on merge

Copy **`.github/workflows/terraform.yml`** from the same reference project — [`examples/cicd/terraform-ci/.github/workflows/`](https://github.com/rbalman/devops-month/tree/main/examples/cicd/terraform-ci/.github/workflows) — to your repo root, then set `role-to-assume` to the **role ARN** from step 1. On a PR it runs `init → fmt → validate → plan`; on merge to `main` it runs `apply`.

### 4. Run the full cycle

1. Commit on a branch, open a **PR**. The workflow runs `fmt`/`validate`/`plan` — expand the **Plan** step and read "1 to add."
2. **Merge.** The `apply` step runs and creates the instance. Confirm it in the EC2 console.
3. Change the instance's tags on another branch, open a PR — the plan now shows "1 to change." Merge to apply.

You just changed AWS infrastructure **without touching a terminal or storing a key** — every change reviewed as a PR.

### 5. Clean up

Add a **manual destroy** you can trigger from the UI — a `workflow_dispatch` workflow that runs `terraform destroy -auto-approve` — or just run it once locally to remove the instance. **An EC2 instance bills by the hour, so don't leave it running.**

!!! success "What you just built"
    A keyless, reviewable Terraform pipeline: PRs show the plan, merges apply it. The same pattern for **Ansible** is in [Ansible in CI/CD](day-25.md); [GitOps & the End-to-End Project](day-26.md) combines both.

---

## Advanced Topics

- **Save & apply the exact plan** — `plan -out=tfplan` as an artifact, `apply tfplan` on merge (no drift between plan and apply) → [Automate Terraform](https://developer.hashicorp.com/terraform/tutorials/automation/github-actions)
- **Post the plan as a PR comment** — render the diff inline with [`actions/github-script`](https://github.com/actions/github-script) or [`dflook/terraform-plan`](https://github.com/dflook/terraform-github-actions)
- **Scan the HCL** — `tflint` / `trivy config` / `checkov` as CI gates (tfsec merged into Trivy in 2024) → [`tflint`](https://github.com/terraform-linters/tflint) · [Trivy](https://trivy.dev/) · [Checkov](https://www.checkov.io/) — covered on [Day 7 · Security Best Practices](day-28.md)
- **Environments for apply** — require a reviewer before the apply job runs → [Using environments](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/manage-environments) (the [Day 2](day-23.md) pattern)
- **Matrix over environments** — one workflow that plans dev + prod in parallel → [Using a matrix](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/run-variations-of-jobs-in-a-workflow)

---

## Assignment

Build an **HTTPS web tier** with your own Terraform **modules** — two web servers behind a load balancer, served at `terraform.<your-domain>` over HTTPS — then deploy the app with **Ansible**. The one change from doing it by hand: **the pipeline runs it** — open a PR to see the `plan`, merge to `main` to `apply`, all authenticated by **OIDC** (no stored keys).

!!! danger "Heads-up: this costs money"
    An ALB (~$0.02–0.03/hr) and a Route 53 hosted zone ($0.50/mo) are billable — tear it all down when you're done (see **Clean up** below).

### Architecture

![HTTPS web tier: a browser reaches terraform.your-domain via a Route 53 record pointing at an internet-facing ALB with :80 and :443 listeners (443 using an ACM certificate), which forwards through a target group to two EC2 instances running nginx, each in a public subnet of the VPC; an Ansible control node configures both over SSH.](../week-03/images/day-20-architecture.png){ width="820" }

*Zoom in / open the image in a new tab if the labels are hard to read.*

### Infra to create

| # | Infra | Module | Details |
|---|---|---|---|
| 1 | 1 VPC + 2 public subnets | `vpc` | `10.0.0.0/16`, across 2 AZs |
| 2 | 2 EC2 + security group | `ec2` | Ubuntu 24.04, `t3.micro`, **SSH key pair** attached; SG allows **22** from your IP, **80** from the ALB |
| 3 | 1 ALB + target group + 2 listeners | `alb` | in the public subnets; **:443** HTTPS (ACM cert) → TG, **:80** → redirect to :443; TG **:80** → both EC2 |
| 4 | Hosted zone + ACM cert + DNS record | `hostedzone` | zone for `<your-domain>`; ACM cert for `terraform.<your-domain>` (DNS-validated); alias `terraform.<your-domain>` → ALB |
| 5 | Deploy the app | Ansible | install **Docker** + run an **nginx container** serving `site.zip` on :80, both EC2 |

### Project layout

```text
terraform-webtier/
├── .github/workflows/
│   └── terraform.yml   # fmt → validate → plan (PR) → apply (merge), via OIDC
├── modules/
│   ├── vpc/            # 1 VPC + 2 public subnets
│   ├── ec2/            # 1 EC2 + security group   (root uses it for 2)
│   ├── alb/            # ALB + target group + listeners (:80, :443) — takes the cert ARN
│   └── hostedzone/     # Route 53 zone + ACM cert (DNS-validated) + alias record
├── dev/               # root env — calls the 4 modules
└── prod/              # root env — same modules, different values
```

### Run it through the pipeline

- Authenticate to AWS with the **OIDC role** ([Section 3](#3-oidc-keyless-aws-auth-the-proper-setup)) — no keys in the repo.
- Keep state in the **remote S3 backend** ([Section 4](#4-remote-state-in-ci-is-mandatory)).
- The workflow runs `fmt`/`validate`/`plan` on every **PR** and `apply` on **merge to `main`** — provision **dev** and **prod** this way (a matrix over the two roots, or a workflow per env).
- **Route 53 delegation** is a manual prereq — point your registrar's nameservers at the zone's NS records. (The first `apply` creates the zone; once DNS propagates, the ACM cert validates.)
- Deploy the app with **Ansible** — install **Docker** and serve `site.zip` from an **nginx container** on port 80 on both EC2. Get it here: [`site.zip`](https://github.com/user-attachments/files/30199374/site.zip). Run the playbook from the pipeline too, after `apply`.

**Submit:** your modules + `dev`/`prod` roots + the workflow, a **PR showing the plan**, the **merge run that applied it**, a screenshot of the **padlock + your site**, a `curl` run a few times hitting both instances, and proof of a clean `terraform destroy`.

### Clean up (don't skip)

!!! danger "Destroy both environments when you're done"
    Trigger your destroy workflow, or run locally:
    ```bash
    cd dev  && terraform destroy
    cd ../prod && terraform destroy
    ```

---

## Further Reading

**Watch**

- 📺 [Terraform with GitHub Actions](https://youtu.be/GhcRJNIA1_o) — automating plan/apply in a pipeline
- 📺 [Authenticate GitHub Actions with AWS Using OIDC](https://youtu.be/Sdzd4N6L5Hg) — the keyless OIDC setup, step by step

**Reference**

- [Automate Terraform with GitHub Actions](https://developer.hashicorp.com/terraform/tutorials/automation/github-actions) · [`hashicorp/setup-terraform`](https://github.com/hashicorp/setup-terraform)
- [Configuring OpenID Connect in AWS](https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services) · [`aws-actions/configure-aws-credentials`](https://github.com/aws-actions/configure-aws-credentials)
- [Terraform — Backends (S3)](https://developer.hashicorp.com/terraform/language/backend/s3) · [`tflint`](https://github.com/terraform-linters/tflint)
