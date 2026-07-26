output "vpc_id" {
  description = "ID of the VPC (from the registry module)."
  value       = module.vpc.vpc_id
}

output "web_ip" {
  description = "Public IP of the EC2 instance."
  value       = aws_instance.web.public_ip
}
