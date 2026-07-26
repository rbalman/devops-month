variable "name" {
  type        = string
  description = "Name prefix, e.g. golive-dev."
}

variable "instance_type" {
  type        = string
  description = "EC2 instance size."
  default     = "t3.micro"
}
