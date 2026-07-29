output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "Both public subnet IDs (ALB spans both; instances go in the first)."
  value       = aws_subnet.public[*].id
}
