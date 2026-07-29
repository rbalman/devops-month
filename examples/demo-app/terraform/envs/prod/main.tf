# ==========================================================================
# dev environment — wires the reusable modules into one stack.
# prod/ is identical except for its tfvars + backend key.
# ==========================================================================

locals {
  name = "demo-app-${var.environment}"
  tags = {
    Project = "demo-app"
    Env     = var.environment
    Managed = "terraform"
  }
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

# The already-configured hosted zone that contains app_domain.
data "aws_route53_zone" "this" {
  name = var.hosted_zone_name
}

# --- Network ---------------------------------------------------------------
module "vpc" {
  source = "../../modules/vpc"
  name   = local.name
  azs    = var.azs
  tags   = local.tags
}

# --- Registry --------------------------------------------------------------
module "ecr" {
  source = "../../modules/ecr"
  name   = local.name
  tags   = local.tags
}

# --- TLS + load balancer (the ALB owns its own security group) -------------
module "acm" {
  source      = "../../modules/acm"
  domain_name = var.app_domain
  zone_id     = data.aws_route53_zone.this.zone_id
  tags        = local.tags
}

module "alb" {
  source            = "../../modules/alb"
  name              = local.name
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  certificate_arn   = module.acm.certificate_arn
  domain_name       = var.app_domain
  zone_id           = data.aws_route53_zone.this.zone_id
  tags              = local.tags
}

# --- Compute: 2 app instances + 1 db instance, all in public[0] ------------
# DB credentials are NOT handled here — they come from GitHub secrets straight
# to Ansible at deploy time (see ansible/group_vars/all.yml).
# Each ec2 module owns its instances' security group + per-instance IAM roles.
module "app" {
  source           = "../../modules/ec2"
  name             = "${local.name}-app"
  instance_count   = 2
  ami_id           = data.aws_ami.ubuntu.id
  instance_type    = var.app_instance_type
  subnet_ids       = module.vpc.public_subnet_ids # spread across both AZs
  vpc_id           = module.vpc.vpc_id
  key_name         = var.key_name
  ssh_ingress_cidr = var.ssh_ingress_cidr
  ingress_from_sg = [{
    description              = "HTTP from ALB"
    port                     = 80
    source_security_group_id = module.alb.security_group_id
  }]
  role = "app"
  tags = local.tags
}

module "db" {
  source = "../../modules/ec2"
  name   = "${local.name}-db"
  # instance_count defaults to 1
  ami_id           = data.aws_ami.ubuntu.id
  instance_type    = var.db_instance_type
  subnet_ids       = [module.vpc.public_subnet_ids[0]] # single AZ (one instance)
  vpc_id           = module.vpc.vpc_id
  key_name         = var.key_name
  ssh_ingress_cidr = var.ssh_ingress_cidr
  ingress_from_sg = [{
    description              = "Postgres from app"
    port                     = 5432
    source_security_group_id = module.app.security_group_id
  }]
  role = "db"
  tags = local.tags
}

# Register the two app instances behind the ALB.
resource "aws_lb_target_group_attachment" "app" {
  count            = length(module.app.instance_ids)
  target_group_arn = module.alb.target_group_arn
  target_id        = module.app.instance_ids[count.index]
  port             = 80
}
