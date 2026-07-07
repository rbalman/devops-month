# Day 30 · Job Preparation & What Comes Next

## Learning Objectives

- Know how to position yourself for entry-level DevOps roles
- Understand what to build and how to talk about it in interviews
- Have a clear roadmap for what to learn after this course

---

## Theory · ~20 min

### What You Now Know

After 30 days you can:

| Skill | What you can do |
|---|---|
| **Linux** | Navigate the filesystem, manage users/permissions/processes, write bash scripts |
| **Git** | Version control workflows, branches, pull requests |
| **Networking** | Understand IP, DNS, SSH, TLS, ports |
| **Web Servers** | Configure Nginx, Apache, SSL |
| **Containers** | Build and run Docker containers, write Compose stacks |
| **Ansible** | Write playbooks and roles to configure servers |
| **Terraform** | Provision cloud infrastructure as code |
| **CI/CD** | Build automated pipelines with GitHub Actions |
| **AWS** | Use IAM, EC2, VPC, S3 via console and CLI |
| **Monitoring** | Set up Prometheus, Loki, Grafana, and Discord alerts |

This is the honest entry-level DevOps stack. You won't be an expert at any of it, but you know enough to be useful, grow quickly, and contribute from Day 1.

### What to Put on Your Resume

Only add things you can actually talk about. For each skill:
- What problem does it solve?
- How did you use it?
- What would you do differently?

**Resume template for this course:**

```
Projects
────────
DevOps Month Final Project (github.com/<you>/final-project)
• Provisioned AWS EC2 with Terraform and configured with Ansible
• Deployed containerized Flask app via GitHub Actions CI/CD pipeline
• Set up Prometheus + Loki + Grafana monitoring with Discord alerting
• Used Docker Compose for local development stack
Technologies: Docker, Nginx, Terraform, Ansible, GitHub Actions, AWS EC2/IAM/VPC/S3, Prometheus, Loki, Grafana
```

### How to Talk About This in Interviews

You'll get asked:
- *"Tell me about a deployment you've done."*
- *"How do you monitor an application?"*
- *"Walk me through a CI/CD pipeline."*
- *"What happens when a deploy fails?"*

Answer using the **STAR format**: Situation → Task → Action → Result.

Example: *"On the final project, the deploy was failing because Promtail couldn't access the Docker socket. I checked the container logs, saw a permission denied error, added the correct volume mount, and the logs started flowing within a minute."*

That's more impressive than knowing every feature of every tool.

---

## Lab · ~50 min (career work)

### Step 1 — Polish your GitHub profile

Your GitHub is your portfolio. Ensure:

```
✓ Profile photo
✓ Bio mentioning DevOps, Linux, Docker, etc.
✓ Pinned repositories: final-project, devops-month fork
✓ README.md in your final project repo
✓ Commit history showing daily work throughout the month
✓ Public repos are clean: no .env files, no credentials
```

Write a good README for your final project:

```bash
cat > ~/final-project/README.md << 'EOF'
# DevOps Month Final Project

A production-style DevOps setup built as part of the DevOps Month course.

## Architecture

- **App**: Flask API containerized with Docker
- **Web Server**: Nginx reverse proxy
- **CI/CD**: GitHub Actions (test → build → push → deploy)
- **Infrastructure**: AWS EC2 provisioned with Terraform, configured with Ansible
- **Monitoring**: Prometheus metrics + Loki logs → Grafana dashboards + Discord alerts

## Running locally

```bash
docker compose up -d
# App: http://localhost
# Grafana: http://localhost:3000 (admin/devops123)
# Prometheus: http://localhost:9090
```

## Deployment

Push to `main` branch → GitHub Actions runs automatically:
1. Tests and linting
2. Docker image build and push to Docker Hub
3. SSH deploy to EC2

## Technologies Used

Docker · Nginx · Terraform · Ansible · GitHub Actions · AWS (EC2, IAM, VPC, S3) · Prometheus · Loki · Grafana
EOF
```

### Step 2 — Entry-level job checklist

Before applying, make sure you can demonstrate:

```
Linux
  ☐ Navigate filesystem without looking anything up
  ☐ Write a bash script with functions, loops, and error handling
  ☐ Manage systemd services
  ☐ Read and follow logs

Containers
  ☐ Write a Dockerfile from scratch
  ☐ Build, tag, push an image
  ☐ Write a docker-compose.yml with 3+ services

Infrastructure
  ☐ Write Terraform to create a server and security group
  ☐ Write an Ansible playbook/role to configure it
  ☐ Deploy an app end-to-end

Cloud
  ☐ Navigate the AWS console confidently
  ☐ Create EC2, security groups, S3 from the CLI
  ☐ Explain IAM roles vs users

CI/CD
  ☐ Write a GitHub Actions workflow
  ☐ Add automated tests to a pipeline
  ☐ Trigger a deployment on push to main

Monitoring
  ☐ Explain what Prometheus scrapes and how
  ☐ Write a basic PromQL query
  ☐ Read a Grafana dashboard and identify a problem
```

### Step 3 — What to practice before interviews

**Whiteboard/verbal questions you'll face:**

1. *What is Docker and why would you use it instead of a VM?*
2. *Explain how DNS works, step by step.*
3. *What does a CI/CD pipeline look like?*
4. *How do you debug a service that's not responding?*
5. *What is Infrastructure as Code? Why does it matter?*
6. *What is the difference between vertical and horizontal scaling?*

Practice answering these out loud. Record yourself. The ability to explain things clearly is as important as technical skill at the entry level.

### Step 4 — What to learn next

After this course, here is a prioritized learning path:

**Immediate (next 1-2 months)**
- [ ] Kubernetes basics — `kubectl`, pods, deployments, services
- [ ] AWS deeper: RDS, ECS/EKS, ALB, CloudWatch
- [ ] Python scripting for DevOps (boto3, automation)

**Short term (3-6 months)**
- [ ] Kubernetes in production (Helm, ingress, HPA)
- [ ] Terraform AWS modules
- [ ] Linux performance troubleshooting (`perf`, `strace`, `tcpdump`)
- [ ] Secrets management (HashiCorp Vault or AWS Secrets Manager)

**Certifications to consider**
- AWS Cloud Practitioner (foundation, ~1 month prep)
- AWS Solutions Architect Associate (3-6 months)
- Certified Kubernetes Administrator (CKA) — after real Kubernetes experience

### Step 5 — The most important thing

**Go build something.**

Job seekers who can point to a real working system — something deployed, monitored, and documented — get interviews. People who only have certifications and no hands-on projects do not.

Take everything from this course and build something personal:
- Deploy your own blog or portfolio site with this pipeline
- Automate something you do manually
- Contribute to an open source project's CI/CD or infra

That becomes your strongest interview talking point.

---

## Final Assignment

The course is complete. For your final submission to `my-progress/day-30.md`:

1. What was the most valuable thing you learned in this course?
2. What was the most confusing — and do you understand it now?
3. What is your plan for the next 30 days after this course?
4. Post your final project's GitHub link in the Discord channel.

---

**Congratulations.** You went from setup to a deployed, monitored, CI/CD-backed application in 30 days. That is the real DevOps workflow. Everything from here is deepening what you've already started.

---

## Resources for the Road Ahead

- [roadmap.sh/devops](https://roadmap.sh/devops) — full skill tree with resources
- [KodeKloud](https://kodekloud.com) — hands-on Kubernetes and DevOps labs
- [AWS Skill Builder](https://skillbuilder.aws) — free AWS training
- [Kubernetes the Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way) — build k8s from scratch
- [DevOps subreddit](https://reddit.com/r/devops) — community, job postings, advice
