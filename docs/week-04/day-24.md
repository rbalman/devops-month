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
- Day 1's `sample-app` repo (we'll add Terraform to it)

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
    "StringLike":  { "token.actions.githubusercontent.com:sub": "repo:<you>/sample-app:*" }
  }
}
```

At run time the workflow presents a signed token, AWS verifies it against the trust policy, and hands back a **15-minute** credential. No access keys ever exist to leak.

!!! tip "Scope the sub condition tighter in production"
    `repo:<you>/sample-app:*` allows any branch/PR. Real setups pin to a branch (`...:ref:refs/heads/main`) or an **environment** (`...:environment:production`) so only trusted contexts can touch AWS.

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

Automate a **tiny** Terraform config with GitHub Actions: `plan` on PRs, `apply` on merge, authenticated by OIDC. The infra is intentionally trivial — a single S3 bucket — so all your attention is on the pipeline.

!!! important "Reuse your S3 backend"
    Use the state bucket from [Day 21, Section 3](../week-03/day-21.md#3-remote-backend-s3-the-modern-way). This config gets its own key: `ci-demo/terraform.tfstate`.

### 1. Create the OIDC role

In the AWS console (IAM → Identity providers → Add provider → OpenID Connect):

- Provider URL: `https://token.actions.githubusercontent.com`, Audience: `sts.amazonaws.com`.
- Then create a **role** for web identity using that provider, with the trust policy from [Section 3](#3-oidc-keyless-aws-auth-the-proper-setup) and a permissions policy allowing S3 (plus access to your state bucket).

Note the **role ARN**.

### 2. The Terraform config

In your repo, make a `terraform/` folder. **`terraform/main.tf`** — one bucket:

```hcl
terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }
  }
  backend "s3" {
    bucket       = "golive-tf-state-<you>"
    key          = "ci-demo/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "demo" {
  bucket = "golive-ci-demo-<your-initials>"   # globally unique
  tags   = { ManagedBy = "github-actions" }
}
```

### 3. The workflow — plan on PR, apply on merge

**`.github/workflows/terraform.yml`**:

```yaml
name: Terraform

on:
  pull_request:
    paths: ["terraform/**"]
  push:
    branches: [main]
    paths: ["terraform/**"]

permissions:
  id-token: write        # request the OIDC token
  contents: read

jobs:
  terraform:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: terraform
    steps:
      - uses: actions/checkout@v7

      - name: Authenticate to AWS (OIDC)
        uses: aws-actions/configure-aws-credentials@v6
        with:
          role-to-assume: arn:aws:iam::<acct>:role/github-actions
          aws-region: us-east-1

      - uses: hashicorp/setup-terraform@v3

      - run: terraform init -input=false
      - run: terraform fmt -check
      - run: terraform validate -no-color

      - name: Plan (on PRs)
        if: github.event_name == 'pull_request'
        run: terraform plan -no-color -input=false

      - name: Apply (on merge to main)
        if: github.ref == 'refs/heads/main' && github.event_name == 'push'
        run: terraform apply -auto-approve -input=false
```

### 4. Run the full cycle

1. Commit on a branch, open a **PR**. The workflow runs `fmt`/`validate`/`plan` — expand the **Plan** step and read "1 to add."
2. **Merge.** The `apply` step runs and creates the bucket. Confirm it in the S3 console.
3. Change the bucket's tags on another branch, open a PR — the plan now shows "1 to change." Merge to apply.

You just changed AWS infrastructure **without touching a terminal or storing a key** — every change reviewed as a PR.

### 5. Clean up

Add a **manual destroy** you can trigger from the UI — a `workflow_dispatch` workflow that runs `terraform destroy -auto-approve` — or just run it once locally to remove the bucket. Don't leave orphaned resources.

!!! success "What you just built"
    A keyless, reviewable Terraform pipeline: PRs show the plan, merges apply it. The same pattern for **Ansible** is in [Ansible in CI/CD](day-25.md); [GitOps & the End-to-End Project](day-26.md) combines both.

---

## Advanced Topics

- **Save & apply the exact plan** — `plan -out=tfplan` as an artifact, `apply tfplan` on merge (no drift between plan and apply) → [Automate Terraform](https://developer.hashicorp.com/terraform/tutorials/automation/github-actions)
- **Post the plan as a PR comment** — `actions/github-script` or the `dflook/terraform-*` actions render the diff inline
- **`tflint` / `trivy config` / `checkov`** — lint and security-scan HCL as CI gates (tfsec was merged into Trivy in 2024) — you'll do this on Day 7
- **Environments for apply** — require a reviewer before the apply job runs (Day 2 pattern)
- **Matrix over environments** — one workflow that plans dev + prod in parallel

---

## Assignment

Make the Terraform pipeline safer and more informative.

**Part 1 — Plan as a PR comment.** Use a marketplace action (e.g. `actions/github-script` or `dflook/terraform-plan`) so the `plan` output is posted **as a comment on the PR**, not buried in logs. Open a PR that changes the bucket's tags and screenshot the rendered plan comment.

**Part 2 — Lint gate.** Add **`tflint`** as a step that runs on every PR and **fails** the workflow on a finding. Prove it: introduce a deliberately bad practice (e.g. a hard-coded region or a missing tag your rules require), watch CI go red, then fix it. (Security scanning with Trivy comes on Day 7.)

**Submit:** your `terraform.yml`, a screenshot of the plan-as-PR-comment, and the CI run where the lint gate caught your bad practice.

---

## Further Reading

**Watch**

- 📺 [Terraform with GitHub Actions](https://youtu.be/GhcRJNIA1_o) — automating plan/apply in a pipeline

**Reference**

- [Automate Terraform with GitHub Actions](https://developer.hashicorp.com/terraform/tutorials/automation/github-actions) · [`hashicorp/setup-terraform`](https://github.com/hashicorp/setup-terraform)
- [Configuring OpenID Connect in AWS](https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services) · [`aws-actions/configure-aws-credentials`](https://github.com/aws-actions/configure-aws-credentials)
- [Terraform — Backends (S3)](https://developer.hashicorp.com/terraform/language/backend/s3) · [`tflint`](https://github.com/terraform-linters/tflint)
