# Day 2 · Ansible II — Variables, Facts, Templates & Roles

> Yesterday you drove a fleet with a flat playbook. That's fine for three lines — but real config has values that differ per host, files that must be generated from data, and logic that should only run when something actually changed. Today you make playbooks **data-driven and reusable**: variables and facts feed **Jinja2 templates**, **handlers** react to change, and everything gets packaged into a **role** you can share via **Ansible Galaxy**. By the end, "configure a web server" is one reusable unit you point at any inventory.

## Learning Objectives

- Store configuration in **variables** and understand where they live and which wins (**precedence**)
- Use **facts** — data Ansible gathers about each host — inside tasks and templates
- Generate config files from **Jinja2 templates**
- React to change with **handlers** (`notify`)
- Control flow with **loops** and **conditionals** (`when`)
- Package a workflow as a **role** and pull community content from **Ansible Galaxy**

---

## Prerequisites

- The **control + web1 + web2** Vagrant fleet from Day 1 (`vagrant up` if you halted it)
- The `~/fleet` project (inventory + `ansible.cfg`) on the control node

---

## Theory · ~20 min

### 1. Variables — and where they live

A **variable** is a named value you reference with `{{ mustache }}` syntax. They can be defined in many places; the ones you'll use most:

| Location | Scope |
|---|---|
| `vars:` in a play | Just that play |
| `group_vars/<group>.yml` | Every host in a group |
| `host_vars/<host>.yml` | One host |
| `--extra-vars` on the CLI | Overrides almost everything |

```yaml
# group_vars/web.yml — applies to web1 and web2
site_name: "Operation Go Live"
worker_processes: 2
```

**Precedence** (simplified): CLI `--extra-vars` > `host_vars` > `group_vars` > play `vars` > role defaults. When two sources set the same variable, the higher one wins.

### 2. Facts — what Ansible knows about a host

Before running tasks, Ansible **gathers facts** — hostname, IP addresses, OS, CPU count, memory, and hundreds more. Reference them like any variable:

```yaml
- debug:
    msg: "{{ inventory_hostname }} runs {{ ansible_distribution }} {{ ansible_distribution_version }}"
```

See them all with `ansible web1 -m setup`. Facts let one playbook adapt to each machine (e.g. size a config by `ansible_processor_vcpus`).

### 3. Jinja2 templates

A **template** is a file with `{{ variables }}` and logic that Ansible renders per host with the `template` module. This is how you generate real config files:

```jinja
# nginx.conf.j2
worker_processes {{ worker_processes }};
server {
    server_name {{ inventory_hostname }};
    # rendered on {{ ansible_distribution }}
}
```

Templates support **filters** (`{{ name | upper }}`, `{{ port | default(80) }}`), **conditionals** (`{% if %}`), and **loops** (`{% for %}`).

### 4. Handlers — act only on change

A **handler** is a task that runs *only when notified* by a changed task — perfect for "restart nginx, but only if its config actually changed":

```yaml
tasks:
  - name: Deploy nginx config
    ansible.builtin.template:
      src: nginx.conf.j2
      dest: /etc/nginx/sites-available/default
    notify: Restart nginx

handlers:
  - name: Restart nginx
    ansible.builtin.service:
      name: nginx
      state: restarted
```

If the template render is `ok` (no change), the handler never fires. Idempotency, applied to services.

### 5. Loops and conditionals

```yaml
- name: Install several packages
  ansible.builtin.apt:
    name: "{{ item }}"
    state: present
  loop:
    - nginx
    - curl
    - git

- name: Only on Ubuntu
  ansible.builtin.debug: msg="Debian-family host"
  when: ansible_os_family == "Debian"
```

### 6. Roles — the unit of reuse

A **role** is a standard directory layout that bundles tasks, templates, variables, handlers, and defaults so a workflow becomes portable:

```
roles/webserver/
├── tasks/main.yml        # the steps
├── handlers/main.yml     # notified handlers
├── templates/            # *.j2 files
├── defaults/main.yml     # default variables (lowest precedence)
└── vars/main.yml         # role variables (higher precedence)
```

A playbook then just *includes* it:

```yaml
- hosts: web
  become: true
  roles:
    - webserver
```

