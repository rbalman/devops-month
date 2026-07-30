variable "region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type for both hosts"
  type        = string
  default     = "t3.small"
}

variable "key_name" {
  description = "Name of an existing EC2 key pair for SSH access"
  type        = string
}

variable "my_ip" {
  description = "Your public IP in CIDR form (e.g. 203.0.113.4/32) — allowed to SSH and reach the Grafana/Prometheus UIs"
  type        = string
}
