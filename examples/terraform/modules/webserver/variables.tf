variable "name" {
  type        = string
  description = "Name for the instance and its security group."
}

variable "ami_id" {
  type        = string
  description = "AMI to launch."
}

variable "instance_type" {
  type        = string
  description = "EC2 instance size."
  default     = "t3.micro"
}

variable "allowed_ssh_cidrs" {
  type        = list(string)
  description = "CIDR blocks allowed to SSH (port 22) into the instance."
  default     = ["0.0.0.0/0"]
}
