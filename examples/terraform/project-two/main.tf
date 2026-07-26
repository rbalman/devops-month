# project-two — another ROOT module reusing the SAME webserver module, but with
# different variables: a bigger instance and SSH locked to one IP.
# It keeps its own state, separate from project-one.

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

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

module "web" {
  source = "../modules/webserver"

  name              = "project-two-web"
  ami_id            = data.aws_ami.ubuntu.id
  instance_type     = "t3.small"          # different size
  allowed_ssh_cidrs = ["203.0.113.10/32"] # locked to one IP
}

variable "region" {
  type    = string
  default = "us-east-1"
}

output "web_ip" {
  value = module.web.public_ip
}
