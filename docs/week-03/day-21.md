# Day 7 · Terraform II — Functions, Modules, Backends & Capstone

> Day 6 gave you one flat config for one stack. Real infrastructure is bigger and *repeated* — dev/staging/prod, many services, a whole team editing it. Today you make Terraform **reusable and collaborative**: **functions** and `for_each` to stop copy-pasting, **modules** to package a stack into a callable unit, and a **remote backend** so state lives safely in S3 with a lock so two people can't corrupt it. Then the **capstone**: the entire Go Live web tier — network, security group, instances — as one reusable module you can stand up or tear down in a single command.

!!! warning "Destroy at the end"
    The capstone builds several billable resources. `terraform destroy` when you're done — and this time you'll appreciate that it cleans up *everything* the module made.

## Learning Objectives

- Use **functions** and **expressions** to compute values
- Create many resources with **`count`** and **`for_each`**
- Package infrastructure as a reusable **module** with inputs and outputs
- Store state in a **remote backend** (S3) with **locking** (DynamoDB)
- Keep code clean with **`fmt`**, **`validate`**, and **workspaces**
- **Capstone:** deploy a complete, reproducible web tier

---

## Prerequisites

- Day 6 complete (Terraform installed, core workflow understood)
- AWS CLI configured; the `~/tf-golive` project as a starting point

---

## Theory · ~20 min

### 1. Functions & expressions

Terraform's language (HCL) has built-in **functions** for strings, lists, maps, math, and more:

```hcl
name       = "${local.project}-${var.env}"     # interpolation
upper_name = upper(var.env)                      # → "PROD"
azs        = slice(data.aws_availability_zones.all.names, 0, 2)
cidr       = cidrsubnet("10.0.0.0/16", 8, 1)     # → 10.0.1.0/24
```

### 2. `count` and `for_each`

Stop copy-pasting resources. **`count`** makes N identical copies; **`for_each`** iterates a map/set for named, stable instances:

```hcl
resource "aws_instance" "web" {
  for_each      = toset(["web1", "web2"])
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  tags          = { Name = each.key }
}
```

