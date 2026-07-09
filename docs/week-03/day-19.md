# Day 19 · Terraform I — Providers, Resources & Plan/Apply

## Learning Objectives

- Understand what Infrastructure as Code (IaC) is and why Terraform exists
- Write Terraform configuration to define cloud resources
- Use `terraform plan` and `terraform apply` to provision infrastructure

---

## Theory · ~20 min

### Infrastructure as Code

Before IaC, infrastructure was managed by clicking through web consoles or running manual shell scripts. Problems:
- Hard to reproduce exactly
- No version history
- Drift — what's running vs what's documented diverges over time

**Terraform** treats infrastructure like code: you describe what you want in `.tf` files, check them into Git, and Terraform figures out how to make it real.

### How Terraform Works

```
You write .tf files
    ↓
terraform init   → download providers (AWS, GCP, Azure plugins)
    ↓
terraform plan   → show what will change (dry run)
    ↓
terraform apply  → make it happen
    ↓
State file (.tfstate) → Terraform's memory of what it created
```

### Key Concepts

| Concept | Meaning |
|---|---|
| **Provider** | Plugin for a cloud/service (AWS, GCP, Docker, GitHub) |
| **Resource** | A piece of infrastructure (EC2 instance, S3 bucket, DNS record) |
| **Data source** | Read-only: look up existing resources |
| **Variable** | Input parameter to make configs reusable |
| **Output** | Values to display after apply (IPs, ARNs, URLs) |
| **State** | Terraform's record of what it has created |
| **Module** | Reusable group of resources |

### HCL Syntax

Terraform uses **HashiCorp Configuration Language (HCL)**:

```hcl
resource "aws_instance" "web" {
  ami           = "ami-0abcdef1234567890"
  instance_type = "t2.micro"

  tags = {
    Name = "my-webserver"
  }
}
```

`resource` = keyword, `"aws_instance"` = resource type, `"web"` = local name you give it.

---

## Lab · ~50 min

> For this lab we'll use the **Docker provider** locally (no AWS account needed yet). AWS comes on Day 22.

### Step 1 — Install Terraform

```bash
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

sudo apt update && sudo apt install -y terraform

terraform version
```

### Step 2 — Your first Terraform config (Docker provider)

```bash
mkdir -p ~/terraform-labs/docker-demo
cd ~/terraform-labs/docker-demo

cat > main.tf << 'EOF'
terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}

# Pull the nginx image
resource "docker_image" "nginx" {
  name         = "nginx:alpine"
  keep_locally = false
}

# Run a container
resource "docker_container" "nginx" {
  image = docker_image.nginx.image_id
  name  = "terraform-nginx"

  ports {
    internal = 80
    external = 8090
  }

  labels {
    label = "managed-by"
    value = "terraform"
  }
}

output "container_id" {
  value = docker_container.nginx.id
}

output "container_ip" {
  value = docker_container.nginx.network_data[0].ip_address
}
EOF
```

### Step 3 — Init, Plan, Apply

```bash
# Download the Docker provider plugin
terraform init

# Preview what will be created (no changes made)
terraform plan

# Apply — create the resources
terraform apply
# Type 'yes' when prompted

# Check it worked
docker ps | grep terraform-nginx
curl http://localhost:8090

# See Terraform's state
cat terraform.tfstate | head -50
terraform show
```

### Step 4 — Modify and update

```bash
# Change the external port
cat > main.tf << 'EOF'
terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}

resource "docker_image" "nginx" {
  name         = "nginx:alpine"
  keep_locally = false
}

resource "docker_container" "nginx" {
  image = docker_image.nginx.image_id
  name  = "terraform-nginx"

  ports {
    internal = 80
    external = 8091    # changed from 8090
  }

  env = ["NGINX_HOST=terraform-demo"]

  labels {
    label = "managed-by"
    value = "terraform"
  }
}

output "container_id" {
  value = docker_container.nginx.id
}
EOF

# Plan shows what will change
terraform plan

# Apply the change
terraform apply

# Old port is gone, new port is active
curl http://localhost:8091
```

### Step 5 — Variables and outputs

```bash
cat > variables.tf << 'EOF'
variable "nginx_image" {
  description = "Docker image to use for nginx"
  type        = string
  default     = "nginx:alpine"
}

variable "external_port" {
  description = "Host port to expose nginx on"
  type        = number
  default     = 8090
}

variable "container_name" {
  description = "Name of the container"
  type        = string
  default     = "terraform-nginx"
}
EOF

# Update main.tf to use variables
cat > main.tf << 'EOF'
terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}

resource "docker_image" "nginx" {
  name         = var.nginx_image
  keep_locally = false
}

resource "docker_container" "nginx" {
  image = docker_image.nginx.image_id
  name  = var.container_name

  ports {
    internal = 80
    external = var.external_port
  }
}

output "container_name" {
  value = docker_container.nginx.name
}

output "access_url" {
  value = "http://localhost:${var.external_port}"
}
EOF

# Apply with default values
terraform apply

# Override a variable at the command line
terraform apply -var="external_port=8092" -var="container_name=nginx-v2"

# Clean up
terraform destroy
docker ps   # should be empty
```

---

## Assignment

1. What is the difference between `terraform plan` and `terraform apply`?
2. What is the Terraform state file and why is it important? What happens if you delete it?
3. Create a Terraform config that runs **two** Nginx containers — one on port 8080 and one on port 8081. Use a `count` or two separate resources.
4. What does `terraform destroy` do? When would you use it?

---

## Further Reading

- [Terraform getting started — Docker](https://developer.hashicorp.com/terraform/tutorials/docker-get-started)
- [Terraform registry — all providers](https://registry.terraform.io/)
- [HCL language documentation](https://developer.hashicorp.com/terraform/language)
