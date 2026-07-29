output "alb_dns_name" {
  value = aws_lb.this.dns_name
}

output "target_group_arn" {
  description = "Attach the app instances to this (done in the env)."
  value       = aws_lb_target_group.app.arn
}

output "security_group_id" {
  description = "The ALB's SG (the app tier allows :80 ingress from it)."
  value       = aws_security_group.alb.id
}
