# `multi-env` — one module, deployed from tfvars (Day 21, Example 1)

A deliberately simple module + tfvars example. The **`webserver` module** creates one VPC (via the community registry module), one security group, and one EC2 — driven by just two variables. The root deploys it as **`dev` or `prod`** by swapping a `.tfvars` file.

## Layout

```
multi-env/
├── modules/webserver/   # VPC (registry) + SG + EC2  (2 variables)
├── main.tf              # root: one module block
├── variables.tf
├── outputs.tf
├── dev.tfvars
└── prod.tfvars
```

## Run it

```bash
terraform init                        # downloads the AWS provider + registry VPC module
terraform fmt -recursive && terraform validate

terraform apply -var-file=dev.tfvars  # or: -var-file=prod.tfvars
terraform output web_ip

terraform destroy -var-file=dev.tfvars
```

> ⚠️ **EC2 is billable** (t3.micro may be free-tier). Destroy when done.
>
> **State is local and single.** Applying `prod` replaces `dev`. To keep both at once, give each its own state — a directory per environment, or a backend key per environment.
