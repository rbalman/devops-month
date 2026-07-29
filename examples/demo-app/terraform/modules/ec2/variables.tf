variable "name" {
  description = "Name prefix for this group (e.g. demo-app-dev-app)."
  type        = string
}

variable "instance_count" {
  description = "How many instances to launch (each gets its own IAM role/profile). Defaults to 1; only set it when you need more."
  type        = number
  default     = 1
}

variable "ami_id" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "vpc_id" {
  description = "VPC the instances + their security group live in."
  type        = string
}

variable "subnet_ids" {
  description = "Public subnets to spread instances across, round-robin by index (pass one subnet to pin to a single AZ)."
  type        = list(string)
}

variable "key_name" {
  description = "EC2 key pair name for SSH access (Ansible deploys over SSH)."
  type        = string
}

variable "ssh_ingress_cidr" {
  description = "CIDR allowed to SSH to these instances."
  type        = string
  default     = "0.0.0.0/0"
}

variable "ingress_from_sg" {
  description = "Ingress rules that reference another security group (e.g. app allows 80 from the ALB SG, db allows 5432 from the app SG)."
  type = list(object({
    description              = string
    port                     = number
    source_security_group_id = string
  }))
  default = []
}

variable "role" {
  description = "Logical role tag Ansible's dynamic inventory groups on: app | db."
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
