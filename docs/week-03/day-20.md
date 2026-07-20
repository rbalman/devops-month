# Day 6 · Terraform I — Providers, Resources & the Core Workflow

> For three days you built AWS resources by hand — clicking consoles, copying IDs, running `aws` commands, and carefully tearing down. It worked, but it's not **reproducible**: nobody can recreate your exact stack, and "teardown" was a manual checklist you could forget. **Terraform** fixes that. You *declare* the infrastructure you want in code; Terraform figures out the API calls to make reality match, and `terraform destroy` removes every last piece. Today you'll rebuild Day 3's EC2 + security group — but this time in code you can apply, share, and destroy with one command.

!!! warning "Still real AWS resources"
    Terraform creates the same billable resources you made by hand. The upside: `terraform destroy` is a *reliable* teardown — no more hunting for stray load balancers. Always `destroy` at the end of a lab.

## Learning Objectives

- Explain **Infrastructure as Code** and how Terraform differs from Ansible
- Configure a **provider** and declare **resources**
- Understand **state** — how Terraform tracks what it manages
- Run the core workflow: **`init` → `plan` → `apply` → `destroy`**
- Parameterize with **variables** and `.tfvars`, expose **outputs**, simplify with **locals**
- Query existing infrastructure with **data sources**

---

## Prerequisites

- Day 3 complete: an AWS account, an IAM user, and the **AWS CLI configured** (Terraform reuses those credentials)
- A key pair name you can reference (or create one in the lab)

---

## Theory · ~20 min

### 1. Infrastructure as Code

Terraform is **declarative**: you describe the *desired end state*, not the steps. Contrast with Ansible, which is *procedural* (a list of tasks). They're complementary — **Terraform provisions** infrastructure (VMs, networks, load balancers); **Ansible configures** what runs inside it. Terraform's superpower is that it keeps a record (**state**) of everything it made, so it can update or delete precisely.

!!! tip "📺 Watch — *Terraform in 100 Seconds* (Fireship)"
    What Terraform is and the declarative IaC model, in under two minutes.

    [![Terraform in 100 Seconds](https://img.youtube.com/vi/tomUWcQ0P3k/hqdefault.jpg){ width="360" }](https://youtu.be/tomUWcQ0P3k)

### 2. Providers

A **provider** is a plugin that teaches Terraform an API — `aws`, `google`, `azurerm`, `kubernetes`, hundreds more. You declare it and Terraform downloads it on `init`:

```hcl
terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region = "us-east-1"
}
```

### 3. Resources

A **resource** is one piece of infrastructure. `type` + `name` gives it an address (`aws_instance.web`):

```hcl
resource "aws_instance" "web" {
  ami           = "ami-0abcd1234"
  instance_type = "t3.micro"
  tags = { Name = "golive-web" }
}
```

### 4. State

Terraform records what it created in a **state file** (`terraform.tfstate`). On the next `apply`, it diffs your code against state against reality, and does the minimum to reconcile. **State is sensitive** (it can hold secrets) and must not be hand-edited. (Tomorrow: storing it remotely so a team can share it.)

### 5. The core workflow

| Command | What it does |
|---|---|
| `terraform init` | Download providers, prepare the working dir |
| `terraform fmt` / `validate` | Format and syntax-check |
| `terraform plan` | Preview the changes (nothing applied) |
| `terraform apply` | Make reality match — after you confirm |
| `terraform destroy` | Delete everything in state |

**Always read the plan** before approving. `+` creates, `~` updates, `-` destroys.

### 6. Variables, outputs, locals

```hcl
variable "instance_type" {
  type    = string
  default = "t3.micro"
}

locals {
  project = "golive"            # computed/shared values
}

output "public_ip" {
  value = aws_instance.web.public_ip   # printed after apply
}
```

Set variables via defaults, a `terraform.tfvars` file, `-var`, or `TF_VAR_` env vars.

### 7. Data sources

A **data source** *reads* something that already exists rather than creating it — e.g. look up the latest Ubuntu AMI instead of hard-coding an ID:

```hcl
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}
# reference: data.aws_ami.ubuntu.id
```

---

## Lab · ~50 min

Run on your host (Terraform uses your configured AWS CLI credentials).

### Step 1 — Install Terraform

```bash
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install -y terraform
terraform -version
```

### Step 2 — Write the configuration

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
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_security_group" "web" {
  name        = "${local.project}-sg"
  description = "HTTP + SSH"
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.my_ip}/32"]
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
  user_data              = "#!/bin/bash\napt-get update -q && apt-get install -y nginx\necho '<h1>Provisioned by Terraform</h1>' > /var/www/html/index.html"
  tags = { Name = "${local.project}-web" }
}
EOF

