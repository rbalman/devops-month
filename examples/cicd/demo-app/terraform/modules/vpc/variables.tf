variable "name" {
  description = "Name prefix for all VPC resources (e.g. demo-app-dev)."
  type        = string
}

variable "cidr_block" {
  description = "CIDR for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Exactly two Availability Zones — the ALB requires two."
  type        = list(string)

  validation {
    condition     = length(var.azs) == 2
    error_message = "Provide exactly two AZs (an ALB needs subnets in two AZs)."
  }
}

variable "public_subnet_cidrs" {
  description = "Two public subnet CIDRs, one per AZ (ALB + instances)."
  type        = list(string)
  default     = ["10.0.0.0/24", "10.0.1.0/24"]
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
