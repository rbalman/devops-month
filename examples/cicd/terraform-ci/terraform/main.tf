terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Remote state in S3 — reuse the state bucket from Week 3, Day 21.
  # A GitHub runner is ephemeral, so CI-run Terraform MUST use a remote backend.
  backend "s3" {
    bucket       = "golive-tf-state-CHANGEME" # the state bucket you created
    key          = "ci-demo/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true # native S3 locking (Terraform 1.10+) — no DynamoDB
  }
}

provider "aws" {
  region = "us-east-1"
}

# Latest Ubuntu 24.04 (Noble) AMI, published by Canonical.
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

# Intentionally trivial infra — the focus is the pipeline, not the resource.
resource "aws_instance" "demo" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"

  tags = {
    Name      = "ci-demo"
    ManagedBy = "github-actions"
  }
}

output "instance_id" {
  value = aws_instance.demo.id
}

output "public_ip" {
  value = aws_instance.demo.public_ip
}
