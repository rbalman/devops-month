# Day 01 · DevOps Introduction & Environment Setup

## Learning Objectives

- Understand what DevOps is and why it exists
- Set up a consistent Linux environment using Vagrant
- Navigate the Linux filesystem with basic commands

---

## Theory · ~20 min

### What is DevOps?

DevOps is not a tool or a job title — it is a culture and a set of practices that bridges software **development** (writing code) and **operations** (running that code in production).

Before DevOps, these two teams worked in silos:

- Developers wrote code and threw it "over the wall" to operations
- Operations ran the servers and were blamed when things broke
- Releases were infrequent, risky, and painful

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

This course covers the **right half** — infrastructure, deployment, and monitoring. Understanding the full loop matters for the job.

### What Does a DevOps Engineer Actually Do?

Day-to-day tasks typically include:

- Writing automation scripts (Bash, Python)
- Managing infrastructure (Terraform, Ansible)
- Maintaining CI/CD pipelines (GitHub Actions, Jenkins)
- Running containers (Docker, Kubernetes)
- Monitoring systems and responding to alerts
- Managing cloud resources (AWS, GCP, Azure)

You won't master all of these in 30 days — but you will understand each one well enough to contribute from Day 1 on the job.

### Why Vagrant?

Throughout this course, you'll run labs inside a Linux VM managed by **Vagrant**. This gives everyone the same Ubuntu 24.04 environment regardless of whether you're on macOS, Windows, or Linux.

Vagrant manages VMs with a single config file (`Vagrantfile`) and a handful of commands. It sits on top of a **hypervisor** (VirtualBox or VMware Fusion) that actually runs the VM.

```
Your machine (any OS)
    └── Hypervisor (VirtualBox or VMware Fusion)
            └── Ubuntu 24.04 LTS VM  ← where all our labs run
                    └── managed by Vagrant
```

---

## Machine Setup

### Step 1 — Know your machine architecture

Before installing anything, check whether your machine is **amd64** (Intel/AMD) or **arm64** (Apple Silicon M1/M2/M3):

=== "macOS"
    ```bash
    uname -m
    # x86_64  → amd64 (Intel Mac)
    # arm64   → arm64 (Apple Silicon)
    ```

=== "Windows"
    ```
    Settings → System → About → System type
    ```

=== "Linux"
    ```bash
    uname -m
    # x86_64  → amd64
    # aarch64 → arm64
    ```

### Step 2 — Install VirtualBox

We use **VirtualBox** as the hypervisor for this course — it's free, works on all platforms, and has native Vagrant support.

Download and install from [virtualbox.org/wiki/Downloads](https://www.virtualbox.org/wiki/Downloads)

!!! warning "Apple Silicon users"
    ARM64 support requires **VirtualBox 7.1 or later**. Make sure you download the latest version.

### Step 3 — Install Vagrant

Download and install from [developer.hashicorp.com/vagrant/install](https://developer.hashicorp.com/vagrant/install)

```bash
vagrant --version    # should print 2.x.x
```

### Step 4 — Spin up your VM

**4.1 Create relevant directories**

```bash
mkdir -p ~/devops-month-labs/day-1
cd ~/devops-month-labs/day-1
```

**4.1 Create a Vagrantfile**

Create a file named `Vagrantfile` (no extension) and paste this content. It works on both amd64 and arm64 — `bento/ubuntu-24.04` supports both architectures automatically.

```ruby
Vagrant.configure("2") do |config|
  config.vm.box      = "bento/ubuntu-24.04"
  config.vm.hostname = "devops-lab"

  config.vm.network "private_network", ip: "192.168.56.10"

  config.vm.provider "virtualbox" do |vb|
    vb.name   = "devops-lab"
    vb.memory = 1024
    vb.cpus   = 1
  end
end
```

```bash
# Start the VM (first run downloads the box ~500MB)
vagrant up

# Check the status of vagrant box
vagrant status

# SSH into it
vagrant ssh
```

Your prompt changes to:

```
vagrant@devops-lab:~$
```

Everything from here runs **inside the VM**.

NOTE: For finding all the available vagrant boxes => https://portal.cloud.hashicorp.com/vagrant/discover


### Step 5 — Explore the OS

```bash
# What OS and version?
cat /etc/os-release

# Kernel version and architecture
uname -a
uname -m      # should print x86_64 or aarch64

# Who are you?
whoami
id

# Hostname
hostname

# Uptime and load
uptime
```

### Step 6 — Navigate the filesystem

The Linux filesystem starts at `/` — everything branches from there:

```
/
├── etc/    → configuration files (nginx.conf, sshd_config)
├── home/   → user home directories (/home/vagrant)
├── var/    → logs, databases, variable data (/var/log)
├── tmp/    → temporary files, cleared on reboot
├── usr/    → installed programs and libraries
└── proc/   → live kernel and process info (virtual, not real files)
```

```bash
pwd             # where am I right now?
ls              # list current directory
ls -la          # long format, include hidden files (dotfiles)

cd /            # go to root
ls              # see all top-level directories

cd /etc         # go into the config directory
ls | head -20   # first 20 entries

cd /var/log     # go to logs
ls -lh          # list with human-readable sizes

cd ~            # back to home (/home/vagrant)
pwd             # confirm
```

### Step 7 — Create and manage files

```bash
mkdir -p ~/practice/week-01
cd ~/practice/week-01

# Create a file
echo "Day 01 - DevOps Month" > notes.txt
cat notes.txt

# Copy and move
cp notes.txt notes-backup.txt
mv notes-backup.txt notes-v2.txt
ls -la

# Delete
rm notes-v2.txt
ls

# Create nested directories
mkdir -p projects/myapp/config
ls -R projects/
```

### Step 8 — Exit and manage the VM

```bash
exit    # back to your host machine
```

```bash
# From your host:
vagrant status    # VM state
vagrant halt      # shut down gracefully
vagrant up        # start again
vagrant ssh       # SSH back in
```

!!! warning
    `vagrant destroy` deletes the VM and all files inside it. `vagrant halt` just shuts it down — your files survive.

---

## Assignment

1. Practice **Basic Commands**, **System Information**, **File and Directory Management** section cheat sheets from this [repository](https://github.com/Nikoo-Asadnejad/Linux-Commands-Cheat-Sheet)

2. **Register your own `.com.np` domain.** You'll use it later in the course when we deploy and serve real applications. Registration is free — follow the official guide: [How to register a `.np` domain](https://register.com.np/how-to-register-np-domain).

3. **Set up an AWS account** so you're ready for the cloud sessions. Pick whichever applies to you:
    - **Student:** apply through [AWS Academy / AWS Educate](https://aws.amazon.com/education/aws-educate/) for free credits, or
    - **Everyone else:** create a new [AWS Free Tier](https://aws.amazon.com/free/) account and register it with your credit card.

    !!! warning "Guard your credit card and free-tier limits"
        A credit card is required even for the Free Tier. Stay within free-tier limits, and **stop or delete any resources** you're not using so you don't get charged. Never share your card details or AWS credentials with anyone.
