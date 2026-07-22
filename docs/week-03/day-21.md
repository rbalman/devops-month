# Day 7 · Terraform II — State, Backends & the Day 5 Stack

> Day 6 built one instance in a flat config with **local** state. Real teams need more: state that lives somewhere safe and shared, ways to compute values, and a way to stamp out *many* resources without copy-paste. Today you go deeper on **state**, move it to an **S3 backend**, learn **functions & expressions** and **loops** — then the payoff: rebuild the **entire Day 5 architecture** (two web servers, an ALB, a TLS certificate, and a Route 53 record) as Terraform code that stands up or tears down in one command.

!!! warning "Destroy at the end"
    Today's lab builds several billable resources (ALB, instances). `terraform destroy` when you're done — and this time you'll appreciate that it cleans up *everything* in one shot.

## Learning Objectives

- Understand the **state file** in depth — what it holds, drift, and why it's sensitive
- Store state in a **remote S3 backend** with locking
- Compute values with **functions & expressions**
- Create many resources with **loops** (`count`, `for_each`, `for`)
- **Lab:** reproduce the Day 5 web tier (2× EC2 + ALB + ACM + Route 53) entirely in Terraform

---

## Prerequisites

- Day 6 complete (Terraform installed, core workflow understood)
- Day 5 done at least once by hand — you have a **Route 53 hosted zone** for `web.example.com`
- AWS CLI configured

---

## Theory · ~20 min

### 1. State & the state file (deeper)

Terraform records everything it created in a **state file** (`terraform.tfstate`) — a JSON map from each resource address (`aws_instance.web`) to its real-world ID and attributes. On every `plan`, Terraform diffs **your code ↔ state ↔ reality** and does the minimum to reconcile.

Two things to internalize:

- **Drift** — when reality changes outside Terraform (someone edits a rule in the console), state no longer matches. `terraform plan` detects it and proposes to put it back.
- **State is sensitive** — it can contain secrets (passwords, keys) in plain text. Never commit it to git, never hand-edit it; use `terraform state` subcommands.

Local state is fine solo, but a shared file is a disaster for a team — which is why you move it to a backend.

