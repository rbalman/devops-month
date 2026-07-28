variable "name" {
  description = "Name prefix (e.g. end-to-end-dev)."
  type        = string
}

variable "vpc_id" {
  description = "VPC to create the security groups in."
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
