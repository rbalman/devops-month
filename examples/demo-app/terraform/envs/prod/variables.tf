variable "region" {
  type    = string
  default = "us-east-1"
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "azs" {
  description = "Two AZs (ALB requirement)."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "app_instance_type" {
  type    = string
  default = "t3.small"
}

variable "db_instance_type" {
  type    = string
  default = "t3.small"
}

variable "key_name" {
  description = "Existing EC2 key pair name for SSH access (Ansible deploys over SSH)."
  type        = string
}

variable "ssh_ingress_cidr" {
  description = "CIDR allowed to SSH to the instances (Ansible). Tighten from 0.0.0.0/0 in production."
  type        = string
  default     = "0.0.0.0/0"
}

variable "app_domain" {
  description = "Full FQDN the app is served at (e.g. app.dev.example.com)."
  type        = string
}

variable "hosted_zone_name" {
  description = "Existing Route53 hosted zone that contains app_domain (e.g. example.com)."
  type        = string
}
