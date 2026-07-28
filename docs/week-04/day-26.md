# Day 5 · GitOps & the End-to-End Project

> The individual CI/CD pieces — tests, images, Terraform, Ansible — converge here into **the project** you'll put on your résumé. A single git repo holds a **frontend**, a **backend**, a **Postgres database**, the **Terraform** that creates the server, and the **Ansible** that deploys all three as containers on it. And it's all driven by **GitOps**: git is the source of truth, a merge provisions and deploys, and nobody touches a server by hand. This is the **capstone** — monitoring and security are layered on top of it.

!!! info "One repo, the whole system"
    App code + infrastructure code + configuration code, together in git. Push a change and the pipeline provisions the infra (Terraform) and deploys the containers (Ansible). That's the end-to-end project.

!!! danger "This builds a billable EC2 instance"
    This lab provisions a real EC2 (may be free-tier eligible). There's a **teardown** at the end — run it when you're done.

## Learning Objectives

- State the four **GitOps principles** and why "git as source of truth" matters
- Distinguish **push-based** GitOps (what we build) from **pull-based** (Argo CD / Flux)
- Lay out an **end-to-end repo**: frontend, backend, database, Terraform, Ansible
- Provision an EC2 with **Terraform** and deploy **frontend + backend + Postgres** as containers with **Ansible**
- **Lab:** a git-driven pipeline — **plan on PR, apply + deploy on merge** — for the whole project

---

## Prerequisites

- **Days 1–4 complete** — CI, image publish (your backend is on GHCR), Terraform-in-CI (incl. the OIDC role), Ansible-in-CI
- The S3 backend from Week 3
- A key pair in your AWS region

---

## Theory · ~30 min

### 1. What GitOps is

**GitOps** is operating your systems by making **git the source of truth** and letting automation keep reality in sync with it. Four principles:

| # | Principle | Meaning |
|---|---|---|
| 1 | **Declarative** | The system is described as *desired state* (Terraform HCL, Ansible YAML) — not scripts of steps |
| 2 | **Versioned & immutable** | That state lives in git — auditable, revertible. `git revert` is your rollback |
| 3 | **Applied automatically** | Changes are applied by automation, not humans running commands |
| 4 | **Continuously reconciled** | Software compares desired (git) vs actual (reality) and corrects drift |

The payoff: **git is your audit log, your review gate, and your rollback button.** Who changed the server? `git log`. Roll it back? `git revert`. Approve it first? A pull request. Operations becomes *just software development*.

### 2. Push vs pull — an honest distinction

| | **Push-based (CIOps)** | **Pull-based (true GitOps)** |
|---|---|---|
| Who applies? | A **CI pipeline** pushes changes *out* | An **agent inside the target** pulls them *in* |
| Trigger | Merge to `main` runs `apply` | Agent notices git ≠ reality and reconciles |
| Tools | GitHub Actions + Terraform/Ansible | **Argo CD**, **Flux** (Kubernetes) |

The pipeline here is **push-based** — assembled from the [Terraform](day-24.md) and [Ansible](day-25.md) CI halves. **Pull-based GitOps** (Argo CD / Flux) is Kubernetes-native and adds *continuous* reconciliation; it's the natural next step once you learn Kubernetes.

### 3. The end-to-end project

Meet the app. Three containers running side by side on one EC2, plus the code that builds and delivers them:

```text
                       Internet
                          │  http://<ec2-ip>
                          ▼
        ┌───────────────────────────────────────┐
        │  EC2  (Terraform-provisioned)          │
        │                                        │
        │   ┌──────────┐  /api   ┌────────────┐  │
        │   │ frontend │────────▶│  backend   │  │
        │   │  nginx   │         │  Node API  │  │
        │   └──────────┘         └─────┬──────┘  │
        │                              │ :5432   │
        │                        ┌─────▼──────┐  │
        │                        │  postgres  │  │  (named volume)
        │                        └────────────┘  │
        │        docker compose, one network     │
        └───────────────────────────────────────┘
```

- **frontend** — nginx serving the static UI and proxying `/api` to the backend.
- **backend** — the Node/Express API from Day 1 (its image is on GHCR from Day 2), reading `DATABASE_URL`.
- **postgres** — the official Postgres image with a **named volume** so data survives restarts.

They talk over a private **compose network** by service name (`backend` → `db:5432`), so there's no cross-host networking to manage — the simplest thing that's still a real three-tier app.

### 4. One repo, three kinds of code

```text
sample-app/
├── frontend/         # static UI (html/css/js) + nginx.conf
├── backend/          # the Node/Express API (Dockerfile from Day 2)
├── db/               # init.sql (schema/seed)
├── terraform/        # the EC2, security group, outputs
├── ansible/          # role that deploys the compose stack
└── .github/workflows/  # ci.yml, deploy.yml, gitops.yml
```

App code, infrastructure code, and configuration code **in one place, versioned together** — the essence of GitOps. A single PR can change the UI *and* the server size *and* the deploy config, reviewed as one unit.

