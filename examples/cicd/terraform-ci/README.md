# Terraform in CI/CD — Sample Project

A complete, runnable version of the project used in **Week 4, Day 3** to run Terraform
from a GitHub Actions pipeline: `plan` on pull requests, `apply` on merge to `main`,
authenticated to AWS with **OIDC** (no stored keys). The infrastructure is intentionally
trivial — a single EC2 instance — so the focus is the **automation**, not the resource.

> This is its **own repo/project** — it does not reuse the `sample-app` from Day 1.

## Structure

```
terraform-ci/
├── .github/
│   └── workflows/
│       └── terraform.yml    # fmt → validate → plan (PR) → apply (merge)
└── terraform/
    ├── main.tf              # one EC2 instance (t3.micro) + the S3 remote backend
    └── .terraform.lock.hcl  # provider version lock — committed, on purpose
```

> **The lock file (`.terraform.lock.hcl`) is committed, not ignored.** It pins the exact
> provider versions and hashes so every run — yours and the CI runner's — resolves the
> same AWS provider. Only `.terraform/` (downloaded binaries) and `*.tfstate` are ignored.

## Before it will run

1. **State bucket** — reuse the S3 backend bucket from Week 3, Day 21. Put its name in
   `terraform/main.tf` (`backend "s3" { bucket = ... }`), replacing `CHANGEME`.
2. **OIDC role** — create an IAM OIDC identity provider for
   `token.actions.githubusercontent.com` and a role whose trust policy allows this repo
   (`repo:<you>/terraform-ci:*`) and whose permissions allow **EC2** (+ the state bucket).
   Put its ARN in `terraform.yml` (`role-to-assume:`), replacing `CHANGEME`.

## Check it locally

You can validate the config offline (no AWS needed):

```bash
cd terraform
terraform fmt -check
terraform init -backend=false
terraform validate      # → Success! The configuration is valid.
```

> Verified with Terraform ≥ 1.10 and the AWS provider `~> 6.0`.

## The pipeline

Copy this folder to a new repo's root; GitHub reads workflows from `.github/workflows/`
at the **repo root** (not from inside `examples/`), so the copy here is a reference.
Open a PR → the workflow runs `fmt`/`validate`/`plan`; merge to `main` → it `apply`s the
EC2 instance.

!!! note
    An EC2 instance bills by the hour (a `t3.micro` is free-tier-eligible) — run
    `terraform destroy` when you're done.

See [Week 4, Day 3](../../../docs/week-04/day-24.md) for the full walkthrough.
