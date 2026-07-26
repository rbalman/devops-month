# bootstrap/main.tf — creates the S3 bucket used as the remote-state backend by
# every other config (e.g. ../vpc-example).
#
# This config keeps LOCAL state on purpose: the bucket that stores everyone's
# remote state can't store its own before it exists. Run it once:
#   terraform init && terraform apply
# It rarely changes after that.
terraform {
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

resource "aws_s3_bucket" "state" {
  bucket = var.bucket_name # must be globally unique
}

# Versioning — recover a previous state if one gets corrupted or deleted
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Encrypt state at rest (it can contain secrets in plain text)
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# State is a keys-to-the-kingdom target — never allow public access
resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "bucket_name" {
  type        = string
  description = "Globally-unique name for the state bucket, e.g. golive-tf-state-yourname."
}

output "bucket_name" {
  description = "Set this as the `bucket` in other configs' backend blocks."
  value       = aws_s3_bucket.state.id
}
