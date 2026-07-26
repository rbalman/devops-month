# `bootstrap` — create the S3 state bucket (run this first)

A minimal, one-file Terraform config that creates the S3 bucket used as the **remote-state backend** by the other examples (like [`../vpc-example`](../vpc-example)), with versioning, encryption, and public-access block turned on.

It keeps **local** state on purpose — the bucket that holds everyone's remote state can't hold its own before it exists.

## Run it once

```bash
terraform init
terraform apply -var "bucket_name=golive-tf-state-$(whoami)"
terraform output bucket_name     # use this as `bucket` in other backend blocks
```

Then point the `backend "s3"` block of [`../vpc-example/backend.tf`](../vpc-example/backend.tf) at that bucket name and `terraform init` there.

> The bucket itself is free; you're billed only for the tiny amount of state stored in it. Leave it in place for as long as you're using Terraform; remove it (`terraform destroy`, or `aws s3 rb ... --force`) when you're completely done.
