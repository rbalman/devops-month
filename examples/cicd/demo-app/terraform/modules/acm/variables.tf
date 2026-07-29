variable "domain_name" {
  description = "FQDN the cert is issued for (e.g. app.dev.example.com)."
  type        = string
}

variable "zone_id" {
  description = "Route53 hosted zone ID that already hosts the domain."
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
