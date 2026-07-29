# One ECR repository per app image. Scan on push, and expire untagged images so
# the registry doesn't grow forever. Per-env repos keep each environment
# self-contained (the trade-off vs a shared build-once/promote registry is noted
# in the project README).

locals {
  repos = ["backend", "frontend"]
}

resource "aws_ecr_repository" "this" {
  for_each             = toset(local.repos)
  name                 = "${var.name}-${each.value}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  # Educational: allow `terraform destroy` to remove repos that still hold images.
  force_delete = true

  tags = merge(var.tags, { Name = "${var.name}-${each.value}" })
}

resource "aws_ecr_lifecycle_policy" "expire_untagged" {
  for_each   = aws_ecr_repository.this
  repository = each.value.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Expire untagged images older than 14 days"
      selection = {
        tagStatus   = "untagged"
        countType   = "sinceImagePushed"
        countUnit   = "days"
        countNumber = 14
      }
      action = { type = "expire" }
    }]
  })
}
