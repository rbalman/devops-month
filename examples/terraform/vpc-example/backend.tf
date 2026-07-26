# Remote state in S3 with NATIVE state locking (Terraform 1.10+).
#
# The modern way: `use_lockfile = true` keeps the lock as a small object in the
# same S3 bucket. You NO LONGER need a separate DynamoDB table for locking —
# that was the old pattern (`dynamodb_table = "..."`) and is now deprecated.
#
# Create the bucket ONCE before `terraform init` (chicken-and-egg):
#   aws s3 mb s3://golive-tf-state-<you> --region us-east-1
#   aws s3api put-bucket-versioning \
#     --bucket golive-tf-state-<you> \
#     --versioning-configuration Status=Enabled
#
# Then set `bucket` below to that name and run `terraform init`.
terraform {
  backend "s3" {
    bucket       = "golive-tf-state-CHANGEME"
    key          = "vpc/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
