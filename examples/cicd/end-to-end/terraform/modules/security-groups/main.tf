# Three tiers, each only as open as it needs to be:
#
#   internet ──80/443──▶ alb ──80──▶ app ──5432──▶ db
#
# The app SG only accepts traffic from the ALB SG; the db SG only from the app
# SG. Nothing takes SSH from the world — management is over SSM (no SSH at all).

# --- ALB: public HTTP/HTTPS -------------------------------------------------
resource "aws_security_group" "alb" {
  name        = "${var.name}-alb"
  description = "ALB: HTTP/HTTPS from the internet"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name}-alb" })
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTPS"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "alb_all" {
  security_group_id = aws_security_group.alb.id
  description       = "All egress"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# --- App instances: HTTP only, only from the ALB ----------------------------
resource "aws_security_group" "app" {
  name        = "${var.name}-app"
  description = "App: HTTP from the ALB only"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name}-app" })
}

resource "aws_vpc_security_group_ingress_rule" "app_http_from_alb" {
  security_group_id            = aws_security_group.app.id
  description                  = "HTTP from ALB"
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.alb.id
}

resource "aws_vpc_security_group_egress_rule" "app_all" {
  security_group_id = aws_security_group.app.id
  description       = "All egress (NAT: ECR, SSM, apt)"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# --- DB instance: Postgres only, only from the app --------------------------
resource "aws_security_group" "db" {
  name        = "${var.name}-db"
  description = "DB: Postgres from the app only"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name}-db" })
}

resource "aws_vpc_security_group_ingress_rule" "db_pg_from_app" {
  security_group_id            = aws_security_group.db.id
  description                  = "Postgres from app"
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.app.id
}

resource "aws_vpc_security_group_egress_rule" "db_all" {
  security_group_id = aws_security_group.db.id
  description       = "All egress (NAT: ECR, SSM, apt)"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
