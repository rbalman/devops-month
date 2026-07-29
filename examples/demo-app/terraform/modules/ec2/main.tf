# A group of identical instances (app x2 or db x1), together with everything they
# own: their security group and one IAM role/instance-profile PER instance (each
# uniquely named). Public subnet + public IP; Ansible reaches them over SSH.

# --- Security group for this group ------------------------------------------
resource "aws_security_group" "this" {
  name        = "${var.name}-sg"
  description = "${var.role} instances"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name}-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.this.id
  description       = "SSH (Ansible deploy)"
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  cidr_ipv4         = var.ssh_ingress_cidr
}

# App traffic that comes from another SG (app←ALB:80, db←app:5432).
resource "aws_vpc_security_group_ingress_rule" "from_sg" {
  for_each                     = { for r in var.ingress_from_sg : r.description => r }
  security_group_id            = aws_security_group.this.id
  description                  = each.value.description
  from_port                    = each.value.port
  to_port                      = each.value.port
  ip_protocol                  = "tcp"
  referenced_security_group_id = each.value.source_security_group_id
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.this.id
  description       = "All egress (IGW: ECR, apt, Docker Hub)"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# --- One IAM role + instance profile per instance (unique names) ------------
resource "aws_iam_role" "this" {
  count = var.instance_count
  name  = "${var.name}-instance-${count.index + 1}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
  tags = var.tags
}

# Pull images from any ECR repo in the account (kept broad for this demo).
resource "aws_iam_role_policy" "ecr_pull" {
  count = var.instance_count
  name  = "ecr-pull"
  role  = aws_iam_role.this[count.index].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ecr:GetAuthorizationToken",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:BatchCheckLayerAvailability",
      ]
      Resource = "*"
    }]
  })
}

resource "aws_iam_instance_profile" "this" {
  count = var.instance_count
  name  = "${var.name}-instance-${count.index + 1}"
  role  = aws_iam_role.this[count.index].name
}

# --- The instances ----------------------------------------------------------
resource "aws_instance" "this" {
  count                       = var.instance_count
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = element(var.subnet_ids, count.index) # round-robin across AZs
  vpc_security_group_ids      = [aws_security_group.this.id]
  iam_instance_profile        = aws_iam_instance_profile.this[count.index].name
  key_name                    = var.key_name
  associate_public_ip_address = true

  # Enforce IMDSv2.
  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  tags = merge(var.tags, {
    Name = "${var.name}-instance-${count.index + 1}"
    Role = var.role
  })
}
