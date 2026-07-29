output "app_url" {
  description = "The live app (HTTPS via the ACM cert)."
  value       = "https://${var.app_domain}"
}

output "alb_dns_name" {
  value = module.alb.alb_dns_name
}

output "app_instance_ids" {
  value = module.app.instance_ids
}

output "db_private_ip" {
  description = "Private IP the backend connects to for Postgres."
  value       = module.db.private_ips[0]
}

output "backend_ecr_url" {
  value = module.ecr.backend_repository_url
}

output "frontend_ecr_url" {
  value = module.ecr.frontend_repository_url
}
