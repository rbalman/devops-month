# ==========================================================================
# dev environment — wires the reusable modules into one stack.
# prod/ is identical except for its tfvars + backend key.
# ==========================================================================

locals {
  name = "end-to-end-${var.environment}"
  tags = {
    Project = "end-to-end"
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

module "security_groups" {
  source = "../../modules/security-groups"
  name   = local.name
  vpc_id = module.vpc.vpc_id
  tags   = local.tags
}

# --- Registry --------------------------------------------------------------
module "ecr" {
  source = "../../modules/ecr"
  name   = local.name
  tags   = local.tags
}

# --- TLS + load balancer ---------------------------------------------------
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
  alb_sg_id         = module.security_groups.alb_sg_id
  certificate_arn   = module.acm.certificate_arn
  domain_name       = var.app_domain
  zone_id           = data.aws_route53_zone.this.zone_id
  tags              = local.tags
}

# --- DB secret: generated here, stored in SSM, never in git ----------------
resource "random_password" "db" {
  length  = 24
  special = false # keep it URL-safe for DATABASE_URL
}

resource "aws_ssm_parameter" "db_username" {
  name  = "/end-to-end/${var.environment}/db/username"
  type  = "String"
  value = var.db_username
  tags  = local.tags
}

resource "aws_ssm_parameter" "db_password" {
  name  = "/end-to-end/${var.environment}/db/password"
  type  = "SecureString"
  value = random_password.db.result
  tags  = local.tags
}

resource "aws_ssm_parameter" "db_name" {
  name  = "/end-to-end/${var.environment}/db/name"
  type  = "String"
  value = var.db_name
  tags  = local.tags
}

# --- IAM: one instance profile for all instances (SSM + ECR pull) ----------
resource "aws_iam_role" "instance" {
  name = "${local.name}-instance"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
  tags = local.tags
}

# SSM Session Manager connectivity (this is how Ansible reaches the hosts).
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Pull images from this env's ECR repos.
resource "aws_iam_role_policy" "ecr_pull" {
  name = "ecr-pull"
  role = aws_iam_role.instance.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
        ]
        Resource = module.ecr.repository_arns
      },
    ]
  })
}

resource "aws_iam_instance_profile" "instance" {
  name = "${local.name}-instance"
  role = aws_iam_role.instance.name
}

# --- Compute: 2 app instances + 1 db instance, all in private[0] -----------
module "app" {
  source               = "../../modules/ec2"
  name                 = "${local.name}-app"
  instance_count       = 2
  ami_id               = data.aws_ami.ubuntu.id
  instance_type        = var.app_instance_type
  subnet_id            = module.vpc.private_subnet_ids[0]
  security_group_ids   = [module.security_groups.app_sg_id]
  iam_instance_profile = aws_iam_instance_profile.instance.name
  role                 = "app"
  tags                 = local.tags
}

module "db" {
  source               = "../../modules/ec2"
  name                 = "${local.name}-db"
  instance_count       = 1
  ami_id               = data.aws_ami.ubuntu.id
  instance_type        = var.db_instance_type
  subnet_id            = module.vpc.private_subnet_ids[0]
  security_group_ids   = [module.security_groups.db_sg_id]
  iam_instance_profile = aws_iam_instance_profile.instance.name
  role                 = "db"
  tags                 = local.tags
}

# Register the two app instances behind the ALB.
resource "aws_lb_target_group_attachment" "app" {
  count            = length(module.app.instance_ids)
  target_group_arn = module.alb.target_group_arn
  target_id        = module.app.instance_ids[count.index]
  port             = 80
}