cat > variables.tf << 'EOF'
variable "region"        { default = "us-east-1" }
variable "instance_type" { default = "t3.micro" }
variable "my_ip"         { description = "Your public IP for SSH" }
locals { project = "golive" }
EOF

cat > outputs.tf << 'EOF'
output "public_ip" { value = aws_instance.web.public_ip }
output "ami_used"  { value = data.aws_ami.ubuntu.id }
EOF
```

### Step 3 — The core workflow

```bash
terraform init                 # downloads the AWS provider
terraform fmt && terraform validate
terraform plan -var "my_ip=$(curl -s https://checkip.amazonaws.com)"
terraform apply -var "my_ip=$(curl -s https://checkip.amazonaws.com)"   # type 'yes'
```

After apply, Terraform prints your outputs:

```bash
terraform output public_ip
curl http://$(terraform output -raw public_ip)     # → Provisioned by Terraform
```

### Step 4 — Inspect state, then change it

```bash
terraform state list           # aws_instance.web, aws_security_group.web, ...
```

Change `instance_type` to `t3.small` in `variables.tf`, then `plan` — see the `~`/`-/+` and note Terraform *replaces* the instance. Revert it.

### Step 5 — 🔻 Teardown (the easy way)

```bash
terraform destroy -var "my_ip=$(curl -s https://checkip.amazonaws.com)"    # type 'yes'
```

One command removes the instance **and** the security group. Confirm the console is empty. *This* is why IaC beats the manual checklist.

---

## Advanced Topics

- **`terraform.tfvars`** — drop variables in this file and Terraform loads them automatically (no `-var` flags).
- **Dependency graph** — Terraform infers order from references (`aws_instance.web` needs `aws_security_group.web`), but `depends_on` forces it when needed.
- **`terraform import`** — bring an existing hand-made resource under Terraform's management.
- **Provisioners** — run scripts on a resource after creation; treat as a last resort (prefer user-data or Ansible).

---

## Assignment

1. **Full `.tfvars`.** Move all variables (region, instance_type, my_ip) into `terraform.tfvars`, remove the `-var` flags, and re-run the workflow. Submit `plan` output showing it picked them up.
2. **Two instances, one output.** Add a second instance and an output that lists **both** public IPs (hint: a list). Apply, curl both, destroy.
3. **Ansible + Terraform.** After `apply`, feed the output IP into your Week-3 Ansible inventory and run your `webserver` role against the Terraform-provisioned box. Explain in two sentences which tool did what.

---

## Further Reading

**Watch**

- 📺 [Terraform in 100 Seconds](https://youtu.be/tomUWcQ0P3k) (Fireship) — the fastest intro
- 📺 [Terraform explained in 10 mins](https://youtu.be/h6rkauDhDUM) — a chaptered walkthrough of the core workflow

**Reference**

- [Terraform — Get Started (AWS)](https://developer.hashicorp.com/terraform/tutorials/aws-get-started)
- [Terraform — Resources](https://developer.hashicorp.com/terraform/language/resources) · [Data sources](https://developer.hashicorp.com/terraform/language/data-sources)
- [Terraform — State](https://developer.hashicorp.com/terraform/language/state)
- [AWS provider registry](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
