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

### 1. The project structure

Day 1 left you with a flat `~/fleet` — an `ansible.cfg`, an `inventory.ini`, and a playbook or two side by side. That works until you add variables, templates, and reusable logic. Ansible has a **conventional directory layout** that it discovers *automatically*: put files in the right place and it wires them up with no extra configuration. Everything you build today lands somewhere in this tree:

```
fleet/
├── ansible.cfg              # project config (Day 1)
├── inventory.ini            # hosts & groups (Day 1)
├── group_vars/
│   └── web.yml              # variables for every host in the 'web' group
├── host_vars/
│   └── web1.yml             # variables for a single host
├── templates/
│   └── index.html.j2        # Jinja2 files rendered per host
├── site.yml                 # the top-level playbook
└── roles/
    └── webserver/           # a self-contained, reusable unit
        ├── tasks/main.yml
        ├── handlers/main.yml
        ├── templates/
        ├── defaults/main.yml
        └── vars/main.yml
```

The magic is **convention over configuration**: name a directory `group_vars/web.yml` and every host in the `web` group picks up those variables with zero wiring. Drop a role under `roles/webserver/` and a playbook can call it by name. You'll create each of these directories as you go today — but knowing the shape up front tells you *where* each new concept belongs.

!!! note "📖 Reference — the canonical layout"
    Ansible's own [**Sample Ansible setup**](https://docs.ansible.com/projects/ansible/latest/tips_tricks/sample_setup.html) documents this directory hierarchy in full — including how to organize multiple environments (production/staging) with separate inventories.

There's **no built-in command that scaffolds the project layout** — you have two ways to get started:

**Option A — build it yourself.** Create the directories by hand as each section calls for them (recommended for learning):

```bash
cd ~/fleet
mkdir -p group_vars host_vars templates   # ansible.cfg + inventory.ini already exist from Day 1
```

**Option B — clone the finished sample.** A complete, runnable version of everything you build today lives in this repo at [`examples/ansible/sample-playbook/`](https://github.com/rbalman/devops-month/tree/main/examples/ansible/sample-playbook) — inventory, `group_vars`/`host_vars`, templates, and a single flat playbook:

```bash
git clone https://github.com/rbalman/devops-month.git
cp -r devops-month/examples/ansible/sample-playbook ~/fleet-sample
```

Use it as a reference (or a starting point) if you get stuck.

Whichever path you take, once a playbook exists you can **parse-check** it without touching a single host — the fastest way to catch a YAML or structure error:

```bash
ansible-playbook site.yml --syntax-check
```

### 2. Variables — and where they live

A **variable** is a named value you reference with `{{ mustache }}` syntax. They can be defined in many places; the ones you'll use most:

When the same variable is set in two places, the one with the **higher precedence number wins**:

| Precedence | Location | Scope |
|---|---|---|
| 1 (lowest) | role `defaults/main.yml` | a role's built-in fallback |
| 2 | `vars:` in a play | just that play |
| 3 | `group_vars/<group>.yml` | every host in a group |
| 4 | `host_vars/<host>.yml` | one host |
| 5 (highest) | `--extra-vars` (`-e`) on the CLI | overrides almost everything |

**a) In a play with `vars:`** — quick and local to that play:

```yaml
- hosts: web
  vars:
    site_name: "Operation Go Live"
    worker_processes: 2
  tasks:
    - name: Show a variable
      ansible.builtin.debug:
        msg: "Deploying {{ site_name }} with {{ worker_processes }} workers"
```

**b) In `group_vars/` and `host_vars/`** — the same variable set per group or per host, picked up automatically by name:

```yaml
# group_vars/web.yml — applies to every host in the 'web' group
site_name: "Operation Go Live"
worker_processes: 2
```

```yaml
# host_vars/web1.yml — applies to web1 only (overrides the group value)
worker_processes: 4
```

**c) On the command line with `--extra-vars`** (`-e`) — highest precedence, great for one-off overrides:

```bash
ansible-playbook site.yml -e "worker_processes=8"
ansible-playbook site.yml -e '{"site_name": "Staging", "worker_processes": 1}'   # JSON for structured values
ansible-playbook site.yml -e "@overrides.yml"                                     # or load from a file
```

**d) Referencing variables** — anywhere Ansible renders Jinja: task args, `msg`, templates, even other variables. Always quote a value that *starts* with `{{ }}`:

```yaml
- ansible.builtin.debug:
    msg: "{{ site_name }} runs on {{ ansible_facts['distribution'] }}"   # a fact
- ansible.builtin.debug:
    msg: "First package is {{ base_packages[0] }}"                       # list index
- ansible.builtin.service:
    name: "{{ service_name }}"                                          # quoted: value starts with {{
```

