# project-one — a ROOT module that reuses the shared webserver module.
# Run terraform here: `terraform init && terraform apply`. It keeps its own state,
# separate from project-two.

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

  name          = "project-one-web"
  ami_id        = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
}

variable "region" {
  type    = string
  default = "us-east-1"
}

# read a child module's output with module.<name>.<output>
output "web_ip" {
  value = module.web.public_ip
}
