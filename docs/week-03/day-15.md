# Day 1 · Ansible I — Fundamentals & Your First Playbook

> Week 2 ended with you SSHing into servers and configuring them **by hand**. That doesn't scale: ten servers means ten sessions and ten chances to fumble a step. **Ansible** turns those manual steps into a file you can run against one server or a hundred — the same way, every time. Today you'll stand up a small fleet with Vagrant (one **control node** driving two **managed nodes** over a private network), and drive them entirely from code. This is the foundation the rest of Week 3 builds on — the exact same playbooks will later target a real AWS server.

## Learning Objectives

- Explain **why** configuration management exists and where Ansible fits
- Name Ansible's defining traits — **agentless, push-based, declarative, idempotent**
- Describe the **control/managed node** architecture and how a task actually runs
- Know where Ansible reads its **configuration** and how a project is laid out
- Build a static **inventory** with groups and run **ad-hoc commands**
- Write and run a first **playbook** (plays → tasks → modules), and find/read module docs

---

## Prerequisites

- **Vagrant + VirtualBox** installed (Week 1 · Day 1)
- Comfort with **SSH keys and `~/.ssh/authorized_keys`** (Week 2 · Day 3) — Ansible *is* SSH under the hood
- ~3.5 GB free RAM (three small VMs)

---

## Theory · ~20 min

### 1. Why configuration management

Configuring servers by hand doesn't scale and isn't repeatable — you forget a step, or two "identical" servers drift apart. **Configuration management** tools let you *declare* the desired state of a machine in code and have the tool make reality match. The benefits: **repeatable** (same result every run), **version-controlled** (your infra changes live in git), and **self-documenting** (the playbook *is* the runbook).

Ansible is one of several such tools (Puppet, Chef, SaltStack) — it won out for most teams because it's **simple** and **agentless**.

### 2. What makes Ansible different

Four traits define how Ansible works — keep them in mind as everything below builds on them:

| Trait | Meaning |
|---|---|
| **Agentless** | No daemon to install on managed machines — it works over plain **SSH** |
| **Push-based** | The control node *pushes* changes out on demand (vs. agents that *pull* on a schedule) |
| **Declarative** | You describe the **desired state**, not the commands to reach it |
| **Idempotent** | Running the same playbook twice is safe — it only changes what's out of line |

!!! note "Declarative vs imperative"
    **Imperative** = "run `apt install nginx`" (a *command*). **Declarative** = "nginx should be **present**" (a *state*). Ansible is declarative — you say *what* you want and it decides *whether* it needs to act. That's exactly what makes idempotency possible.

**Idempotency in practice:** on the first run Ansible installs nginx (**changed**); on the second run it sees nginx already there and does nothing (**ok**). Every task reports one of **ok** (already correct), **changed** (Ansible fixed it), or **failed** — which is why re-running a playbook is safe, and why Ansible can run on a schedule to correct drift.

### 3. Design & architecture

Ansible has just two roles, and nothing Ansible-specific on the managed side:

- **Control node** — where Ansible is installed and where you run commands (your laptop, a CI runner, or — today — a dedicated VM). *Never Windows.*
- **Managed nodes** — the machines being configured. They need only **SSH access** and **Python**.

When you run a task, the control node **connects over SSH**, **pushes a small Python module** to the managed node, **executes it**, collects the result, and **removes it**:

```
   Control node                         Managed nodes
┌───────────────┐   SSH (push module)  ┌──────────┐
│    Ansible    │ ───────────────────▶ │  web1    │
│  playbooks +  │ ───────────────────▶ │  web2    │
│   inventory   │        ...           │  ...     │
└───────────────┘                      └──────────┘
```

That's the whole trick: if you can SSH to it, Ansible can manage it.

