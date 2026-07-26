# `vpc-example` — a root config that consumes the `vpc` module

This is a complete, runnable Terraform configuration that:

1. Calls the reusable [`../modules/vpc`](../modules/vpc) module to build a public/private VPC across two AZs, and
2. Stores its state in a **remote S3 backend** with **native locking** (`use_lockfile`, Terraform 1.10+) — **no DynamoDB table required**.

## Layout

```
vpc-example/
├── backend.tf                  # S3 remote state + native locking
├── main.tf                     # provider + module "vpc" { ... }
├── variables.tf                # region, project
├── outputs.tf                  # re-exposes the module outputs
└── terraform.tfvars.example    # copy to terraform.tfvars and edit
```

## Run it

```bash
# 0. Prereqs: AWS CLI configured, Terraform >= 1.10 installed.

# 1. Create the state bucket ONCE (chicken-and-egg — the backend needs it to exist).
aws s3 mb s3://golive-tf-state-$(whoami) --region us-east-1
aws s3api put-bucket-versioning \
  --bucket golive-tf-state-$(whoami) \
  --versioning-configuration Status=Enabled

# 2. Point backend.tf at that bucket (replace golive-tf-state-CHANGEME).

# 3. Init, review, apply.
terraform init          # initializes the S3 backend + downloads the AWS provider
terraform fmt -recursive && terraform validate
terraform plan
terraform apply         # type 'yes'

terraform output vpc_id

# 4. Tear it all down when done.
terraform destroy
```

> ⚠️ **Cost:** the VPC, subnets, internet gateway, and route tables are **free**. This example keeps `enable_nat_gateway = false`, so nothing here is billable — but if you set it to `true`, a NAT gateway costs ~$0.045/hour + data. Either way, `terraform destroy` when finished.

## What to notice

- **One `module "vpc"` block** stands up ~10 resources. Call it again with a different `name`/CIDRs and you get a second, independent VPC — that's reuse.
- The module is referenced by a **local path** (`source = "../modules/vpc"`). In a real project the same `source` could be a Git URL (`git::https://...//modules/vpc?ref=v1.2.0`) or a registry reference, pinned to a version.
- State lives in S3, locked via `use_lockfile` — the current, DynamoDB-free way to do team-safe remote state.
