# Day 6 · Terraform I — IaC, HCL & the Core Workflow

> For three days you built AWS resources by hand — clicking consoles, copying IDs, and tearing down with a checklist you could forget. It worked, but it isn't **reproducible**: nobody can recreate your exact stack. **Terraform** fixes that. You *declare* the infrastructure you want in code, Terraform makes reality match, and `terraform destroy` removes every last piece. Today you'll learn what Infrastructure as Code is, how Terraform's language and architecture work, then rebuild **Day 4's EC2 + security group** in code you can apply, share, and destroy with one command.

!!! warning "Still real AWS resources"
    Terraform creates the same billable resources you made by hand. The upside: `terraform destroy` is a *reliable* teardown — no more hunting for stray resources. Always `destroy` at the end of a lab.

## Learning Objectives

- Explain **Infrastructure as Code** and name common IaC tools
- Describe **Terraform**, its creator, and how it relates to **OpenTofu**
- Contrast **Terraform vs Ansible** and see why they're **complementary**
- Read **HCL** and describe Terraform's **architecture** (CLI, providers, resources, state)
- Use the core building blocks: **variables & types, locals, resources, data sources, outputs**
- Run the core workflow **`init → plan → apply → destroy`**

---

## Prerequisites

- Day 4 complete: an AWS account, an IAM user, and the **AWS CLI configured** (Terraform reuses those credentials)
- **Ubuntu 24.04** (the lab installs Terraform there)

---

## Theory · ~25 min

### 1. What is Infrastructure as Code?

**Infrastructure as Code (IaC)** means defining your servers, networks, and other infrastructure in **machine-readable files** instead of clicking through a console. Those files live in git — so your infrastructure becomes **versioned, reviewable, reproducible, and self-documenting**, and tearing it down is one command instead of a checklist.

Common IaC tools:

| Tool | Scope / language |
|---|---|
| **Terraform / OpenTofu** | Cloud-agnostic provisioning · HCL |
| **AWS CloudFormation** | AWS-only · JSON/YAML |
| **Pulumi** | Provisioning in real languages (Python, TS, Go) |
| **Azure Bicep / ARM** | Azure-only |
| **Ansible** | Config management (+ some provisioning) · YAML |

### 2. Terraform & OpenTofu

Terraform was created by **HashiCorp** (co-founded by **Mitchell Hashimoto**) and first released in **2014**. In 2023 HashiCorp relicensed Terraform from the open-source MPL to the **Business Source License (BSL)**; in response the community forked the last open version into **OpenTofu**, now stewarded by the **Linux Foundation**. OpenTofu is a **drop-in, open-source alternative** — same HCL, same workflow, just `tofu` instead of `terraform`. This course uses Terraform; everything here applies to OpenTofu too.

