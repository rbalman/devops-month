variable "name" {
  description = "Name prefix for this group (e.g. end-to-end-dev-app)."
  type        = string
}

variable "instance_count" {
  description = "How many instances to launch."
  type        = number
  default     = 1
}

variable "ami_id" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "subnet_id" {
  description = "Private subnet the instances launch into (single-AZ compute)."
  type        = string
}

variable "security_group_ids" {
  type = list(string)
}

variable "iam_instance_profile" {
  description = "Instance profile name (grants SSM + ECR pull) — created in the env."
  type        = string
}

variable "role" {
  description = "Logical role tag Ansible's dynamic inventory groups on: app | db."
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
