# Dedicated example: creating S3 buckets with loops, two ways.
#   - count + index     → N numbered buckets
#   - for_each + a map   → one bucket per named entry

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

# ── count + index — N numbered buckets ──
resource "aws_s3_bucket" "numbered" {
  count  = var.bucket_count
  bucket = "${var.prefix}-bucket-${count.index}" # -bucket-0, -bucket-1, ...
}

# ── for_each + map — one bucket per named entry ──
resource "aws_s3_bucket" "named" {
  for_each = var.buckets
  bucket   = "${var.prefix}-${each.value}" # golive-logs, golive-backups
  tags     = { Purpose = each.key }        # each.key = "logs" / "backups"
}
