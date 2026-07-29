terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Remote state in S3 (reuse the state bucket from Week 3). CI runners are
  # ephemeral, so state MUST be remote. Each env has its own key.
  backend "s3" {
    bucket       = "golive-tf-state-CHANGEME"
    key          = "demo-app/dev/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true # native S3 locking (Terraform 1.10+)
  }
}

provider "aws" {
  region = var.region
}