`for_each` is preferred when items have identity (removing one doesn't renumber the rest).

### 3. Modules

A **module** is a folder of `.tf` files with **input variables** and **outputs** — a reusable component you call with a `module` block:

```hcl
module "web_tier" {
  source        = "./modules/web-tier"
  instance_count = 2
  env            = "prod"
}

output "alb_dns" { value = module.web_tier.alb_dns }
```

Every Terraform config is already a "root module"; you're just factoring pieces out. Modules can also come from the **[Terraform Registry](https://registry.terraform.io)**.

### 4. Remote backends & locking

By default state is a local file — fine solo, disastrous for a team. A **remote backend** stores it centrally; a lock stops two applies from clashing:

```hcl
terraform {
  backend "s3" {
    bucket         = "golive-tf-state"
    key            = "web/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "golive-tf-lock"     # lock table
    encrypt        = true
  }
}
```

Now `terraform apply` reads/writes state in S3 and grabs a DynamoDB lock for the duration.

!!! tip "📺 Watch — *Learn Terraform State in 10 Minutes*"
    A tightly chaptered tour of state and remote backends — today's core topic.

    [![Learn Terraform State in 10 Minutes](https://img.youtube.com/vi/yhLrH0Q-kq4/hqdefault.jpg){ width="360" }](https://youtu.be/yhLrH0Q-kq4)

    **Chapters:** [local state](https://youtu.be/yhLrH0Q-kq4?t=26) · [remote state](https://youtu.be/yhLrH0Q-kq4?t=226) · [backend configuration](https://youtu.be/yhLrH0Q-kq4?t=370) · [local → remote migration](https://youtu.be/yhLrH0Q-kq4?t=407)

### 5. `fmt`, `validate`, workspaces

- **`terraform fmt`** — canonical formatting (run it in CI).
- **`terraform validate`** — catches errors before touching AWS.
- **Workspaces** — multiple named states from one config (`terraform workspace new staging`) for env separation.

---

## Lab · ~50 min

### Step 1 — Bootstrap the remote backend

```bash
cd ~/tf-golive
# Create the state bucket + lock table ONCE (chicken-and-egg: make these first, by CLI)
aws s3 mb s3://golive-tf-state-$(whoami)
aws dynamodb create-table --table-name golive-tf-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

Add the `backend "s3"` block (bucket = the name above) to `main.tf`, then:

```bash
terraform init          # Terraform offers to migrate local state → S3; say yes
```

### Step 2 — Factor the stack into a module

```bash
mkdir -p modules/web-tier
# Move the SG + instance resources into modules/web-tier/main.tf,
# with variables.tf (inputs) and outputs.tf (public_ips) inside the module.
```

`modules/web-tier/variables.tf`:

```hcl
variable "instance_count" { type = number, default = 2 }
variable "my_ip"          { type = string }
variable "env"            { type = string, default = "dev" }
```

`modules/web-tier/main.tf` (uses `for_each`/`count` over `instance_count`), `outputs.tf`:

```hcl
output "public_ips" { value = [for i in aws_instance.web : i.public_ip] }
```

### Step 3 — Call the module from root

```bash
cat > main.tf << 'EOF'
terraform {
  backend "s3" { bucket = "golive-tf-state-<you>", key = "web/terraform.tfstate", region = "us-east-1", dynamodb_table = "golive-tf-lock", encrypt = true }
  required_providers { aws = { source = "hashicorp/aws", version = "~> 5.0" } }
}
provider "aws" { region = "us-east-1" }

module "web_tier" {
  source         = "./modules/web-tier"
  instance_count = 2
  my_ip          = var.my_ip
  env            = "prod"
}

output "web_ips" { value = module.web_tier.public_ips }
EOF

terraform init          # registers the module
terraform fmt && terraform validate
terraform apply -var "my_ip=$(curl -s https://checkip.amazonaws.com)"
```

### Step 4 — Scale by changing one number

```bash
# Bump instance_count 2 → 3, then:
terraform plan -var "my_ip=$(curl -s https://checkip.amazonaws.com)"    # one new instance, nothing else
```

That single-number change is the whole point of modules.

### Step 5 — 🔻 Capstone teardown

```bash
terraform destroy -var "my_ip=$(curl -s https://checkip.amazonaws.com)"
# then remove the backend resources if you're fully done:
aws dynamodb delete-table --table-name golive-tf-lock
aws s3 rb s3://golive-tf-state-<you> --force
```

---

## Capstone · Infrastructure as Code, end to end

Tie the week together. Deliver a git repo that, from nothing, stands up the Go Live web tier:

1. A **Terraform module** that provisions a security group + N EC2 instances (bonus: a VPC + ALB) with a remote S3 backend.
2. An **Ansible role** (from Days 1–2) that configures nginx + a templated homepage on those instances.
3. A short **README** with the exact commands: `terraform apply` → grab the output IPs → `ansible-playbook` → `curl` → `terraform destroy`.

The grader should be able to run it, see your site load-balanced across instances, and destroy it — spending pennies. That's the DevOps loop: **provision (Terraform) → configure (Ansible) → verify → destroy.**

---

## Advanced Topics

- **Module registry & versioning** — publish modules and pin `version = "~> 1.2"` for stability.
- **`terraform_remote_state`** — one stack reads another's outputs (e.g. network stack → app stack).
- **CI/CD for Terraform** — `plan` on pull requests, `apply` on merge (Week 4 territory).
- **Policy as code** — Sentinel/OPA to enforce "no public S3 buckets" before apply.

---

## Assignment

The **capstone above is the assignment.** Additionally:

1. **Two environments.** Use `terraform workspace` (or a `dev.tfvars`/`prod.tfvars` split) to deploy the module twice — `dev` (1 instance) and `prod` (2). Show both live, then destroy both.
2. **Reflect on the week.** In one page: where does Terraform stop and Ansible begin? When would you reach for each, and why did AWS-by-hand (Days 3–5) make the Terraform code make sense?

---

## Further Reading

**Watch**

- 📺 [Learn Terraform State in 10 Minutes](https://youtu.be/yhLrH0Q-kq4) — state, remote backends & locking, heavily chaptered

**Reference**

- [Terraform — Modules](https://developer.hashicorp.com/terraform/language/modules)
- [Terraform — Backends](https://developer.hashicorp.com/terraform/language/settings/backends/s3) · [State locking](https://developer.hashicorp.com/terraform/language/state/locking)
- [Terraform — Functions](https://developer.hashicorp.com/terraform/language/functions) · [`for_each`](https://developer.hashicorp.com/terraform/language/meta-arguments/for_each)
- [Terraform Registry](https://registry.terraform.io) — community modules and providers