---

## Lab · ~50 min

Provision the EC2 with Terraform, deploy the three containers with Ansible, and wire the git-driven pipeline that runs it all.

!!! important "Reuse your backend + OIDC role"
    State goes in the S3 backend (key `end-to-end/terraform.tfstate`); AWS auth uses an **OIDC role for this repo**, set up the same way as in [Terraform in CI/CD](day-24.md).

### 1. The infrastructure — Terraform

Keep it minimal: a security group and one EC2 in your default VPC. **`terraform/main.tf`**:

```hcl
terraform {
  required_version = ">= 1.10"
  required_providers { aws = { source = "hashicorp/aws", version = "~> 6.0" } }
  backend "s3" {
    bucket       = "golive-tf-state-<you>"
    key          = "end-to-end/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" { region = "us-east-1" }

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter { name = "name", values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"] }
}

resource "aws_security_group" "app" {
  name        = "end-to-end-app"
  description = "web + ssh"
  ingress { description = "HTTP",  from_port = 80, to_port = 80, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"] }
  ingress { description = "SSH",   from_port = 22, to_port = 22, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"] }
  egress  { from_port = 0, to_port = 0, protocol = "-1", cidr_blocks = ["0.0.0.0/0"] }
}

resource "aws_instance" "app" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.small"          # room for 3 containers
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.app.id]
  tags                   = { Name = "end-to-end-app" }
}

output "public_ip" { value = aws_instance.app.public_ip }
```

!!! note "We start simple on purpose"
    SSH open to the world and no HTTPS is fine to *learn* on — but it's exactly what the [Security Best Practices](day-28.md) day hardens: locking down the security group, adding TLS, scanning the images, and more. Get it working first; make it safe as a follow-up.

### 2. The deployment — Ansible, three containers

**`ansible/roles/app/templates/docker-compose.yml.j2`** — the whole app on one network:

```yaml
services:
  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: appuser
      POSTGRES_PASSWORD: "{{ db_password }}"
      POSTGRES_DB: appdb
    volumes:
      - dbdata:/var/lib/postgresql/data
      - /opt/app/init.sql:/docker-entrypoint-initdb.d/init.sql:ro

  backend:
    image: {{ backend_image }}          # ghcr.io/<you>/sample-app/api:latest
    environment:
      DATABASE_URL: "postgres://appuser:{{ db_password }}@db:5432/appdb"
      PORT: "3000"
    depends_on: [db]

  frontend:
    image: nginx:1.27-alpine
    ports: ["80:80"]
    volumes:
      - /opt/app/frontend:/usr/share/nginx/html:ro
      - /opt/app/nginx.conf:/etc/nginx/conf.d/default.conf:ro
    depends_on: [backend]

volumes:
  dbdata:
```

**`ansible/roles/app/tasks/main.yml`** — install Docker, copy the app files, launch:

```yaml
- name: Install Docker + Compose plugin
  ansible.builtin.apt: { name: [docker.io, docker-compose-v2], update_cache: true }
  become: true

- name: Log in to GHCR
  community.docker.docker_login:
    registry: ghcr.io
    username: "{{ ghcr_user }}"
    password: "{{ ghcr_token }}"
  become: true

- name: Copy frontend, nginx config, and db init
  ansible.builtin.copy: { src: "{{ item.src }}", dest: "{{ item.dest }}" }
  loop:
    - { src: "../frontend/",   dest: "/opt/app/frontend/" }
    - { src: "../frontend/nginx.conf", dest: "/opt/app/nginx.conf" }
    - { src: "../db/init.sql", dest: "/opt/app/init.sql" }
  become: true

- name: Template the compose file
  ansible.builtin.template: { src: docker-compose.yml.j2, dest: /opt/app/docker-compose.yml }
  become: true

- name: Start the stack
  community.docker.docker_compose_v2: { project_src: /opt/app, pull: always }
  become: true
```

