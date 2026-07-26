# `vpc` module

A small, reusable Terraform module that builds a classic public/private VPC on AWS.

**What it creates**

- 1× VPC (DNS support + hostnames on)
- 1× internet gateway
- N public subnets (one per AZ), auto-assign public IP
- N private subnets (one per AZ)
- a public route table (`0.0.0.0/0` → internet gateway) + associations
- *(optional)* a NAT gateway + private route table so private subnets get outbound internet

## Usage

```hcl
module "vpc" {
  source = "../modules/vpc"   # local path; could be a Git URL or registry ref instead

  name       = "golive-vpc"
  cidr_block = "10.0.0.0/16"
  azs        = ["us-east-1a", "us-east-1b"]

  public_subnet_cidrs  = ["10.0.0.0/24", "10.0.1.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]

  enable_nat_gateway = false   # true adds a billable NAT gateway

  tags = {
    Project   = "golive"
    ManagedBy = "terraform"
  }
}
```

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | — (required) | Name prefix for the VPC and all its resources |
| `cidr_block` | `string` | `"10.0.0.0/16"` | CIDR block for the VPC |
| `azs` | `list(string)` | — (required) | AZs to spread subnets across |
| `public_subnet_cidrs` | `list(string)` | `[]` | Public subnet CIDRs, one per AZ (same order as `azs`) |
| `private_subnet_cidrs` | `list(string)` | `[]` | Private subnet CIDRs, one per AZ (same order as `azs`) |
| `enable_nat_gateway` | `bool` | `false` | Create a NAT gateway (⚠️ billable) for private-subnet egress |
| `tags` | `map(string)` | `{}` | Extra tags merged onto every resource |

## Outputs

| Name | Description |
|---|---|
| `vpc_id` | ID of the VPC |
| `vpc_cidr_block` | CIDR block of the VPC |
| `public_subnet_ids` | IDs of the public subnets |
| `private_subnet_ids` | IDs of the private subnets |
| `internet_gateway_id` | ID of the internet gateway |
| `nat_gateway_id` | ID of the NAT gateway (`null` when disabled) |

> ⚠️ **Cost:** the base module (VPC, subnets, IGW, route tables) is **free**. Setting `enable_nat_gateway = true` creates a NAT gateway (~$0.045/hour + data). Leave it `false` unless private subnets truly need outbound internet, and `terraform destroy` when you're done.

See [`../vpc-example`](../vpc-example) for a complete, runnable configuration that consumes this module with a remote S3 backend.
