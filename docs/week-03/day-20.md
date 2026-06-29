# Day 20 · Terraform II — State, Variables & Modules

## Learning Objectives

- Understand Terraform state in depth and how to manage it
- Use input variables, local values, and output values effectively
- Create and use a reusable Terraform module

---

## Theory · ~20 min

### Terraform State

The state file (`terraform.tfstate`) is Terraform's database of the real-world resources it manages. It stores:
- What resources exist
- Their attributes (IDs, IPs, ARNs)
- Dependencies between resources

**What happens without state**: Terraform can't know what it previously created, so it would try to create everything again.

**Remote state** is the production pattern. Instead of a local file, state lives in a shared backend (S3, Terraform Cloud, GCS). This enables:
- Team collaboration (no "who has the state file?")
- State locking (prevent two people applying at once)
- Versioning and backup

```hcl
# Remote state in S3 (Day 22+ topic, preview here)
terraform {
  backend "s3" {
    bucket = "my-terraform-state"
    key    = "prod/terraform.tfstate"
    region = "us-east-1"
  }
}
```

### Variable Types

```hcl
variable "instance_count" {
  type        = number
  default     = 1
  description = "Number of instances to create"
}

variable "tags" {
  type = map(string)
  default = {
    Environment = "dev"
    Owner       = "balman"
  }
}

variable "allowed_ports" {
  type    = list(number)
  default = [80, 443, 22]
}
```

### Locals

Locals are intermediate values — computed from variables or resource attributes:

```hcl
locals {
  env        = var.environment
  name_prefix = "${var.project}-${local.env}"
}

resource "docker_container" "app" {
  name = "${local.name_prefix}-app"
}
```

### Modules

A module is a directory of `.tf` files that you call from another config. It's the primary reuse mechanism in Terraform.

```hcl
# Calling a module
module "web_server" {
  source = "./modules/nginx"    # local path, or registry URL

  port         = 8080
  container_name = "web"
}

# Using module outputs
output "server_url" {
  value = module.web_server.url
}
```

---

## Lab · ~50 min

### Step 1 — Explore state commands

```bash
cd ~/terraform-labs/docker-demo

# Apply something first if not already done
terraform apply

# List all resources in state
terraform state list

# Show details of a specific resource
terraform state show docker_container.nginx

# Move a resource to a different name (renaming without recreating)
# terraform state mv docker_container.nginx docker_container.web

# Remove a resource from state (without destroying it)
# terraform state rm docker_container.nginx

# Import an existing resource into state
docker run -d --name manual-nginx nginx:alpine
CONTAINER_ID=$(docker inspect manual-nginx --format '{{.Id}}')
# terraform import docker_container.nginx $CONTAINER_ID
# (Not running this to keep things simple)

docker rm -f manual-nginx
```

### Step 2 — Variables file (terraform.tfvars)

```bash
mkdir -p ~/terraform-labs/variables-demo
cd ~/terraform-labs/variables-demo

cat > variables.tf << 'EOF'
variable "project_name" {
  type        = string
  description = "Project name prefix for all resources"
}

variable "environment" {
  type        = string
  description = "Deployment environment"
  default     = "dev"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "app_port" {
  type        = number
  default     = 8080
}

variable "replicas" {
  type        = number
  default     = 1
}
EOF

cat > locals.tf << 'EOF'
locals {
  name_prefix = "${var.project_name}-${var.environment}"
  common_labels = {
    project     = var.project_name
    environment = var.environment
    managed_by  = "terraform"
  }
}
EOF

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

resource "docker_image" "app" {
  name         = "nginx:alpine"
  keep_locally = true
}

resource "docker_container" "app" {
  count = var.replicas
  image = docker_image.app.image_id
  name  = "${local.name_prefix}-app-${count.index}"

  ports {
    internal = 80
    external = var.app_port + count.index
  }

  dynamic "labels" {
    for_each = local.common_labels
    content {
      label = labels.key
      value = labels.value
    }
  }
}
EOF

cat > outputs.tf << 'EOF'
output "container_names" {
  value = docker_container.app[*].name
}

output "access_urls" {
  value = [for c in docker_container.app : "http://localhost:${c.ports[0].external}"]
}
EOF

# Create a tfvars file
cat > terraform.tfvars << 'EOF'
project_name = "devops-month"
environment  = "dev"
app_port     = 8080
replicas     = 2
EOF

terraform init
terraform plan
terraform apply

# See the outputs
terraform output
curl http://localhost:8080
curl http://localhost:8081
```

### Step 3 — Build a reusable module

```bash
mkdir -p ~/terraform-labs/modules-demo/modules/nginx-container

# Module files
cat > ~/terraform-labs/modules-demo/modules/nginx-container/variables.tf << 'EOF'
variable "name" {
  type = string
}

variable "port" {
  type    = number
  default = 80
}

variable "image" {
  type    = string
  default = "nginx:alpine"
}
EOF

cat > ~/terraform-labs/modules-demo/modules/nginx-container/main.tf << 'EOF'
terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

resource "docker_image" "this" {
  name         = var.image
  keep_locally = true
}

resource "docker_container" "this" {
  image = docker_image.this.image_id
  name  = var.name

  ports {
    internal = 80
    external = var.port
  }
}
EOF

cat > ~/terraform-labs/modules-demo/modules/nginx-container/outputs.tf << 'EOF'
output "container_name" {
  value = docker_container.this.name
}

output "url" {
  value = "http://localhost:${var.port}"
}
EOF

# Root config that calls the module
cat > ~/terraform-labs/modules-demo/main.tf << 'EOF'
terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}

module "frontend" {
  source = "./modules/nginx-container"
  name   = "frontend"
  port   = 8080
}

module "backend_proxy" {
  source = "./modules/nginx-container"
  name   = "backend-proxy"
  port   = 8081
  image  = "nginx:latest"
}

output "frontend_url" {
  value = module.frontend.url
}

output "backend_url" {
  value = module.backend_proxy.url
}
EOF

cd ~/terraform-labs/modules-demo
terraform init
terraform apply

terraform output

# Clean up everything
terraform destroy
```

---

## Assignment

In `my-progress/day-20.md`:

1. What is the difference between `terraform.tfvars` and environment variables for providing variable values?
2. What happens if two team members run `terraform apply` at the same time against the same state file? How does remote state with locking solve this?
3. Extend your module to accept a `healthcheck_path` variable and add a label to the container with its value.
4. What is the `count` meta-argument? What is `for_each` and when would you use it instead of `count`?

```bash
cp -r ~/terraform-labs/modules-demo my-progress/terraform-modules
git add my-progress/
git commit -m "day-20: terraform state modules variables"
git push origin main
```

---

## Further Reading

- [Terraform state documentation](https://developer.hashicorp.com/terraform/language/state)
- [Terraform modules best practices](https://developer.hashicorp.com/terraform/language/modules/develop)
- [Terraform registry — public modules](https://registry.terraform.io/browse/modules)
