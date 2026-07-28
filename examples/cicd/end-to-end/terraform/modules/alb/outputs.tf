output "alb_dns_name" {
  value = aws_lb.this.dns_name
}

output "target_group_arn" {
  description = "Attach the app instances to this (done in the env)."
  value       = aws_lb_target_group.app.arn
}
