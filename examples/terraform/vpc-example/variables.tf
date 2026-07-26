variable "region" {
  type        = string
  description = "AWS region to deploy the VPC into."
  default     = "us-east-1"
}

variable "project" {
  type        = string
  description = "Project name, used as a prefix for the VPC."
  default     = "golive"
}