!!! note "📖 Reference — special variables"
    Some variables are set by Ansible itself, not you — `inventory_hostname`, `ansible_facts`, `groups`, `hostvars`, `play_hosts`, and more. The [**Special Variables**](https://docs.ansible.com/projects/ansible/latest/reference_appendices/special_variables.html) appendix is the full list of these built-in "magic" variables and connection settings.

### 3. Facts — what Ansible knows about a host

Before running tasks, Ansible **gathers facts** — hostname, IP addresses, OS, CPU count, memory, and hundreds more. Reference them from the `ansible_facts` dictionary:

```yaml
- debug:
    msg: "{{ inventory_hostname }} runs {{ ansible_facts['distribution'] }} {{ ansible_facts['distribution_version'] }}"
```

See them all with `ansible web1 -m setup`. Facts let one playbook adapt to each machine (e.g. size a config by `ansible_facts['processor_vcpus']`).

!!! warning "Use `ansible_facts['name']`, not `ansible_name`"
    You'll see older content reference facts as top-level variables with an `ansible_` prefix (`ansible_distribution`, `ansible_os_family`). That auto-injection is **deprecated** and is being removed in ansible-core 2.24 — always read facts from the **`ansible_facts`** dictionary (`ansible_facts['distribution']`), which has no prefix on the key.

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

### 5. Conditions and loops

A **conditional** (`when:`) decides whether a task runs; a **loop** runs one task many times. Together they keep a playbook short and adaptive.

**Conditionals** — the expression is plain Jinja, so no `{{ }}`:

```yaml
- name: Only on Debian-family hosts
  ansible.builtin.debug:
    msg: "Debian-family host"
  when: ansible_facts['os_family'] == "Debian"

# Combine tests — a list is an implicit AND
- name: Restart only if service is present and enabled
  ansible.builtin.service: name=nginx state=restarted
  when:
    - "'nginx' in ansible_facts['packages']"
    - ansible_facts['os_family'] == "Debian"

# OR, negation, and numeric comparison
- name: Warn on small boxes
  ansible.builtin.debug:
    msg: "Low memory"
  when: ansible_facts['memtotal_mb'] < 1024 or ansible_facts['processor_vcpus'] == 1
```

**`register` + `when`** — capture a task's result and branch on it:

```yaml
- name: Check if the app is deployed
  ansible.builtin.command: test -f /opt/app/current
  register: app_check
  ignore_errors: true          # don't abort the play on non-zero exit

- name: Deploy only when missing
  ansible.builtin.debug:
    msg: "Deploying for the first time"
  when: app_check.rc != 0
```

**Loops** come in several shapes:

```yaml
# 1) A simple list
- name: Install several packages
  ansible.builtin.apt:
    name: "{{ item }}"
    state: present
  loop:
    - nginx
    - curl
    - git

# 2) A list of dicts — reference sub-keys with item.<key>
- name: Create app users
  ansible.builtin.user:
    name: "{{ item.name }}"
    groups: "{{ item.group }}"
  loop:
    - { name: deploy, group: www-data }
    - { name: ci,     group: docker }

# 3) A list of dicts with a per-item condition
- name: Open only the enabled ports
  ansible.builtin.debug:
    msg: "opening {{ item.port }}"
  loop:
    - { port: 22,   enabled: true }
    - { port: 80,   enabled: true }
    - { port: 8080, enabled: false }
  when: item.enabled

# 4) Retry until a condition holds (polling)
- name: Wait for the port to come up
  ansible.builtin.command: nc -z localhost 80
  register: port_check
  until: port_check.rc == 0
  retries: 5
  delay: 3
```

> Note: `with_items`, `with_dict`, etc. are the **older** loop syntax you'll still see in the wild — `loop:` is the modern replacement.

### 6. Filters — transforming a value

You don't always want a variable *as-is*. A **filter** transforms it, using the pipe (`|`) — the same idea as a Unix pipe: `{{ value | filter }}`. A few you'll meet constantly:

```yaml
{{ site_name | upper }}                 # uppercase → "OPERATION GO LIVE"
{{ port | default(80) }}                # fall back to 80 if 'port' is undefined
{{ base_packages | length }}            # how many items in the list
{{ path | basename }}                   # "/etc/nginx/nginx.conf" → "nginx.conf"
{{ some_dict | to_nice_json }}          # pretty-print a structure
```

Filters can be chained left-to-right (`{{ name | trim | lower }}`). You'll use them most inside **templates** (next section) to format the values you drop into config files.

!!! tip "Just a heads-up for now"
    Don't memorize filters today — just recognize the `|` when you see it. Ansible ships dozens (plus all of Jinja2's), listed in [**Playbook filters**](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_filters.html). Reach for one when you need to reshape a value; look it up then.

