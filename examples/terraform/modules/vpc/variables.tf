variable "name" {
  type        = string
  description = "Name prefix applied to the VPC and all of its resources."
}

variable "cidr_block" {
  type        = string
  description = "CIDR block for the VPC."
  default     = "10.0.0.0/16"
}

variable "azs" {
  type        = list(string)
  description = "Availability zones to spread subnets across, e.g. [\"us-east-1a\", \"us-east-1b\"]."
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for the public subnets — one per AZ, in the same order as var.azs."
  default     = []
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for the private subnets — one per AZ, in the same order as var.azs."
  default     = []
}

variable "enable_nat_gateway" {
  type        = bool
  description = "Create a NAT gateway so private subnets can reach the internet outbound. Costs ~$0.045/hour + data processing — leave false unless you need it."
  default     = false
}

variable "tags" {
  type        = map(string)
  description = "Extra tags merged onto every resource the module creates."
  default     = {}
}
