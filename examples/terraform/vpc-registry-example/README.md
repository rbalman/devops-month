# `vpc-registry-example` — a VPC from the community registry module

Instead of the hand-written [`../modules/vpc`](../modules/vpc), this config uses the popular
[`terraform-aws-modules/vpc/aws`](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest)
module from the Terraform Registry.

**What it builds:** 1 VPC, 1 internet gateway, 2 public + 2 private subnets across two AZs, route tables, and **1 NAT gateway** (`single_nat_gateway = true`) for private-subnet egress.

## Run it

```bash
terraform init      # downloads the registry module + AWS provider
terraform fmt && terraform validate
terraform plan
terraform apply     # type 'yes'

terraform output vpc_id
terraform destroy   # when done
```

> ⚠️ **Billable:** `enable_nat_gateway = true` creates a **NAT gateway** (~$0.045/hour + data) plus an Elastic IP. `single_nat_gateway = true` keeps it to one (not one per AZ), but it still costs money — `terraform destroy` promptly.

## Local module vs registry module

| | [`../vpc-example`](../vpc-example) (local) | this (registry) |
|---|---|---|
| `source` | `../modules/vpc` | `terraform-aws-modules/vpc/aws` |
| Versioning | git tag / local path | `version = "~> 6.0"` |
| Maintenance | you own it | community-maintained |
| Best for | learning; small custom needs | production, feature-rich VPCs |