!!! tip "📺 Watch — *Ansible in 100 Seconds* (Fireship, ~2.5 min)"
    A rapid primer on what Ansible is and why "agentless" matters — watch before the lab.

    [![Ansible in 100 Seconds](https://img.youtube.com/vi/xRMPKQweySE/hqdefault.jpg){ width="360" }](https://youtu.be/xRMPKQweySE)

### 4. Where Ansible's configuration lives

Ansible's behaviour is controlled by an **`ansible.cfg`** file, and it searches a fixed order — **the first one found wins** (settings are *not* merged across files):

| Order | Location | Use |
|---|---|---|
| 1 | `ANSIBLE_CONFIG` env var | Explicit override |
| 2 | `./ansible.cfg` | **Per-project** — what you'll use |
| 3 | `~/.ansible.cfg` | Per-user |
| 4 | `/etc/ansible/ansible.cfg` | System-wide default |

A fresh install also drops a default layout under **`/etc/ansible/`** (a sample `hosts` inventory and a roles path). In practice you ignore the system files and keep a **project-local `ansible.cfg`** next to your playbooks:

```ini
[defaults]
inventory = ./inventory.ini      # so you can omit -i every time
host_key_checking = False        # skip the SSH "trust this host?" prompt in a lab
```

`ansible --version` prints which config file is currently active — handy when a setting "isn't taking."

### 5. Inventory & groups

The **inventory** lists the hosts Ansible manages, organized into **groups** so you can target many at once. It's usually an INI (or YAML) file. Here are two patterns you'll reuse — keep them as reference points:

```ini
# ── Example 1: the basics — a host alias, its address, and login user ──
web1 ansible_host=192.168.56.30 ansible_user=vagrant


# ── Example 2: groups + a group-wide variable + a per-host override ────
[web]
web1 ansible_host=192.168.56.30 ansible_user=vagrant
web2 ansible_host=192.168.56.31 ansible_user=vagrant ansible_port=2222   # per-host override

[web:vars]                          # a variable shared by EVERY host in [web]
ansible_ssh_private_key_file=~/.ssh/id_ed25519
```

Two group names always exist: **`all`** (every host) and **`ungrouped`** (hosts in no group). You target any host or group by name — `ansible web ...`, `ansible all ...`.

### 6. Ad-hoc commands

An **ad-hoc command** runs a single module against hosts for one-off jobs (check uptime, restart a service) — no file needed. It uses the `ansible` command:

```bash
ansible web -m ping                                # is the group reachable?
ansible web -m command -a "uptime"                 # run a command everywhere
ansible web -b -m apt -a "name=curl state=present" # -b = become (sudo)
```

`-m` picks the **module**, `-a` passes its **arguments**. Ad-hoc is great for exploring; repeatable work belongs in a **playbook**.

### 7. Playbooks — plays, tasks & modules

!!! tip "📺 New to YAML? Watch this first — *YAML Explained in 10 Minutes* (KodeKloud, ~8 min)"
    Playbooks are written in **YAML**. If the syntax below looks unfamiliar, watch this first — indentation, lists, and dictionaries are all you need to read every playbook this week.

    [![YAML Explained: A Beginner's Guide](https://img.youtube.com/vi/o9pT9cWzbnI/hqdefault.jpg){ width="360" }](https://youtu.be/o9pT9cWzbnI)

    **Chapters:** [what is YAML](https://youtu.be/o9pT9cWzbnI?t=30) · [spaces & indentation](https://youtu.be/o9pT9cWzbnI?t=163) · [dictionary vs list vs list-of-dictionaries](https://youtu.be/o9pT9cWzbnI?t=249)

A **playbook** is a **YAML** file: a list of **plays**; each play maps a group of hosts to an ordered list of **tasks**; each task calls a **module**. YAML is indentation-sensitive — two spaces, never tabs:

```yaml
- name: Configure web servers      # ← a PLAY (list items start with '-')
  hosts: web                       #   which hosts it targets
  become: true                     #   run tasks as root (sudo)
  tasks:
    - name: Install nginx          # ← a TASK
      ansible.builtin.apt:         # ← a MODULE (the verb)
        name: nginx                #   ┐ module
        state: present             #   ┘ arguments
```

- **`name:`** — a human label printed as the play/task runs.
- **`become: true`** — **privilege escalation**: run with `sudo` (set per-play or per-task). Installing packages needs root; on the Vagrant boxes the `vagrant` user has passwordless sudo, so it "just works."
- **The module** — the `ansible.builtin.apt` line is the *verb* that does the work; browse the full catalog in the [Ansible module index](https://docs.ansible.com/ansible/latest/collections/index_module.html) or list them locally with `ansible-doc -l`.
- **Indentation is structure** — a wrong indent is the #1 beginner error.

!!! note "📖 Reference — YAML syntax"
    New to the format? Ansible's [**YAML Syntax**](https://docs.ansible.com/projects/ansible/latest/reference_appendices/YAMLSyntax.html#yaml-syntax) page is the concise reference for lists, dictionaries, quoting, and multi-line strings — the whole subset you need to read every playbook.

**Project layout.** One playbook is a single file, but real projects follow a conventional tree so Ansible finds things automatically (you'll fill this out on Day 2):

```
fleet/
├── ansible.cfg          # project config (Section 4)
├── inventory.ini        # hosts & groups (Section 5)
├── group_vars/          # variables per group
├── host_vars/           # variables per host
├── site.yml             # the top-level playbook
└── roles/               # reusable units (Day 2)
```

### 8. Modules & reading the docs

A **module** is the unit of work — `apt`, `copy`, `service`, `user`, and thousands more. Two things to know:

- **Where they live.** Core modules ship as **`ansible.builtin.*`** (e.g. `ansible.builtin.apt`). The rest come in **collections** installed from Ansible Galaxy (e.g. `community.postgresql.*`). The fully-qualified name (FQCN) is future-proof; the short name (`apt`) still works.
- **How to find & read them.** Every module is self-documenting from the command line:

```bash
ansible-doc -l            # list every available module
ansible-doc apt           # full docs + copy-paste examples for one module
```

…or browse [docs.ansible.com](https://docs.ansible.com/ansible/latest/collections/index_module.html). Before using a module, skim its **parameters**, its **`state`** options, and the **Examples** at the bottom — that's where the real usage lives.

---

## Lab · ~50 min

Work on your **host machine**; you'll build the fleet with Vagrant, then drive it from the control node.

### Step 1 — Create the lab and build the fleet

Write the **simplest possible** Vagrantfile — three boxes, 1 GB each, static IPs, and *nothing else*. No auto-provisioning: you'll install and wire up everything yourself, so you learn what each piece is for.

```ruby
mkdir -p ~/ansible-lab && cd ~/ansible-lab

cat > Vagrantfile << 'EOF'
Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-24.04"

  # control node on .20, managed nodes on .30 / .31 (so they're easy to tell apart)
  nodes = { "control" => "192.168.56.20",
            "web1"    => "192.168.56.30",
            "web2"    => "192.168.56.31" }

  nodes.each do |name, ip|
    config.vm.define name do |node|
      node.vm.hostname = name
      node.vm.network "private_network", ip: ip
      node.vm.provider "virtualbox" do |vb|
        vb.name   = name
        vb.memory = 1024
        vb.cpus   = 1
      end
    end
  end
end
EOF

vagrant up            # first run downloads the box + builds 3 VMs (~a few minutes)
vagrant status        # control, web1, web2 all "running"
```

### Step 2 — Install Ansible on the control node

Ansible lives **only** on the control node. Log in and install it by hand:

```bash
vagrant ssh control

# now inside the control node:
sudo apt-get update
sudo apt-get install -y software-properties-common
sudo add-apt-repository --yes --update ppa:ansible/ansible
sudo apt-get install -y ansible
ansible --version
```

### Step 3 — Glue it together: authorize the control node's SSH key

This is the part auto-provisioning usually hides. Ansible reaches the managed nodes over **plain SSH**, so the control node's **public key** must live in each managed node's `~/.ssh/authorized_keys`. (The managed nodes already have Python — the only other thing Ansible needs.)

**a) On the control node, create a key pair and print the public half:**

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""   # no passphrase → non-interactive
cat ~/.ssh/id_ed25519.pub                           # ← copy this whole line
exit                                                # back to the host
```

**b) Paste that public key into each managed node's `authorized_keys`:**

```bash
vagrant ssh web1
  # inside web1 — paste the line you copied from the control node:
  echo 'ssh-ed25519 AAAA...paste-control-public-key...' >> ~/.ssh/authorized_keys
  exit

vagrant ssh web2
  # inside web2 — the same line:
  echo 'ssh-ed25519 AAAA...paste-control-public-key...' >> ~/.ssh/authorized_keys
  exit
```

**c) Verify from the control node** — you should log in with *no password prompt*:

```bash
vagrant ssh control
ssh vagrant@192.168.56.30 hostname     # → web1
ssh vagrant@192.168.56.31 hostname     # → web2
```

!!! tip "The real-world shortcut"
    On actual servers you'd distribute the key with one command per host — `ssh-copy-id vagrant@192.168.56.30` — which does exactly this `authorized_keys` append for you. Doing it by hand once shows you what it's automating.

### Step 4 — Write the inventory and `ansible.cfg`

Back **inside the control node**, describe the fleet:

```bash
mkdir -p ~/fleet && cd ~/fleet

cat > inventory.ini << 'EOF'
[web]
web1 ansible_host=192.168.56.30 ansible_user=vagrant
web2 ansible_host=192.168.56.31 ansible_user=vagrant
EOF

cat > ansible.cfg << 'EOF'
[defaults]
inventory = ./inventory.ini
host_key_checking = False
EOF

ansible --version           # the config file should now point at ~/fleet/ansible.cfg
```

### Step 5 — Ad-hoc commands

```bash
ansible web -m ping                          # green "pong" from both = success
ansible web -m command -a "uptime"           # run a command everywhere
ansible web -m setup -a "filter=ansible_distribution*"   # gather a few facts
ansible web -b -m apt -a "name=curl state=present"       # -b = become (install curl)
```

`ansible web -m ping` is your smoke test — if that's green, SSH, the key, and Python are all working.

### Step 6 — Your first playbooks

**6a · A simple "hello world" playbook**

Start with the smallest useful play — install nginx and drop a one-line homepage on each host:

```bash
cat > site.yml << 'EOF'
- name: Configure web servers
  hosts: web
  become: true
  tasks:
    - name: Install nginx
      ansible.builtin.apt:
        name: nginx
        state: present
        update_cache: true

    - name: Deploy a homepage
      ansible.builtin.copy:
        content: "Hello from {{ inventory_hostname }}\n"
        dest: /var/www/html/index.html

    - name: Ensure nginx is running and enabled
      ansible.builtin.service:
        name: nginx
        state: started
        enabled: true
EOF

ansible-playbook site.yml
```

The first run shows tasks as **changed**. Verify it:

```bash
curl http://192.168.56.30       # → Hello from web1
curl http://192.168.56.31       # → Hello from web2
```

Now run the **exact same** playbook again:

```bash
ansible-playbook site.yml
```

This time every task is **ok** and the recap shows `changed=0` — nothing was touched because reality already matched the declaration. That's **idempotency**, and it's what makes Ansible safe to re-run.

**6b · Deploy a real site from a zip**

Real deployments ship files, not one-liners. First, **download the site archive onto the control node**, into `~/fleet` — Ansible's `copy` module looks for `src:` files next to the playbook:

```bash
cd ~/fleet
curl -L -o site.zip https://github.com/user-attachments/files/30199374/site.zip
```

!!! note
    If that URL returns *404 Not Found*, it isn't publicly reachable — host `site.zip` at a stable public URL (this course's repo or a GitHub release) and download that instead.

Then write a playbook that installs `unzip`, ships the archive to each node, extracts it into the web root, and reboots:

```bash
cat > deploy-site.yml << 'EOF'
- name: Configure web servers
  hosts: web
  become: true

  tasks:
    - name: Install nginx and unzip
      ansible.builtin.apt:
        name:
          - nginx
          - unzip
        state: present
        update_cache: true

    - name: Ensure web root exists
      ansible.builtin.file:
        path: /var/www/html
        state: directory

    - name: Copy site.zip to managed node
      ansible.builtin.copy:
        src: site.zip
        dest: /tmp/site.zip
        mode: "0644"

    - name: Extract site.zip into web root
      ansible.builtin.unarchive:
        src: /tmp/site.zip
        dest: /var/www/html
        remote_src: true

    - name: Ensure nginx is running and enabled
      ansible.builtin.service:
        name: nginx
        state: started
        enabled: true

    - name: Restart nginx to pick up the new site
      ansible.builtin.service:
        name: nginx
        state: restarted
EOF

ansible-playbook deploy-site.yml
```

Verify the deployed site:

```bash
curl http://192.168.56.30       # → the site from site.zip
curl http://192.168.56.31
```

!!! note "Not every play is idempotent"
    Unlike 6a, this play ends with a **restart** (`state: restarted`) — that task runs *every* time, so re-running `deploy-site.yml` always reports `changed`. Idempotency is a property of the modules you choose, not something you get for free. (A more idempotent pattern is to trigger a restart only when the site actually changes, using a **handler** — you'll meet those tomorrow.)

### Step 7 — Stop or keep the fleet

```bash
exit                 # back to host
# vagrant halt       # stop the fleet, keep it for tomorrow (recommended)
# vagrant destroy -f # only if you want to reclaim the disk
```

!!! tip "Keep the fleet"
    Leave these VMs around (`vagrant halt` to save RAM) — **Day 2 builds directly on this inventory** with variables, templates, and roles.

---

## Advanced Topics

Deeper references for when you need them:

- [Configuration settings](https://docs.ansible.com/ansible/latest/reference_appendices/config.html) — every `ansible.cfg` option
- [Building inventory](https://docs.ansible.com/ansible/latest/inventory_guide/intro_inventory.html) — INI/YAML, groups, `group_vars` / `host_vars`, patterns
- [Dynamic inventory](https://docs.ansible.com/ansible/latest/inventory_guide/intro_dynamic_inventory.html) — generate hosts from a cloud/API (how you'll target AWS later)
- [Ansible Vault](https://docs.ansible.com/ansible/latest/vault_guide/index.html) — encrypt secrets kept in git
- [Check mode & diff](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_checkmode.html) — preview changes before applying (dry run)

---

## Assignment

Write a playbook that installs `htop`, `tree`, and `jq` on the `web` group — then use a single ad-hoc command to print each tool's version from every node at once.

---

## Further Reading

**Watch**

- 📺 [YAML Explained in 10 Minutes](https://youtu.be/o9pT9cWzbnI) (KodeKloud) — the syntax playbooks are written in; watch first if YAML is new to you
- 📺 [Ansible in 100 Seconds](https://youtu.be/xRMPKQweySE) (Fireship) — the fastest possible intro
- 📺 Jeff Geerling's **Ansible 101** — [Ep 1 · Introduction](https://youtu.be/goclfp6a2IQ) · [Ep 2 · Inventory & ad-hoc](https://youtu.be/7kVfqmGtDL8) · [Ep 3 · Playbooks](https://youtu.be/WNmKjtWtqIc) · [Ep 4 · First real-world playbook](https://youtu.be/SLW4LX7lbvE) — the definitive free series, by the author of the roles you'll install tomorrow
- 📺 [Ansible Full Course · Zero to Hero](https://youtu.be/GROqwFFLl3s) (Rahul Wagh, ~3.5 hr) — one comprehensive, chaptered course covering both Ansible days end to end

**Reference**

- [Ansible — Getting Started](https://docs.ansible.com/ansible/latest/getting_started/index.html) — the official on-ramp
- [YAML Syntax](https://docs.ansible.com/projects/ansible/latest/reference_appendices/YAMLSyntax.html#yaml-syntax) — the concise syntax reference for playbooks
- [How Ansible works](https://www.ansible.com/overview/how-ansible-works) — architecture in one page
- [Ansible module index](https://docs.ansible.com/ansible/latest/collections/index_module.html) — every built-in verb
- [Idempotency, explained](https://docs.ansible.com/ansible/latest/reference_appendices/glossary.html#term-Idempotency) — the concept that makes it all safe
