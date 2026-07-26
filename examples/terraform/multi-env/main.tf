terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# The whole root config is one module call — dev and prod differ only by tfvars.
module "webserver" {
  source        = "./modules/webserver"
  name          = "golive-${var.environment}"
  instance_type = var.instance_type
}
