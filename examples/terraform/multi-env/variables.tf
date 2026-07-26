variable "region" {
  type    = string
  default = "us-east-1"
}

variable "environment" {
  type        = string
  description = "dev or prod — set by the matching .tfvars file."
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}