!!! tip "📺 Watch — *Ansible 101 · Ep 6 — Vault & Roles* (Jeff Geerling, ~1 hr)"
    The definitive walkthrough of roles — from the author of the community roles you're installing. Jump to what maps to today:

    [![Ansible 101 — Vault & Roles](https://img.youtube.com/vi/JFweg2dUvqM/hqdefault.jpg){ width="360" }](https://youtu.be/JFweg2dUvqM)

    **Chapters:** [conditionals & tags](https://youtu.be/JFweg2dUvqM?t=1293) · [playbook organization](https://youtu.be/JFweg2dUvqM?t=1646) · [roles](https://youtu.be/JFweg2dUvqM?t=2766) · [flexible role usage](https://youtu.be/JFweg2dUvqM?t=3150) · [Ansible Vault](https://youtu.be/JFweg2dUvqM?t=651)

### 7. Ansible Galaxy

**[Galaxy](https://galaxy.ansible.com)** is the public hub for community **roles** and **collections** (bundles of modules/plugins). Scaffold your own or install others':

```bash
ansible-galaxy role init webserver              # scaffold the layout above
ansible-galaxy role install geerlingguy.nginx   # pull a popular community role
ansible-galaxy collection install community.postgresql
```

---

## Lab · ~50 min

Run everything **inside the control node**, in `~/fleet`.

### Step 1 — Group variables

```bash
cd ~/fleet && mkdir -p group_vars
cat > group_vars/web.yml << 'EOF'
site_name: "Operation Go Live"
worker_processes: 2
EOF
```

### Step 2 — A fact-aware template

```bash
mkdir -p templates
cat > templates/index.html.j2 << 'EOF'
<h1>{{ site_name }}</h1>
<p>Served by {{ inventory_hostname }} ({{ ansible_default_ipv4.address }})</p>
<p>OS: {{ ansible_distribution }} {{ ansible_distribution_version }} — {{ ansible_processor_vcpus }} vCPU</p>
EOF
```

### Step 3 — Playbook with a template + handler

```bash
cat > web.yml << 'EOF'
- name: Configure web servers
  hosts: web
  become: true
  tasks:
    - name: Install nginx
      ansible.builtin.apt:
        name: nginx
        state: present
        update_cache: true

    - name: Render the homepage
      ansible.builtin.template:
        src: templates/index.html.j2
        dest: /var/www/html/index.html
      notify: Restart nginx

  handlers:
    - name: Restart nginx
      ansible.builtin.service:
        name: nginx
        state: restarted
EOF

ansible-playbook web.yml
curl http://192.168.56.11        # note the per-host IP/OS/vCPU in the output
```

Run it **again** — the template task is `ok`, so the handler does **not** fire (`changed=0`). Now bump `worker_processes` in `group_vars/web.yml`, edit the template to print it, re-run, and watch the handler restart nginx *only* because the file changed.

### Step 4 — Refactor into a role

```bash
ansible-galaxy role init roles/webserver

# Move the logic into the role
cp templates/index.html.j2 roles/webserver/templates/

cat > roles/webserver/tasks/main.yml << 'EOF'
- name: Install nginx
  ansible.builtin.apt:
    name: nginx
    state: present
    update_cache: true

- name: Render the homepage
  ansible.builtin.template:
    src: index.html.j2
    dest: /var/www/html/index.html
  notify: Restart nginx
EOF

cat > roles/webserver/handlers/main.yml << 'EOF'
- name: Restart nginx
  ansible.builtin.service:
    name: nginx
    state: restarted
EOF

cat > roles/webserver/defaults/main.yml << 'EOF'
site_name: "Default Site"
worker_processes: 1
EOF
```

Now the playbook is just:

```bash
cat > site.yml << 'EOF'
- hosts: web
  become: true
  roles:
    - webserver
EOF

ansible-playbook site.yml        # same result — now packaged and reusable
```

### Step 5 — Pull a role from Galaxy

```bash
ansible-galaxy role install geerlingguy.ntp
ansible-galaxy role list                     # see what's installed
```

(Browse [geerlingguy's roles](https://galaxy.ansible.com/geerlingguy) — Jeff Geerling's are the community gold standard and worth reading as examples.)

```bash
exit
# vagrant halt    # keep the fleet; you're done with Ansible after today
```

---

## Advanced Topics

- **`vars_files` and Vault** — keep secrets in an encrypted file: `ansible-vault create secrets.yml`, then reference it with `vars_files`.
- **`register` and conditionals** — capture a task's result into a variable and branch on it (`when: result.rc != 0`).
- **`block`** — group tasks with shared `when`/`become` and add `rescue`/`always` for error handling.
- **Collections** — the modern packaging unit; roles increasingly ship inside collections installed from Galaxy or a private Automation Hub.
- **Molecule** — test roles in throwaway containers before shipping them.

---

## Assignment

1. **Parameterize the role.** Add a `defaults/main.yml` variable `page_title` and use it in the template. Override it per host with `host_vars/web1.yml` so web1 and web2 show different titles — prove it with two `curl`s.
2. **Add a config handler chain.** Extend the role to deploy a custom nginx site config from a template; notify a handler that runs `nginx -t` (validate) *and* restarts. Show that editing the template triggers the handler and an unchanged run does not.
3. **Reuse community work.** Install `geerlingguy.nginx` from Galaxy, read its `defaults/main.yml`, and write one paragraph on how its structure compares to the role you built.

---

## Further Reading

**Watch**

- 📺 Jeff Geerling's **Ansible 101** — [Ep 5 · Handlers, vars & env](https://youtu.be/HU-dkXBCPdU) · [Ep 6 · Vault & Roles](https://youtu.be/JFweg2dUvqM) · [Ep 7 · Molecule, Linting & Galaxy](https://youtu.be/FaXVZ60o8L8)
- 📺 [Ansible Full Course · Zero to Hero](https://youtu.be/GROqwFFLl3s) (Rahul Wagh, ~3.5 hr) — comprehensive, chaptered course covering variables → templates → roles → Galaxy and more

**Reference**

- [Ansible — Using Variables](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_variables.html)
- [Ansible — Roles](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_reuse_roles.html)
- [Jinja2 templating](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_templating.html)
- [Ansible Galaxy](https://galaxy.ansible.com) · [Jeff Geerling's roles](https://galaxy.ansible.com/geerlingguy) — production-grade examples
