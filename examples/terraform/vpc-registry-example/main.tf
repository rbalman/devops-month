# Using the community VPC module from the Terraform Registry instead of writing
# your own. `terraform init` downloads it from the registry.
#
# Builds: 1 VPC, 1 internet gateway, 2 public + 2 private subnets across 2 AZs,
# route tables, and 1 (shared) NAT gateway for private-subnet egress.

terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.region
}

data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0" # pin it — latest is 6.6.1

  name = "${var.project}-vpc"
  cidr = "10.0.0.0/16"

  azs             = slice(data.aws_availability_zones.available.names, 0, 2)
  public_subnets  = ["10.0.0.0/24", "10.0.1.0/24"]   # 2 public subnets
  private_subnets = ["10.0.10.0/24", "10.0.11.0/24"] # 2 private subnets

  enable_nat_gateway = true # NAT gateway(s) for private-subnet outbound internet
  single_nat_gateway = true # just ONE, shared across AZs (cheaper)

  tags = {
    Project   = var.project
    ManagedBy = "terraform"
  }
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "project" {
  type    = string
  default = "golive"
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnets" {
  value = module.vpc.public_subnets
}

output "private_subnets" {
  value = module.vpc.private_subnets
}
