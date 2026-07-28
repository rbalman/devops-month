output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "Both public subnet IDs (for the ALB)."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Both private subnet IDs (instances go in the first one)."
  value       = aws_subnet.private[*].id
}
