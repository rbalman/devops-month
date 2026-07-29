variable "name" {
  description = "Name prefix (e.g. demo-app-dev)."
  type        = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  description = "The two public subnet IDs the ALB spans."
  type        = list(string)
}

variable "certificate_arn" {
  description = "Validated ACM cert ARN for the HTTPS listener."
  type        = string
}

variable "domain_name" {
  description = "FQDN to alias to the ALB (e.g. app.dev.example.com)."
  type        = string
}

variable "zone_id" {
  description = "Route53 hosted zone ID for the alias record."
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