### 7. Jinja2 templates

A **template** is a file with `{{ variables }}` and logic that Ansible renders per host with the `template` module. This is how you generate real config files:

```jinja
# nginx.conf.j2
worker_processes {{ worker_processes }};
server {
    server_name {{ inventory_hostname }};
    # rendered on {{ ansible_facts['distribution'] }}
}
```

Templates support **filters** (`{{ name | upper }}`, `{{ port | default(80) }}`), **conditionals** (`{% if %}`), and **loops** (`{% for %}`).

!!! note "📖 Reference — Jinja2 templating"
    Ansible's [**Templating (Jinja2)**](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_templating.html) guide covers how templates are rendered in playbooks; the [**Jinja2 template designer docs**](https://jinja.palletsprojects.com/en/stable/templates/) are the full language reference for `{% if %}`, `{% for %}`, and the built-in filters.

### 8. Roles — the unit of reuse

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

!!! example "📂 See it both ways"
    The repo has the **same nginx setup written twice** so you can compare: a flat playbook in [`examples/ansible/sample-playbook/`](https://github.com/rbalman/devops-month/tree/main/examples/ansible/sample-playbook) and the role-based version in [`examples/ansible/sample-role-playbook/`](https://github.com/rbalman/devops-month/tree/main/examples/ansible/sample-role-playbook). Diff them to see exactly what "packaging into a role" moves where.

Grab the role-based sample to run or study locally:

```bash
git clone https://github.com/rbalman/devops-month.git
cp -r devops-month/examples/ansible/sample-role-playbook ~/fleet-role-sample
```

!!! tip "📺 Watch — *Ansible 101 · Ep 6 — Vault & Roles* (Jeff Geerling, ~1 hr)"
    The definitive walkthrough of roles — from the author of the community roles you're installing. Jump to what maps to today:

    [![Ansible 101 — Vault & Roles](https://img.youtube.com/vi/JFweg2dUvqM/hqdefault.jpg){ width="360" }](https://youtu.be/JFweg2dUvqM)

    **Chapters:** [conditionals & tags](https://youtu.be/JFweg2dUvqM?t=1293) · [playbook organization](https://youtu.be/JFweg2dUvqM?t=1646) · [roles](https://youtu.be/JFweg2dUvqM?t=2766) · [flexible role usage](https://youtu.be/JFweg2dUvqM?t=3150) · [Ansible Vault](https://youtu.be/JFweg2dUvqM?t=651)

### 9. Ansible Galaxy

You don't have to write every role yourself. **[Ansible Galaxy](https://galaxy.ansible.com)** is the public registry of community-maintained automation — think **npm for JavaScript** or **Docker Hub for images**, but for Ansible content. The `ansible-galaxy` CLI is how you interact with it. It ships two kinds of content:

- **Roles** — a single reusable role (like the `webserver` role above).
- **Collections** — the modern bundle: many roles *plus* modules and plugins, namespaced as `namespace.name` (e.g. `community.postgresql`).

The same CLI both **scaffolds** your own content and **installs** other people's:

```bash
ansible-galaxy role init webserver               # scaffold an empty role skeleton (your own)
ansible-galaxy role install geerlingguy.nginx    # download a community role
ansible-galaxy collection install community.postgresql
```

For a real project you pin dependencies in a **`requirements.yml`** and install them all at once — the reproducible way, instead of ad-hoc `install` commands:

```yaml
# requirements.yml
roles:
  - name: geerlingguy.nginx
collections:
  - name: community.postgresql
```

```bash
ansible-galaxy install -r requirements.yml
```

!!! note "📖 Reference — installing content"
    See [**Installing content from Galaxy**](https://docs.ansible.com/ansible/latest/galaxy/user_guide.html) for roles vs collections, `requirements.yml`, and version pinning. Browse [**geerlingguy's roles**](https://galaxy.ansible.com/ui/standalone/namespaces/geerlingguy/) — Jeff Geerling's are the community gold standard and worth reading as examples.

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
<p>Served by {{ inventory_hostname }} ({{ ansible_facts['default_ipv4']['address'] }})</p>
<p>OS: {{ ansible_facts['distribution'] }} {{ ansible_facts['distribution_version'] }} — {{ ansible_facts['processor_vcpus'] }} vCPU</p>
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
