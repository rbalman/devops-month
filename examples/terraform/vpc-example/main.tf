terraform {
  required_version = ">= 1.10" # use_lockfile (native S3 locking) needs Terraform 1.10+
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

# Pick the first two available AZs in the chosen region automatically
data "aws_availability_zones" "available" {
  state = "available"
}

# Call the reusable VPC module — this is the whole point of a module:
# one block stands up a full VPC, and you could call it again for another env.
module "vpc" {
  source = "../modules/vpc"

  name       = "${var.project}-vpc"
  cidr_block = "10.0.0.0/16"
  azs        = slice(data.aws_availability_zones.available.names, 0, 2)

  public_subnet_cidrs  = ["10.0.0.0/24", "10.0.1.0/24"]
  private_subnet_cidrs = ["10.0.10.0/24", "10.0.11.0/24"]

  enable_nat_gateway = false # flip to true only if private subnets need outbound internet

  tags = {
    Project   = var.project
    ManagedBy = "terraform"
  }
}
