# Day 17 · Ansible II — Playbooks

## Learning Objectives

- Write Ansible playbooks to automate server configuration
- Use tasks, handlers, and conditionals in playbooks
- Run a playbook to fully configure an Nginx web server

---

## Theory · ~20 min

### What is a Playbook?

A **playbook** is a YAML file that defines a series of **plays**. Each play targets a group of hosts and runs a list of **tasks**.

```yaml
---
- name: Configure web servers         # play name
  hosts: webservers                   # target host group
  become: true                        # run as sudo

  tasks:
    - name: Install nginx             # task name
      apt:
        name: nginx
        state: present

    - name: Start nginx
      service:
        name: nginx
        state: started
        enabled: true
```

### Tasks

Each task calls an **Ansible module** with parameters. Modules are idempotent — they check current state before making changes.

Common modules:

| Module | Purpose |
|---|---|
| `apt` / `yum` | Package management |
| `service` | Manage systemd services |
| `copy` | Copy files to remote |
| `template` | Copy Jinja2 templates with variables |
| `file` | Manage files, dirs, permissions |
| `user` | Manage system users |
| `shell` / `command` | Run shell commands |
| `git` | Clone/update git repos |
| `lineinfile` | Ensure a line exists in a file |

### Handlers

Handlers are tasks triggered by `notify` — they run at the end of the play, only if notified, and only once regardless of how many tasks notify them.

```yaml
tasks:
  - name: Copy nginx config
    copy:
      src: nginx.conf
      dest: /etc/nginx/nginx.conf
    notify: Restart nginx           # trigger the handler

handlers:
  - name: Restart nginx
    service:
      name: nginx
      state: restarted
```

This pattern is clean: the config task doesn't restart nginx directly — it delegates to a handler that runs once after all tasks finish.

---

## Lab · ~50 min

### Step 1 — Write your first playbook

```bash
cd ~/ansible-labs

cat > site.yml << 'EOF'
---
- name: Configure all nodes
  hosts: all
  become: true

  tasks:
    - name: Update apt cache
      apt:
        update_cache: true
        cache_valid_time: 3600

    - name: Install common packages
      apt:
        name:
          - curl
          - git
          - htop
          - unzip
        state: present

    - name: Ensure /opt/devops directory exists
      file:
        path: /opt/devops
        state: directory
        owner: root
        group: root
        mode: "0755"

    - name: Create a version file
      copy:
        content: "configured by ansible on {{ ansible_date_time.date }}\n"
        dest: /opt/devops/version.txt
EOF

# Run it
ansible-playbook -i inventory.ini site.yml

# Run again — notice the "changed" vs "ok" counts
ansible-playbook -i inventory.ini site.yml
```

### Step 2 — Playbook with handlers

```bash
# Create an nginx config file locally
mkdir -p files

cat > files/nginx.conf << 'EOF'
server {
    listen 80;
    server_name _;

    location / {
        root /var/www/html;
        index index.html;
    }

    location /health {
        return 200 'ok';
        add_header Content-Type text/plain;
    }
}
EOF

cat > webserver.yml << 'EOF'
---
- name: Configure web servers
  hosts: webservers
  become: true

  tasks:
    - name: Install nginx
      apt:
        name: nginx
        state: present
        update_cache: true

    - name: Copy nginx site config
      copy:
        src: files/nginx.conf
        dest: /etc/nginx/sites-available/default
        owner: root
        group: root
        mode: "0644"
      notify: Reload nginx

    - name: Deploy index.html
      copy:
        content: |
          <html>
          <body><h1>Configured by Ansible</h1></body>
          </html>
        dest: /var/www/html/index.html

    - name: Ensure nginx is running and enabled
      service:
        name: nginx
        state: started
        enabled: true

  handlers:
    - name: Reload nginx
      service:
        name: nginx
        state: reloaded
EOF

ansible-playbook -i inventory.ini webserver.yml

# Test
curl http://192.168.56.11
curl http://192.168.56.11/health
```

### Step 3 — Conditionals and facts

```bash
cat > facts_demo.yml << 'EOF'
---
- name: OS-conditional tasks
  hosts: all
  become: true

  tasks:
    - name: Show OS information
      debug:
        msg: "Running {{ ansible_distribution }} {{ ansible_distribution_version }}"

    - name: Install packages on Debian/Ubuntu
      apt:
        name: tree
        state: present
      when: ansible_os_family == "Debian"

    - name: Install packages on RedHat/CentOS
      yum:
        name: tree
        state: present
      when: ansible_os_family == "RedHat"

    - name: Warn if low memory
      debug:
        msg: "WARNING: Low memory! Only {{ ansible_memfree_mb }}MB free"
      when: ansible_memfree_mb < 256
EOF

ansible-playbook -i inventory.ini facts_demo.yml
```

### Step 4 — Dry run and verbosity

```bash
# Check mode — show what WOULD change, without making changes
ansible-playbook -i inventory.ini webserver.yml --check

# Diff mode — show exact file changes
ansible-playbook -i inventory.ini webserver.yml --check --diff

# Verbose output for debugging
ansible-playbook -i inventory.ini webserver.yml -v     # basic
ansible-playbook -i inventory.ini webserver.yml -vv    # more detail
ansible-playbook -i inventory.ini webserver.yml -vvv   # full SSH debug

# Run only specific tags
ansible-playbook -i inventory.ini webserver.yml --tags nginx

# Skip specific tags
ansible-playbook -i inventory.ini webserver.yml --skip-tags deploy
```

### Step 5 — Limit to specific hosts

```bash
# Run against a single host
ansible-playbook -i inventory.ini webserver.yml --limit node1

# Run against a pattern
ansible-playbook -i inventory.ini site.yml --limit "node*"

# Dry run on a specific host
ansible-playbook -i inventory.ini webserver.yml --limit node1 --check
```

---

## Assignment

Write a playbook `~/ansible-labs/database.yml` that:

1. Targets the `databases` group
2. Installs `postgresql` and ensures it is running and enabled
3. Creates a system user named `deploy`
4. Creates a directory `/opt/myapp/data` with `deploy` as owner
5. Uses a handler to restart PostgreSQL only when a config file changes

Answer:
- What is the difference between a `task` and a `handler`?
- What does `become: true` do and when is it needed?
- Why is `cache_valid_time` useful in the `apt` module?

---

## Further Reading

- [Ansible playbook guide](https://docs.ansible.com/ansible/latest/playbook_guide/index.html)
- [Ansible conditionals](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_conditionals.html)
- [Ansible all modules list](https://docs.ansible.com/ansible/latest/collections/index_module.html)
