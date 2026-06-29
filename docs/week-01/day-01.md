# Day 01 · DevOps Introduction & Machine Setup

## Learning Objectives

- Understand what DevOps is and why it exists
- Know the core pillars: infrastructure, automation, observability, security
- Have a working local environment ready for the rest of the course

---

## Theory · ~20 min

### What is DevOps?

DevOps is not a tool or a job title — it is a culture and a set of practices that bridges software **development** (writing code) and **operations** (running that code in production).

Before DevOps, these two teams worked in silos:

- Developers wrote code and threw it "over the wall" to operations.
- Operations ran the servers and were blamed when things broke.
- Releases were infrequent, risky, and painful.

DevOps changes this by emphasizing:

| Principle | Meaning |
|---|---|
| **Collaboration** | Dev and Ops work together throughout the lifecycle |
| **Automation** | Anything done manually more than twice should be scripted |
| **Continuous delivery** | Small, frequent releases instead of big risky ones |
| **Observability** | You can't fix what you can't see — monitor everything |
| **Feedback loops** | Fast feedback from tests, monitoring, and users |

### The DevOps Lifecycle

```
Plan → Code → Build → Test → Release → Deploy → Operate → Monitor
  ↑___________________________________________________|
```

This course covers the **right half** of this loop — the infrastructure, deployment, and monitoring side. Understanding the full picture matters for the job.

### What Does a DevOps Engineer Actually Do?

Day-to-day tasks typically include:

- Writing automation scripts (Bash, Python)
- Managing infrastructure (Terraform, Ansible)
- Maintaining CI/CD pipelines (GitHub Actions, Jenkins)
- Running containers and orchestration (Docker, Kubernetes)
- Monitoring systems and responding to alerts
- Managing cloud resources (AWS, GCP, Azure)

You won't master all of these in 30 days. But you will understand each one well enough to get started and grow on the job.

---

## Lab · ~50 min

### Step 1 — Install required tools

Open your terminal and install the following. Commands are for Ubuntu/Debian. Adapt for macOS (use `brew`) or your distro.

**Git**
```bash
sudo apt update && sudo apt install -y git
git --version
```

**curl and wget**
```bash
sudo apt install -y curl wget
```

**VS Code** — download from [code.visualstudio.com](https://code.visualstudio.com) and install.

Useful VS Code extensions to install now:
- `ms-vscode-remote.remote-ssh`
- `hashicorp.terraform`
- `redhat.ansible`
- `ms-azuretools.vscode-docker`

**VirtualBox** (for Vagrant labs next week)
```bash
sudo apt install -y virtualbox
```

Or download from [virtualbox.org](https://www.virtualbox.org/wiki/Downloads) for macOS/Windows.

### Step 2 — Configure Git

```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
git config --global init.defaultBranch main
git config --list
```

### Step 3 — Fork and clone this course repo

1. Go to `https://github.com/rbalman/devops-month`
2. Click **Fork** → Fork to your account
3. Clone your fork:

```bash
git clone https://github.com/<your-username>/devops-month.git
cd devops-month
```

### Step 4 — Create your personal progress file

Inside the cloned repo:

```bash
mkdir -p my-progress
echo "# My DevOps Month Progress" > my-progress/README.md
echo "Started: $(date)" >> my-progress/README.md
git add my-progress/
git commit -m "day-01: start progress tracking"
git push origin main
```

Verify it appears on GitHub at `https://github.com/<your-username>/devops-month`.

### Step 5 — Explore your system

Run these commands and read the output:

```bash
uname -a          # kernel and OS info
whoami            # current user
hostname          # machine name
df -h             # disk usage
free -h           # RAM usage
lscpu             # CPU info
```

Write down what each line tells you about your machine. You will refer to this later.

---

## Assignment

Answer these questions in `my-progress/day-01.md` and push to your fork:

1. In your own words (2–3 sentences), what problem does DevOps solve?
2. List 3 tasks a DevOps engineer does that a developer typically does not.
3. What OS, RAM, and CPU does your machine have? (use the commands above)
4. What went wrong during setup (if anything) and how did you fix it?

```bash
# Template
cat > my-progress/day-01.md << 'EOF'
# Day 01 Notes

## What DevOps solves


## 3 DevOps tasks


## My machine specs


## Setup issues & fixes

EOF
git add my-progress/day-01.md
git commit -m "day-01: assignment complete"
git push origin main
```

---

## Further Reading

- [The Phoenix Project](https://itrevolution.com/product/the-phoenix-project/) — fictional novel, best introduction to DevOps culture
- [roadmap.sh/devops](https://roadmap.sh/devops) — visual map of the full DevOps skill tree
- [What is DevOps? — AWS](https://aws.amazon.com/devops/what-is-devops/)