!!! tip "📺 Watch — *Terraform in 100 Seconds* (Fireship)"
    What Terraform is and the declarative IaC model, in under two minutes.

    [![Terraform in 100 Seconds](https://img.youtube.com/vi/tomUWcQ0P3k/hqdefault.jpg){ width="360" }](https://youtu.be/tomUWcQ0P3k)

### 3. Terraform vs Ansible

| | **Terraform** | **Ansible** |
|---|---|---|
| Model | Declarative (desired state) | Procedural (ordered tasks) |
| Best at | **Provisioning** infra (VMs, networks, LBs, DNS) | **Configuring** inside (packages, files, services) |
| State | Tracks state | Stateless |
| Language | HCL | YAML |
| Connects via | Cloud APIs | SSH |

They are **complementary, not competitors.** Terraform builds the servers; Ansible configures what runs on them. The DevOps loop you've seen all week: **provision (Terraform) → configure (Ansible) → verify → destroy.**

### 4. HCL — the Terraform language

Terraform is written in **HashiCorp Configuration Language (HCL)** — declarative and block-based. A config is a set of blocks:

```hcl
# block form:  <type> "<label>" ["<name>"] { arguments }
terraform { ... }                         # settings & required providers
provider  "aws" { ... }                   # configure a provider
resource  "aws_instance" "web" { ... }    # something to create
variable  "region" { ... }                # an input
output    "ip" { ... }                    # a value to print
```

Comments use `#`; strings interpolate with `${...}`; you reference other objects by address (`aws_instance.web.id`). Inside a block, arguments go on their own lines; commas only appear inside list/map literals.

### 5. Terraform architecture

| Piece | Role |
|---|---|
| **CLI** | the `terraform` binary you run (`init`, `plan`, `apply`…) |
| **Provider** | a plugin that speaks one platform's API (`aws`, `google`, `azurerm`, …) |
| **Resource** | one infrastructure object a provider manages (e.g. `aws_instance`) |
| **State** | Terraform's record of everything it created |
| **Cloud / infra** | the real API endpoints the provider calls |

Flow: you write **HCL** → the **CLI** loads a **provider** → the provider calls the **cloud API** → Terraform records the result in **state**.

### 6. Core building blocks

```hcl
# variables & types — inputs to your config
variable "instance_type" {
  type    = string
  default = "t3.micro"
}
# types: string, number, bool, list(...), set(...), map(...), object({...})

# locals — computed / shared values, named once
locals {
  project = "golive"
}

# data — READ something that already exists (don't create it)
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

# resource — something to CREATE
resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  tags          = { Name = "${local.project}-web" }
}

# output — print a value after apply
output "public_ip" {
  value = aws_instance.web.public_ip
}
```

### 7. The core workflow

| Command | What it does |
|---|---|
| `terraform init` | Download providers, prepare the working dir |
| `terraform fmt` / `validate` | Format and syntax-check |
| `terraform plan` | Preview the changes (nothing applied) |
| `terraform apply` | Make reality match — after you confirm |
| `terraform destroy` | Delete everything in state |

**Always read the plan** before approving: `+` creates, `~` updates, `-` destroys.

---

## Lab · ~50 min

Run on your Ubuntu 24.04 host — Terraform uses your configured AWS CLI credentials.

### Step 1 — Install Terraform (Ubuntu 24.04)

```bash
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install -y terraform
terraform -version
```

### Step 2 — A "Hello, World" project

```bash
mkdir -p ~/tf-hello && cd ~/tf-hello
cat > main.tf << 'EOF'
output "hello" {
  value = "Hello, World — from Terraform!"
}
EOF
terraform init
terraform apply -auto-approve     # prints the hello output — no cloud yet
```

Proof the workflow runs. Now let's create something real.

### Step 3 — A security group + EC2, with its IP as output

```bash
mkdir -p ~/tf-golive && cd ~/tf-golive

cat > main.tf << 'EOF'
terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
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

resource "aws_security_group" "web" {
  name        = "${local.project}-sg"
  description = "SSH + HTTP"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.my_ip}/32"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
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

resource "aws_instance" "web" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.web.id]
  tags                   = { Name = "${local.project}-web" }
}
EOF

cat > variables.tf << 'EOF'
variable "region" {
  type    = string
  default = "us-east-1"
}
variable "instance_type" {
  type    = string
  default = "t3.micro"
}
variable "my_ip" {
  type        = string
  description = "Your public IP for SSH"
}
locals {
  project = "golive"
}
EOF

cat > outputs.tf << 'EOF'
output "public_ip" {
  value = aws_instance.web.public_ip
}
EOF
```

### Step 4 — Run the core workflow

```bash
terraform init                 # downloads the AWS provider
terraform fmt && terraform validate
terraform plan  -var "my_ip=$(curl -s https://checkip.amazonaws.com)"
terraform apply -var "my_ip=$(curl -s https://checkip.amazonaws.com)"   # type 'yes'

terraform output public_ip     # your EC2 IP, printed by the output block
```

### Step 5 — 🔻 Teardown (the easy way)

```bash
terraform destroy -var "my_ip=$(curl -s https://checkip.amazonaws.com)"   # type 'yes'
```

One command removes the instance **and** the security group. *This* is why IaC beats the manual checklist.

---

## Advanced Topics

Adjacent to today — read the linked resource for each:

- **`terraform.tfvars`** — drop variables in this file and Terraform auto-loads them (no `-var` flags) → [Terraform — Variable definition files](https://developer.hashicorp.com/terraform/language/values/variables#variable-definitions-tfvars-files)
- **Explicit dependencies (`depends_on`)** — force ordering Terraform can't infer from references → [Terraform — depends_on](https://developer.hashicorp.com/terraform/language/meta-arguments/depends_on)
- **`terraform import`** — bring an existing hand-made resource under Terraform's management → [Terraform — Import](https://developer.hashicorp.com/terraform/cli/import)
- **Provisioners** — run scripts on a resource after creation; a last resort (prefer user-data or Ansible) → [Terraform — Provisioners](https://developer.hashicorp.com/terraform/language/resources/provisioners/syntax)

---

## Assignment

1. **Parameterize with `terraform.tfvars`.** Move `region`, `instance_type`, and `my_ip` into a `terraform.tfvars` file, drop the `-var` flags, and re-run the workflow. Submit the `plan` output showing it picked the values up.
2. **More outputs.** Add outputs for the **instance ID** and the **AMI ID** the data source resolved, then show `terraform output`.

---

## Further Reading

**Watch**

- 📺 [Terraform in 100 Seconds](https://youtu.be/tomUWcQ0P3k) (Fireship) — the fastest intro
- 📺 [Terraform explained in 10 mins](https://youtu.be/h6rkauDhDUM) — a chaptered walkthrough of the core workflow

**Reference**

- [Terraform — Get Started (AWS)](https://developer.hashicorp.com/terraform/tutorials/aws-get-started)
- [Terraform — HCL language](https://developer.hashicorp.com/terraform/language) · [Resources](https://developer.hashicorp.com/terraform/language/resources) · [Data sources](https://developer.hashicorp.com/terraform/language/data-sources)
- [OpenTofu](https://opentofu.org/) — the open-source fork of Terraform
- [AWS provider registry](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
