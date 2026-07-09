# Day 18 · Ansible III — Roles, Variables & Templates

## Learning Objectives

- Organize Ansible code into reusable roles
- Use variables, defaults, and Jinja2 templates
- Build a role that fully configures an Nginx server with a templated config

---

## Theory · ~20 min

### Variables

Variables make playbooks flexible and reusable. You define them in several places (in priority order, highest wins):

1. Command line `-e "key=value"`
2. `vars:` in the play
3. `host_vars/<hostname>.yml`
4. `group_vars/<group>.yml`
5. Role `defaults/main.yml` (lowest priority)

```yaml
# In a play
vars:
  app_port: 8080
  app_name: myapp

tasks:
  - name: Start app
    service:
      name: "{{ app_name }}"
      state: started
```

### Jinja2 Templates

Templates let you generate dynamic config files from variables:

```jinja2
# nginx.conf.j2
server {
    listen {{ nginx_port }};
    server_name {{ server_name }};
    root {{ web_root }};
}
```

Ansible renders this with actual variable values before copying to the target.

### Roles

A role is a structured directory that bundles tasks, handlers, templates, files, and variables into a reusable unit.

```
roles/
└── nginx/
    ├── tasks/
    │   └── main.yml      ← main task list
    ├── handlers/
    │   └── main.yml      ← handlers
    ├── templates/
    │   └── nginx.conf.j2 ← Jinja2 templates
    ├── files/
    │   └── index.html    ← static files
    ├── vars/
    │   └── main.yml      ← variables (high priority)
    └── defaults/
        └── main.yml      ← defaults (low priority, easy to override)
```

Use a role in a playbook:

```yaml
- name: Configure web servers
  hosts: webservers
  roles:
    - nginx
```

---

## Lab · ~50 min

### Step 1 — Create a role skeleton

```bash
cd ~/ansible-labs

# Create the directory structure
ansible-galaxy role init roles/nginx

# See what was created
tree roles/nginx/
```

### Step 2 — Fill in the role

```bash
# defaults — low priority, easy to override
cat > roles/nginx/defaults/main.yml << 'EOF'
---
nginx_port: 80
nginx_server_name: "_"
nginx_web_root: /var/www/html
nginx_worker_processes: auto
nginx_worker_connections: 1024
EOF

# tasks
cat > roles/nginx/tasks/main.yml << 'EOF'
---
- name: Install nginx
  apt:
    name: nginx
    state: present
    update_cache: true

- name: Deploy nginx main config
  template:
    src: nginx.conf.j2
    dest: /etc/nginx/nginx.conf
    owner: root
    group: root
    mode: "0644"
  notify: Reload nginx

- name: Deploy site config
  template:
    src: site.conf.j2
    dest: /etc/nginx/sites-available/default
    owner: root
    group: root
    mode: "0644"
  notify: Reload nginx

- name: Deploy index.html
  template:
    src: index.html.j2
    dest: "{{ nginx_web_root }}/index.html"
    owner: www-data
    group: www-data
    mode: "0644"

- name: Ensure nginx is started and enabled
  service:
    name: nginx
    state: started
    enabled: true
EOF

# handlers
cat > roles/nginx/handlers/main.yml << 'EOF'
---
- name: Reload nginx
  service:
    name: nginx
    state: reloaded

- name: Restart nginx
  service:
    name: nginx
    state: restarted
EOF
```

### Step 3 — Write Jinja2 templates

```bash
# Main nginx.conf template
cat > roles/nginx/templates/nginx.conf.j2 << 'EOF'
user www-data;
worker_processes {{ nginx_worker_processes }};
pid /run/nginx.pid;

events {
    worker_connections {{ nginx_worker_connections }};
}

http {
    sendfile on;
    tcp_nopush on;
    types_hash_max_size 2048;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    gzip on;

    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
EOF

# Site config template
cat > roles/nginx/templates/site.conf.j2 << 'EOF'
server {
    listen {{ nginx_port }};
    server_name {{ nginx_server_name }};
    root {{ nginx_web_root }};
    index index.html;

    access_log /var/log/nginx/{{ nginx_server_name }}_access.log;
    error_log  /var/log/nginx/{{ nginx_server_name }}_error.log;

    location / {
        try_files $uri $uri/ =404;
    }

    location /health {
        return 200 'ok';
        add_header Content-Type text/plain;
    }
}
EOF

# index.html template
cat > roles/nginx/templates/index.html.j2 << 'EOF'
<!DOCTYPE html>
<html>
<head><title>{{ nginx_server_name }}</title></head>
<body>
  <h1>{{ nginx_server_name }}</h1>
  <p>Configured by Ansible on {{ ansible_date_time.date }}</p>
  <p>Host: {{ ansible_hostname }} | IP: {{ ansible_default_ipv4.address }}</p>
</body>
</html>
EOF
```

### Step 4 — Use the role in a playbook

```bash
cat > deploy.yml << 'EOF'
---
- name: Deploy web servers
  hosts: webservers
  become: true

  roles:
    - role: nginx
      vars:
        nginx_port: 80
        nginx_server_name: "devops-month.local"
EOF

ansible-playbook -i inventory.ini deploy.yml

# Test
curl http://192.168.56.11
curl http://192.168.56.11/health
```

### Step 5 — Override defaults per host

```bash
# Per-host variables
mkdir -p host_vars
cat > host_vars/node1.yml << 'EOF'
nginx_server_name: node1.local
nginx_worker_connections: 512
EOF

ansible-playbook -i inventory.ini deploy.yml

# See the difference in the config on node1
ansible webservers -i inventory.ini -m shell -a "cat /etc/nginx/sites-available/default"
```

---

## Assignment

Create a role `roles/app` that:

1. Deploys a simple Python Flask app (you can reuse Day 13's `app.py`)
2. Installs Python3 and pip from `defaults/main.yml` variables
3. Copies the app file using a `files/` directory
4. Creates a systemd service using a Jinja2 template (`files/app.service.j2`)
5. Ensures the service is started and enabled

Answer:
- What is the difference between `vars/main.yml` and `defaults/main.yml` in a role?
- What is Jinja2? Give one example of a template expression and what it produces.
- Why are roles better than a single large playbook?

---

## Further Reading

- [Ansible roles guide](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_reuse_roles.html)
- [Jinja2 templating in Ansible](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_templating.html)
- [Ansible Galaxy](https://galaxy.ansible.com/) — community roles you can reuse
