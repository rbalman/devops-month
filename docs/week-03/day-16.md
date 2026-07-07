# Day 16 · Ansible I — Inventory & Ad-hoc Commands

## Learning Objectives

- Understand what Ansible is and why it's used
- Write an inventory file to define target hosts
- Run ad-hoc commands to manage multiple servers at once

---

## Theory · ~20 min

### What is Ansible?

Ansible is a **configuration management and automation tool**. It lets you define the desired state of your servers and apply it consistently — across one server or a thousand.

Key characteristics:
- **Agentless** — no software needs to be installed on managed nodes; Ansible connects via SSH
- **Idempotent** — running the same playbook twice produces the same result (no duplicate changes)
- **Declarative** — you describe *what* you want, Ansible figures out *how*
- **YAML-based** — human-readable configuration

### Where Ansible fits in DevOps

```
Terraform   → Provision the infrastructure (create servers)
Ansible     → Configure the servers (install packages, deploy apps, manage users)
```

Ansible answers: "Given a fresh server, how do I get it to the correct state?"

### How Ansible Connects

```
Control Node (your machine)
    │
    └── SSH → Managed Node 1 (server-1)
    └── SSH → Managed Node 2 (server-2)
    └── SSH → Managed Node 3 (server-3)
```

Ansible runs commands remotely via SSH. No agent. No daemon. Your machine needs Python + Ansible; the target needs SSH + Python.

### Inventory

An inventory defines your hosts. Simplest form (INI):

```ini
[webservers]
web-01 ansible_host=192.168.56.11
web-02 ansible_host=192.168.56.12

[databases]
db-01 ansible_host=192.168.56.20

[all:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=~/.ssh/devops_month
```

---

## Lab · ~50 min

### Step 1 — Install Ansible

```bash
sudo apt update
sudo apt install -y ansible

ansible --version
```

### Step 2 — Set up Vagrant machines as targets

```bash
mkdir -p ~/ansible-labs
cd ~/ansible-labs

cat > Vagrantfile << 'EOF'
Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"

  (1..2).each do |i|
    config.vm.define "node#{i}" do |node|
      node.vm.hostname = "node#{i}"
      node.vm.network "private_network", ip: "192.168.56.#{10 + i}"
      node.vm.provider "virtualbox" do |vb|
        vb.memory = "512"
      end
    end
  end
end
EOF

vagrant up

# Get the SSH config for both nodes
vagrant ssh-config node1 >> ~/.ssh/config
vagrant ssh-config node2 >> ~/.ssh/config

# Test connectivity
ssh node1 "hostname && uname -a"
ssh node2 "hostname && uname -a"
```

### Step 3 — Write the inventory file

```bash
cat > inventory.ini << 'EOF'
[webservers]
node1 ansible_host=192.168.56.11

[databases]
node2 ansible_host=192.168.56.12

[all:vars]
ansible_user=vagrant
ansible_ssh_private_key_file=~/.vagrant.d/insecure_private_key
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
EOF

# Test connectivity with Ansible's ping module
ansible all -i inventory.ini -m ping

# Ping only webservers
ansible webservers -i inventory.ini -m ping
```

### Step 4 — Run ad-hoc commands

Ad-hoc commands are one-off commands — no playbook needed:

```bash
# Run a shell command on all hosts
ansible all -i inventory.ini -m shell -a "hostname && uptime"

# Get facts about hosts
ansible all -i inventory.ini -m setup | head -50

# Get a specific fact
ansible all -i inventory.ini -m setup -a "filter=ansible_distribution"

# Copy a file to all hosts
echo "Hello from Ansible" > /tmp/test.txt
ansible all -i inventory.ini -m copy -a "src=/tmp/test.txt dest=/tmp/test.txt"

# Verify it landed
ansible all -i inventory.ini -m shell -a "cat /tmp/test.txt"

# Install a package (requires sudo)
ansible all -i inventory.ini -m apt -a "name=nginx state=present" -b
# -b = become (sudo)

# Start a service
ansible webservers -i inventory.ini -m service -a "name=nginx state=started" -b

# Verify nginx is running
ansible webservers -i inventory.ini -m shell -a "systemctl status nginx"
```

### Step 5 — Explore useful modules

```bash
# File module — manage files and permissions
ansible all -i inventory.ini -m file -a "path=/tmp/ansible-dir state=directory mode=0755" -b

# User module — manage system users
ansible all -i inventory.ini -m user -a "name=deploy shell=/bin/bash" -b

# Package info
ansible all -i inventory.ini -m shell -a "dpkg -l nginx" -b

# Gather and display free disk space
ansible all -i inventory.ini -m shell -a "df -h /"

# Remove a package
ansible all -i inventory.ini -m apt -a "name=nginx state=absent" -b
```

---

## Assignment

In `my-progress/day-16.md`:

1. What does "agentless" mean for Ansible? What does it require on the target machines instead?
2. What is idempotency? Run `ansible all -m apt -a "name=nginx state=present" -b` twice. What changes in the second run? Why?
3. Using only ad-hoc commands, perform these tasks on both nodes:
   - Create a directory `/opt/myapp`
   - Create a file `/opt/myapp/version.txt` with content `v1.0`
   - Set ownership to `root:root` with permissions `644`
   - Verify by listing the file
4. What is the difference between the `shell` module and the `command` module in Ansible?

---

## Further Reading

- [Ansible module index](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/index.html)
- [Ansible ad-hoc commands guide](https://docs.ansible.com/ansible/latest/command_guide/intro_adhoc.html)
- [Ansible inventory guide](https://docs.ansible.com/ansible/latest/inventory_guide/intro_inventory.html)
