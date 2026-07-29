output "instance_ids" {
  value = aws_instance.this[*].id
}

output "private_ips" {
  value = aws_instance.this[*].private_ip
}

output "security_group_id" {
  description = "This group's SG (so a downstream tier can allow ingress from it)."
  value       = aws_security_group.this.id
}