Secrets (`db_password`, `ghcr_token`) live in an **Ansible Vault** file, never plain YAML (Day 4's pattern). The `nginx.conf` in `frontend/` serves the static files and proxies `/api/` to `http://backend:3000`.

### 3. The GitOps pipeline

**`.github/workflows/gitops.yml`** — combine the Terraform (Day 3) and Ansible (Day 4) mechanics into one git-driven flow:

```yaml
name: GitOps

on:
  pull_request:
    paths: ["terraform/**", "ansible/**"]
  push:
    branches: [main]
    paths: ["terraform/**", "ansible/**"]

permissions:
  id-token: write
  contents: read

jobs:
  plan:
    if: github.event_name == 'pull_request'
    runs-on: ubuntu-latest
    defaults: { run: { working-directory: terraform } }
    steps:
      - uses: actions/checkout@v7
      - uses: aws-actions/configure-aws-credentials@v6
        with: { role-to-assume: arn:aws:iam::<acct>:role/github-actions, aws-region: us-east-1 }
      - uses: hashicorp/setup-terraform@v3
      - run: terraform init -input=false
      - run: terraform plan -no-color -input=false
        env: { TF_VAR_key_name: "${{ vars.KEY_NAME }}" }

  apply-and-deploy:
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    runs-on: ubuntu-latest
    environment: production          # add a required reviewer for a real gate
    steps:
      - uses: actions/checkout@v7
      - uses: aws-actions/configure-aws-credentials@v6
        with: { role-to-assume: arn:aws:iam::<acct>:role/github-actions, aws-region: us-east-1 }
      - uses: hashicorp/setup-terraform@v3

      - name: Provision infra
        working-directory: terraform
        run: terraform init -input=false && terraform apply -auto-approve -input=false
        env: { TF_VAR_key_name: "${{ vars.KEY_NAME }}" }

      - name: Deploy the app
        run: |
          pip install ansible
          echo "${{ secrets.SSH_PRIVATE_KEY }}" > key && chmod 600 key
          echo "${{ secrets.VAULT_PASSWORD }}" > .vault
          IP=$(terraform -chdir=terraform output -raw public_ip)
          echo -e "[app]\n$IP ansible_user=ubuntu" > ansible/inventory.ini
          ansible-playbook -i ansible/inventory.ini ansible/site.yml \
            --private-key key --vault-password-file .vault \
            -e "ANSIBLE_HOST_KEY_CHECKING=False"
```

Notice the deploy step builds the inventory **from the Terraform output** — the pipeline discovers the IP it just created.

### 4. A full GitOps cycle

1. Open a **PR** (e.g. change the instance type or a frontend file). Actions posts the **plan**.
2. **Merge.** `apply-and-deploy` provisions the EC2 and deploys the three containers.
3. Visit `http://<public_ip>` — the frontend loads; `http://<public_ip>/api/healthz` reaches the backend; the backend reads/writes Postgres. **You never opened a terminal.**

### 5. Reconciliation catches drift

**Manually stop the app** on the server (or delete the instance in the console). Re-run the pipeline (push an empty commit). Terraform recreates any missing infra and Ansible redeploys the stack — reality reconciled back to git.

!!! success "This is your capstone"
    A complete application — frontend, backend, database — provisioned by Terraform and deployed in containers by Ansible, **all driven by git**. Day 6 adds monitoring; Day 7 makes it secure. Keep this repo; it's your portfolio centerpiece.

!!! danger "Teardown"
    ```bash
    cd terraform && terraform destroy
    ```
    Keep it if you're going straight to Day 6; otherwise destroy so the EC2 stops billing.

---

## Advanced Topics

- **Argo CD & Flux** — pull-based, continuously-reconciling GitOps for Kubernetes → [Argo CD](https://argo-cd.readthedocs.io/) · [Flux](https://fluxcd.io/)
- **Managed database** — swap the Postgres container for **RDS** when you need backups/HA (Week 3 patterns) → [RDS module](https://registry.terraform.io/modules/terraform-aws-modules/rds/aws/latest)
- **Build a frontend image** — instead of Ansible-copying files, build+push a frontend image in CI (Day 2 pattern)
- **Atlantis** — PR-driven Terraform automation, purpose-built → [runatlantis.io](https://www.runatlantis.io/)
- **Scheduled drift detection** — a nightly `plan -detailed-exitcode` that alerts on drift

---

## Assignment — the capstone deliverable

Ship the end-to-end project and document it as a portfolio piece.

**What must work:**

1. **One repo** with `frontend/`, `backend/`, `db/`, `terraform/`, `ansible/`, and workflows — no secrets committed.
2. **A PR** shows the Terraform **plan**; **merge to `main`** provisions the EC2 (OIDC, no stored keys) and deploys all three containers with Ansible — no local commands.
3. `http://<public_ip>` serves the **frontend**; `/api/healthz` reaches the **backend**; the backend **reads/writes Postgres** (add one DB-backed endpoint, e.g. `GET /api/items`).
4. **Destroy + rebuild** reproduces the whole app from git.

**Document** in the repo `README.md`: an architecture diagram (redraw the one above), a "how it works" trace from `git push` to live, and a runbook (deploy / roll back / tear down).

**Submit:** repo link, a green pipeline run (all jobs), screenshots of the app in a browser and a successful destroy→rebuild, and a ½-page write-up of **what broke and how you debugged it**.

---

## Further Reading

**Watch**

- 📺 [What is GitOps, How GitOps works](https://youtu.be/f5EpcWp0THw) — TechWorld with Nana; principles and push vs pull

**Reference**

- [OpenGitOps — Principles](https://opengitops.dev/) · [Automate Terraform with GitHub Actions](https://developer.hashicorp.com/terraform/tutorials/automation/github-actions)
- [`community.docker.docker_compose_v2`](https://docs.ansible.com/ansible/latest/collections/community/docker/docker_compose_v2_module.html) · [Postgres Docker image](https://hub.docker.com/_/postgres)
- [The Twelve-Factor App](https://12factor.net/) — the config/deploy principles behind this design
