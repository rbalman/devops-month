output "backend_repository_url" {
  value = aws_ecr_repository.this["backend"].repository_url
}

output "frontend_repository_url" {
  value = aws_ecr_repository.this["frontend"].repository_url
}

output "repository_arns" {
  description = "Both repo ARNs (used to scope the instances' ECR pull policy)."
  value       = [for r in aws_ecr_repository.this : r.arn]
}
