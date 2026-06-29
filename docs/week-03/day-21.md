# Day 21 · Review & Mini Project — Infrastructure as Code End-to-End

## Learning Objectives

- Consolidate Week 3 knowledge (Vagrant, Ansible, Terraform)
- Build a complete IaC workflow: provision VM with Terraform, configure it with Ansible
- Practice debugging and troubleshooting

---

## Theory · ~10 min

### Week 3 Recap

This week covered the three pillars of infrastructure management:

| Tool | What it does | When to use |
|---|---|---|
| **Vagrant** | Manages local VMs for dev/test | Local environment simulation |
| **Ansible** | Configures servers (install, deploy, manage) | Day-2 operations on any server |
| **Terraform** | Provisions infrastructure (creates resources) | Creating servers, networks, buckets |

The workflow in a real project:

```
Terraform creates EC2 instances
    ↓
Ansible configures them (nginx, app, users, etc.)
    ↓
Your application runs on fully-automated infrastructure
```

### What to practice when stuck

- `ansible-playbook --check --diff` — see what would change without applying
- `terraform plan` — always check before applying
- Read the error message top to bottom — the important line is rarely the last one
- `ansible -m setup hostname` — dump all facts about a host to understand its state

---

## Mini Project · ~80 min

Build a complete local environment using all three tools.

### Goal

Provision a local VM, configure it with Ansible, and verify the setup — all automated, reproducible by running three commands.

### Step 1 — Project structure

```bash
mkdir -p ~/mini-project/{terraform,ansible/{roles/webserver/{tasks,templates,handlers,defaults},inventory}}
cd ~/mini-project
```

### Step 2 — Provision the VM with Terraform (Docker provider)

```bash
cat > terraform/main.tf << 'EOF'
terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}

resource "docker_image" "ubuntu" {
  name         = "rastasheep/ubuntu-sshd:22.04"
  keep_locally = true
}

resource "docker_container" "server" {
  image    = docker_image.ubuntu.image_id
  name     = "mini-project-server"
  hostname = "mini-project"

  ports {
    internal = 22
    external = 2222
  }

  ports {
    internal = 80
    external = 8080
  }
}

output "ssh_command" {
  value = "ssh root@localhost -p 2222 -o StrictHostKeyChecking=no"
}

output "web_url" {
  value = "http://localhost:8080"
}
EOF

cd ~/mini-project/terraform
terraform init
terraform apply
```

### Step 3 — Ansible inventory and role

```bash
cd ~/mini-project

cat > ansible/inventory/hosts.ini << 'EOF'
[webservers]
mini-project ansible_host=127.0.0.1 ansible_port=2222 ansible_user=root ansible_password=root ansible_ssh_common_args='-o StrictHostKeyChecking=no'
EOF

# Webserver role tasks
cat > ansible/roles/webserver/defaults/main.yml << 'EOF'
---
app_name: "Mini Project"
app_port: 80
web_root: /var/www/html
EOF

cat > ansible/roles/webserver/tasks/main.yml << 'EOF'
---
- name: Update apt cache
  apt:
    update_cache: true

- name: Install packages
  apt:
    name:
      - nginx
      - curl
      - git
    state: present

- name: Deploy site config
  template:
    src: site.conf.j2
    dest: /etc/nginx/sites-available/default
  notify: Reload nginx

- name: Deploy index page
  template:
    src: index.html.j2
    dest: "{{ web_root }}/index.html"

- name: Ensure nginx is running
  service:
    name: nginx
    state: started
    enabled: true

- name: Create app info file
  copy:
    content: |
      app={{ app_name }}
      port={{ app_port }}
      deployed={{ ansible_date_time.iso8601 }}
    dest: /etc/app-info
EOF

cat > ansible/roles/webserver/handlers/main.yml << 'EOF'
---
- name: Reload nginx
  service:
    name: nginx
    state: reloaded
EOF

cat > ansible/roles/webserver/templates/site.conf.j2 << 'EOF'
server {
    listen {{ app_port }};
    root {{ web_root }};
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }

    location /health {
        return 200 '{"status":"ok","app":"{{ app_name }}"}';
        add_header Content-Type application/json;
    }
}
EOF

cat > ansible/roles/webserver/templates/index.html.j2 << 'EOF'
<!DOCTYPE html>
<html>
<head><title>{{ app_name }}</title></head>
<body>
  <h1>{{ app_name }}</h1>
  <ul>
    <li>Host: {{ ansible_hostname }}</li>
    <li>OS: {{ ansible_distribution }} {{ ansible_distribution_version }}</li>
    <li>IP: {{ ansible_default_ipv4.address }}</li>
    <li>Deployed: {{ ansible_date_time.date }}</li>
  </ul>
</body>
</html>
EOF

cat > ansible/site.yml << 'EOF'
---
- name: Configure web servers
  hosts: webservers
  become: true
  roles:
    - webserver
EOF

# Install sshpass for password-based SSH (development only)
sudo apt install -y sshpass

# Run the playbook
ansible-playbook -i ansible/inventory/hosts.ini ansible/site.yml
```

### Step 4 — Verify everything works

```bash
# Check the web server
curl http://localhost:8080
curl http://localhost:8080/health

# SSH in and verify
ssh root@localhost -p 2222 -o StrictHostKeyChecking=no "cat /etc/app-info"
ssh root@localhost -p 2222 -o StrictHostKeyChecking=no "systemctl status nginx"
ssh root@localhost -p 2222 -o StrictHostKeyChecking=no "cat /var/log/nginx/access.log"
```

### Step 5 — Automate with a Makefile

```bash
cat > ~/mini-project/Makefile << 'EOF'
.PHONY: up configure verify down

up:
	cd terraform && terraform init && terraform apply -auto-approve

configure:
	ansible-playbook -i ansible/inventory/hosts.ini ansible/site.yml

verify:
	@echo "=== Testing web server ==="
	curl -s http://localhost:8080/health | python3 -m json.tool
	@echo "\n=== Checking nginx status ==="
	ssh root@localhost -p 2222 -o StrictHostKeyChecking=no "systemctl status nginx --no-pager"

down:
	cd terraform && terraform destroy -auto-approve

all: up configure verify
EOF

# Full teardown and rebuild
make down
make all
```

---

## Assignment

This week's assignment is the mini project itself. Push everything to your fork:

```bash
cp -r ~/mini-project my-progress/mini-project
git add my-progress/
git commit -m "day-21: week 3 mini project complete"
git push origin main
```

Then answer in `my-progress/day-21.md`:

1. What was the hardest part of this mini project? What did you debug?
2. How would this project change if you used AWS EC2 instead of a local Docker container?
3. What would you add to the Ansible role to make it production-ready?
4. If a teammate clones your repo and runs `make all`, will it work? What assumptions does it make?

---

## Further Reading

- [Terraform + Ansible together — HashiCorp blog](https://developer.hashicorp.com/terraform/tutorials/provision/ansible)
- Review Days 15–20 notes for anything that felt unclear
- [IaC best practices](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/infrastructure-as-code)
