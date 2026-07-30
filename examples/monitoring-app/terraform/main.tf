provider "aws" {
  region = var.region
}

# Latest Ubuntu 24.04 (Noble), published by Canonical.
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

# Use the account's default VPC and its subnets — nothing to build.
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# One security group shared by both hosts.
resource "aws_security_group" "monitoring" {
  name        = "monitoring-lab"
  description = "Monitoring lab: SSH + UIs open, all traffic between the two hosts"
  vpc_id      = data.aws_vpc.default.id

  # Open to the world to keep the lab simple. Fine for a short-lived lab you
  # tear down; do NOT do this for anything real.
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Grafana UI"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Prometheus UI"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Everything between hosts in this SG: node-exporter scrape (9100), Loki push (3100)…
  ingress {
    description = "All traffic within this security group"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  egress {
    description = "All egress (apt, Docker Hub)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "monitoring-lab" }
}

# Install Docker Engine + Compose plugin (and git, to fetch these files) on first boot.
locals {
  bootstrap = <<-EOF
    #!/bin/bash
    set -e
    apt-get update
    apt-get install -y ca-certificates curl git
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" > /etc/apt/sources.list.d/docker.list
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    usermod -aG docker ubuntu
  EOF
}

resource "aws_instance" "app" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = data.aws_subnets.default.ids[0]
  vpc_security_group_ids = [aws_security_group.monitoring.id]
  user_data              = local.bootstrap

  tags = { Name = "monitoring-app" }
}

resource "aws_instance" "observability" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = data.aws_subnets.default.ids[0]
  vpc_security_group_ids = [aws_security_group.monitoring.id]
  user_data              = local.bootstrap

  tags = { Name = "monitoring-observability" }
}
