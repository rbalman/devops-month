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

variable "app_domain" {
  description = "Full FQDN the app is served at (e.g. app.dev.example.com)."
  type        = string
}

variable "hosted_zone_name" {
  description = "Existing Route53 hosted zone that contains app_domain (e.g. example.com)."
  type        = string
}

variable "db_username" {
  description = "Postgres role name (the password is generated + stored in SSM)."
  type        = string
  default     = "appuser"
}

variable "db_name" {
  type    = string
  default = "appdb"
}
