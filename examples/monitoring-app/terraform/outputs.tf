output "app_public_ip" {
  description = "SSH into the app host here"
  value       = aws_instance.app.public_ip
}

output "app_private_ip" {
  description = "Prometheus scrapes this host's node-exporter at this IP"
  value       = aws_instance.app.private_ip
}

output "observability_public_ip" {
  description = "SSH here; Grafana on :3000, Prometheus on :9090"
  value       = aws_instance.observability.public_ip
}

output "observability_private_ip" {
  description = "Alloy on the app host pushes logs to Loki at this IP"
  value       = aws_instance.observability.private_ip
}