!!! tip "📺 Watch — *Learn Terraform State in 10 Minutes*"
    A tightly chaptered tour of state and remote backends — today's core topic.

    [![Learn Terraform State in 10 Minutes](https://img.youtube.com/vi/yhLrH0Q-kq4/hqdefault.jpg){ width="360" }](https://youtu.be/yhLrH0Q-kq4)

    **Chapters:** [local state](https://youtu.be/yhLrH0Q-kq4?t=26) · [remote state](https://youtu.be/yhLrH0Q-kq4?t=226) · [backend configuration](https://youtu.be/yhLrH0Q-kq4?t=370) · [local → remote migration](https://youtu.be/yhLrH0Q-kq4?t=407)

### 2. Remote backend — S3

A **backend** stores state centrally so a whole team shares one source of truth; a **lock** prevents two `apply`s from clashing:

```hcl
terraform {
  backend "s3" {
    bucket       = "golive-tf-state-<you>"
    key          = "web/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true         # S3-native state locking (Terraform 1.10+)
  }
}
```

The bucket must exist **before** `init` (chicken-and-egg — you create it once with the CLI). `use_lockfile` keeps the lock in S3 itself; older setups used a separate **DynamoDB** table (`dynamodb_table = "..."`) instead.

### 3. Functions & expressions

HCL has built-in **functions** for strings, lists, maps, math, and more, plus **conditional** expressions:

```hcl
name    = "${local.project}-${var.env}"           # interpolation
subnets = slice(data.aws_subnets.default.ids, 0, 2)  # first two subnet IDs
size    = var.env == "prod" ? "t3.small" : "t3.micro"  # conditional
```

### 4. Loops — `count`, `for_each`, `for`

Stop copy-pasting resources:

```hcl
# count — N identical copies, indexed [0], [1], ...
resource "aws_instance" "web" {
  count         = 2
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  subnet_id     = element(data.aws_subnets.default.ids, count.index)
  tags          = { Name = "web-${count.index}" }
}

# for expression — transform a list into another list
output "web_ips" {
  value = [for i in aws_instance.web : i.public_ip]
}
```

Use **`count`** for N interchangeable copies; **`for_each`** when items have stable identity (a map/set) so removing one doesn't renumber the rest.

---

## Lab · ~60 min

Rebuild the **Day 5 stack** — two web servers behind an ALB, HTTPS via ACM, reachable at `web.example.com` — but this time as code. Work in a fresh dir; put the pieces in `main.tf` (split into files if you prefer).

### Step 1 — Bootstrap the S3 backend (once)

```bash
mkdir -p ~/tf-day5 && cd ~/tf-day5
aws s3 mb s3://golive-tf-state-$(whoami)      # note this bucket name
```

Add the backend block (bucket = the name above) to your `terraform` block, then `terraform init` and let it initialize the remote state.

### Step 2 — Provider, data sources, variables

```hcl
provider "aws" {
  region = var.region
}

data "aws_vpc" "default" {
  default = true
}
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}
data "aws_route53_zone" "web" {
  name = var.domain          # e.g. "web.example.com"
}

variable "region" {
  type    = string
  default = "us-east-1"
}
variable "domain" {
  type        = string
  description = "The subdomain hosted zone from Day 5, e.g. web.example.com"
}
locals {
  project = "golive"
}
```

### Step 3 — Security groups & two instances (a loop)

```hcl
# ALB security group — 80/443 open to the world
resource "aws_security_group" "alb" {
  name   = "${local.project}-alb-sg"
  vpc_id = data.aws_vpc.default.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Web security group — port 80 only from the ALB
resource "aws_security_group" "web" {
  name   = "${local.project}-web-sg"
  vpc_id = data.aws_vpc.default.id
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Two web servers — a count loop across the default subnets
resource "aws_instance" "web" {
  count                       = 2
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  subnet_id                   = element(data.aws_subnets.default.ids, count.index)
  vpc_security_group_ids      = [aws_security_group.web.id]
  associate_public_ip_address = true
  user_data                   = "#!/bin/bash\napt-get update -q && apt-get install -y nginx\necho '<h1>Terraform web ${count.index}</h1>' > /var/www/html/index.html"
  tags                        = { Name = "${local.project}-web-${count.index}" }
}
```

### Step 4 — ACM certificate (DNS-validated in Route 53)

```hcl
resource "aws_acm_certificate" "web" {
  domain_name       = var.domain
  validation_method = "DNS"
}

resource "aws_route53_record" "cert_validation" {
  for_each = { for o in aws_acm_certificate.web.domain_validation_options : o.domain_name => o }
  zone_id  = data.aws_route53_zone.web.zone_id
  name     = each.value.resource_record_name
  type     = each.value.resource_record_type
  records  = [each.value.resource_record_value]
  ttl      = 60
}

resource "aws_acm_certificate_validation" "web" {
  certificate_arn         = aws_acm_certificate.web.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}
```

### Step 5 — ALB, target group, listeners

```hcl
resource "aws_lb" "web" {
  name               = "${local.project}-alb"
  load_balancer_type = "application"
  subnets            = slice(data.aws_subnets.default.ids, 0, 2)
  security_groups    = [aws_security_group.alb.id]
}

resource "aws_lb_target_group" "web" {
  name     = "${local.project}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id
  health_check { path = "/" }
}

resource "aws_lb_target_group_attachment" "web" {
  count            = 2
  target_group_arn = aws_lb_target_group.web.arn
  target_id        = aws_instance.web[count.index].id
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.web.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = aws_acm_certificate_validation.web.certificate_arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}
```

### Step 6 — Route 53 alias record + outputs

```hcl
resource "aws_route53_record" "web" {
  zone_id = data.aws_route53_zone.web.zone_id
  name    = var.domain
  type    = "A"
  alias {
    name                   = aws_lb.web.dns_name
    zone_id                = aws_lb.web.zone_id
    evaluate_target_health = true
  }
}

output "alb_dns"  { value = aws_lb.web.dns_name }
output "web_ips"  { value = [for i in aws_instance.web : i.public_ip] }
```

### Step 7 — Apply, verify, destroy

```bash
terraform init
terraform fmt && terraform validate
terraform apply -var "domain=web.example.com"     # read the plan, type 'yes'

curl -k https://web.example.com                    # nginx page, load-balanced, over HTTPS
```

```bash
terraform destroy -var "domain=web.example.com"    # one command removes the whole stack
aws s3 rb s3://golive-tf-state-$(whoami) --force   # remove the state bucket when fully done
```

---

## Advanced Topics

Adjacent to today — read the linked resource for each:

- **Modules** — package this whole stack into a reusable, versioned unit with inputs/outputs → [Terraform — Modules](https://developer.hashicorp.com/terraform/language/modules)
- **Workspaces** — multiple named states from one config for `dev`/`staging`/`prod` → [Terraform — Workspaces](https://developer.hashicorp.com/terraform/language/state/workspaces)
- **`terraform_remote_state`** — one stack reads another's outputs (network → app) → [Terraform — remote_state data source](https://developer.hashicorp.com/terraform/language/state/remote-state-data)
- **CI/CD for Terraform** — `plan` on pull requests, `apply` on merge (Week 4 territory) → [Terraform — Automate Terraform with CI/CD](https://developer.hashicorp.com/terraform/tutorials/automation/automate-terraform)

---

## Assignment

**Deploy `site.zip` into the infrastructure Terraform built.** After `terraform apply` stands up the Day 5 stack, use the `web_ips` output to point **Ansible** at the two instances and deploy the **`site.zip`** from [Week 3 · Day 1](day-15.md) — install Docker + run an **nginx container on port 80** (same setup as the [Day 2 assignment](day-16.md#assignment)), so **`https://web.example.com` serves your site**, load-balanced across both instances.

This is the full DevOps loop, end to end: **provision with Terraform → configure with Ansible → verify → `terraform destroy`.**

Submit: the live URL (while it's up), a screenshot showing the **padlock + your site**, and the commands you ran (`terraform apply` → `ansible-playbook` → `terraform destroy`).

---

## Further Reading

**Watch**

- 📺 [Learn Terraform State in 10 Minutes](https://youtu.be/yhLrH0Q-kq4) — state, remote backends & locking, heavily chaptered

**Reference**

- [Terraform — State](https://developer.hashicorp.com/terraform/language/state) · [Backends (S3)](https://developer.hashicorp.com/terraform/language/backend/s3)
- [Terraform — Functions](https://developer.hashicorp.com/terraform/language/functions) · [Expressions](https://developer.hashicorp.com/terraform/language/expressions)
- [Terraform — `count`](https://developer.hashicorp.com/terraform/language/meta-arguments/count) · [`for_each`](https://developer.hashicorp.com/terraform/language/meta-arguments/for_each) · [`for` expressions](https://developer.hashicorp.com/terraform/language/expressions/for)
- [AWS provider — ALB, ACM & Route 53 resources](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
