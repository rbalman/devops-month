# These simply re-expose the module's outputs. A root config can also feed them
# into other resources (e.g. launch EC2 into module.vpc.public_subnet_ids).

output "vpc_id" {
  description = "ID of the VPC the module created."
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets."
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets."
  value       = module.vpc.private_subnet_ids
}
