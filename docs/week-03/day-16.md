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

## Theory · ~35 min

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

### 6. Play order — `pre_tasks`, `roles`, `tasks`, `post_tasks`

A play doesn't just run top to bottom — Ansible runs its sections in a **fixed order**, no matter how you arrange them in the file:

```
pre_tasks  →  roles  →  tasks  →  post_tasks
```

So plain `tasks:` always run *after* your roles (covered later). When you need a step to happen **before** a role (e.g. refresh the apt cache) or guaranteed **after** everything (e.g. a smoke test), reach for `pre_tasks:` and `post_tasks:`.

**See it for yourself** — a tiny playbook that just prints from each section:

```yaml
# order-demo.yml — run:  ansible-playbook order-demo.yml
- name: Show the order sections run in
  hosts: localhost
  gather_facts: false

  pre_tasks:
    - name: pre
      ansible.builtin.debug:
        msg: "1) pre_tasks"

  roles:
    - demo            # a role whose task prints "2) role"

  tasks:
    - name: main
      ansible.builtin.debug:
        msg: "3) tasks"

  post_tasks:
    - name: post
      ansible.builtin.debug:
        msg: "4) post_tasks"
```

```yaml
# roles/demo/tasks/main.yml
- name: role
  ansible.builtin.debug:
    msg: "2) role"
```

No matter that `roles:` is written above `tasks:`, the output always comes out in order:

```
TASK [pre] ......... "1) pre_tasks"
TASK [demo : role] . "2) role"
TASK [main] ........ "3) tasks"
TASK [post] ........ "4) post_tasks"
```

!!! note "Where handlers fit"
    **Handlers** don't follow this line — a notified handler runs at the **end of the section that notified it** (after `pre_tasks`, after `roles`+`tasks`, after `post_tasks`), not wherever it's defined. Force them to run early with the `meta` task `- ansible.builtin.meta: flush_handlers`.

### 7. Filters — transforming a value

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

### 8. Jinja2 templates

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

### 9. Roles — the unit of reuse

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

### 10. Ansible Galaxy

You don't have to write every role yourself. **[Ansible Galaxy](https://galaxy.ansible.com)** is the public registry of community-maintained **roles** — think **npm for JavaScript** or **Docker Hub for images**, but for Ansible. The `ansible-galaxy` CLI both **scaffolds** your own roles and **installs** other people's:

```bash
ansible-galaxy role init webserver               # scaffold an empty role skeleton (your own)
ansible-galaxy role install geerlingguy.nginx    # download a community role
```

For a real project you pin dependencies in a **`requirements.yml`** and install them all at once — the reproducible way, instead of ad-hoc `install` commands:

```yaml
# requirements.yml
roles:
  - name: geerlingguy.nginx
```

```bash
ansible-galaxy install -r requirements.yml
```

!!! note "📖 Reference — installing content"
    See [**Installing content from Galaxy**](https://docs.ansible.com/ansible/latest/galaxy/user_guide.html) for `requirements.yml` and version pinning. Browse [**geerlingguy's roles**](https://github.com/geerlingguy?tab=repositories&q=ansible-role) — Jeff Geerling's are the community gold standard and worth reading as examples.

!!! example "📂 Sample — host a page with a Galaxy role"
    [`examples/ansible/sample-galaxy-playbook/`](https://github.com/rbalman/devops-month/tree/main/examples/ansible/sample-galaxy-playbook) uses the community [`geerlingguy.nginx`](https://github.com/geerlingguy/ansible-role-nginx) role (declared in `requirements.yml`) to install and configure nginx, then serves a minimal static page — no hand-written nginx tasks at all. Grab it with:

    ```bash
    git clone https://github.com/rbalman/devops-month.git
    cp -r devops-month/examples/ansible/sample-galaxy-playbook ~/fleet-galaxy-sample
    ```

---

## Lab · ~50 min

Each lab is a **small, self-contained playbook** that puts one theory section into practice — a hands-on refresher, in the same order as the theory. Run everything **inside the control node**, in `~/fleet` (from Day 1). They accumulate into a real project as you go.

```bash
cd ~/fleet
```

### Lab 1 — Variables & facts (Theory 2 & 3)

Define a group variable, then reference it alongside a **fact** with `debug`.

```bash
mkdir -p group_vars
cat > group_vars/web.yml << 'EOF'
site_name: "Operation Go Live"
worker_processes: 2
EOF

cat > vars.yml << 'EOF'
- hosts: web
  tasks:
    - name: Show a variable and a fact
      ansible.builtin.debug:
        msg: "{{ site_name }} on {{ inventory_hostname }} ({{ ansible_facts['distribution'] }})"
EOF

ansible-playbook vars.yml
ansible-playbook vars.yml -e "site_name=Staging"   # --extra-vars wins over group_vars
```

### Lab 2 — Filters (Theory 7)

Reshape a value with the pipe. Runs on `localhost` — no server needed.

```bash
cat > filters.yml << 'EOF'
- hosts: localhost
  gather_facts: false
  vars:
    name: "operation go live"
  tasks:
    - name: Apply a couple of filters
      ansible.builtin.debug:
        msg: "{{ name | upper }} — {{ name | length }} chars — {{ missing | default('fallback') }}"
EOF

ansible-playbook filters.yml
```

### Lab 3 — Conditions & loops (Theory 5)

Install a list of packages with one looping task, guarded by a `when`.

```bash
cat > tools.yml << 'EOF'
- hosts: web
  become: true
  tasks:
    - name: Install base tools
      ansible.builtin.apt:
        name: "{{ item }}"
        state: present
        update_cache: true
      loop:
        - htop
        - git
      when: ansible_facts['os_family'] == "Debian"
EOF

ansible-playbook tools.yml
```

### Lab 4 — Play order (Theory 6)

Prove the `pre_tasks → tasks → post_tasks` sequence with `debug`. On `localhost`.

```bash
cat > order.yml << 'EOF'
- hosts: localhost
  gather_facts: false
  post_tasks:
    - name: post
      ansible.builtin.debug:
        msg: "3) post_tasks"
  pre_tasks:
    - name: pre
      ansible.builtin.debug:
        msg: "1) pre_tasks"
  tasks:
    - name: main
      ansible.builtin.debug:
        msg: "2) tasks"
EOF

ansible-playbook order.yml     # prints 1 → 2 → 3, despite post_tasks being written first
```

### Lab 5 — Template + handler (Theory 4 & 8)

Render a fact-aware page and restart nginx **only when the file changes**.

```bash
mkdir -p templates
cat > templates/index.html.j2 << 'EOF'
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><title>{{ site_name }}</title></head>
<body>
  <h1>{{ site_name }}</h1>
  <p>Served by {{ inventory_hostname }} ({{ ansible_facts['default_ipv4']['address'] }})</p>
  <p>OS: {{ ansible_facts['distribution'] }} {{ ansible_facts['distribution_version'] }} - {{ ansible_facts['processor_vcpus'] }} vCPU</p>
</body>
</html>
EOF

cat > web.yml << 'EOF'
- hosts: web
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
curl http://192.168.56.30        # per-host IP / OS / vCPU in the output
```

Run it **again** — the template is `ok` (no change), so the handler does **not** fire (`changed=0`). Edit the template, re-run, and watch it restart nginx *only* because the file changed.

### Lab 6 — Package it into a role (Theory 1 & 9)

Scaffold a role and move the logic in. The playbook shrinks to three lines.

```bash
ansible-galaxy role init roles/webserver
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

cat > site.yml << 'EOF'
- hosts: web
  become: true
  roles:
    - webserver
EOF

ansible-playbook site.yml        # same result — now packaged and reusable
```

### Lab 7 — Install a role from Galaxy (Theory 10)

Declare a community role in `requirements.yml` and install it.

```bash
cat > requirements.yml << 'EOF'
roles:
  - name: geerlingguy.ntp
EOF

ansible-galaxy install -r requirements.yml
ansible-galaxy role list          # see what's installed
```

Browse [geerlingguy's roles](https://github.com/geerlingguy?tab=repositories&q=ansible-role) — the community gold standard, worth reading as examples.

```bash
exit
# vagrant halt    # keep the fleet; you're done with Ansible after today
```

---

## Advanced Topics

- [Re-using files (`import_*` / `include_*`)](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_reuse.html)
- [Ansible Vault](https://docs.ansible.com/ansible/latest/vault_guide/index.html)
- [Blocks & error handling](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_blocks.html)
- [Tags](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_tags.html)
- [Collections](https://docs.ansible.com/ansible/latest/collections_guide/index.html)
- [Molecule (role testing)](https://ansible.readthedocs.io/projects/molecule/)

---

## Assignment

Write a playbook that uses a **community Galaxy role to install Docker**, then runs an **nginx container** serving a custom page.

**Steps:**

1. Install [`geerlingguy.docker`](https://galaxy.ansible.com/ui/standalone/roles/geerlingguy/docker/documentation/) — declare it in a `requirements.yml` and `ansible-galaxy install -r requirements.yml`.
2. Write a playbook targeting the `web` group that:
   - applies the `geerlingguy.docker` role to install Docker,
   - deploys `index.html` **from a Jinja2 template** (`index.html.j2`) that renders the message *plus the host's uptime at deploy time* — e.g.
     **`Hello World from Ansible!!!. Last Uptime: up 13 hours, 50 minutes.`** — where the uptime is read from the target host during the run (not hard-coded),
   - runs an **nginx container**, mapping container port 80 to host **port 8080**, with your page mounted as the site root.
3. Verify: `curl http://192.168.56.30:8080` returns your `Hello World from Ansible!!!. Last Uptime: …` page with the real host uptime (repeat for `192.168.56.31`). **Re-run the playbook** and confirm the uptime reflects the host each deploy.

**Hint — the uptime:** capture it from the target host with a task, then reference the registered variable in `index.html.j2`:

```yaml
- name: Read host uptime
  ansible.builtin.command: uptime -p      # → "up 13 hours, 50 minutes"
  register: host_uptime
  changed_when: false
```

```jinja
Hello World from Ansible!!!. Last Uptime: {{ host_uptime.stdout }}.
```

**Hint — the container:** once Docker is installed, run it with the `community.docker.docker_container` module:

```yaml
- name: Run nginx in a container
  community.docker.docker_container:
    name: hello-nginx
    image: nginx:latest
    state: started
    ports:
      - "8080:80"
    volumes:
      - "/opt/site:/usr/share/nginx/html:ro"
```

---

## Further Reading

**Watch**

- 📺 Jeff Geerling's **Ansible 101** — [Ep 5 · Handlers, vars & env](https://youtu.be/HU-dkXBCPdU) · [Ep 6 · Vault & Roles](https://youtu.be/JFweg2dUvqM) · [Ep 7 · Molecule, Linting & Galaxy](https://youtu.be/FaXVZ60o8L8)
- 📺 [Ansible Full Course · Zero to Hero](https://youtu.be/GROqwFFLl3s) (Rahul Wagh, ~3.5 hr) — comprehensive, chaptered course covering variables → templates → roles → Galaxy and more

**Reference**

- [Ansible — Using Variables](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_variables.html) · [Special Variables](https://docs.ansible.com/projects/ansible/latest/reference_appendices/special_variables.html)
- [Conditionals](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_conditionals.html) · [Loops](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_loops.html) · [Handlers](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_handlers.html)
- [Playbook filters](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_filters.html) · [Jinja2 templating](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_templating.html)
- [Ansible — Roles](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_reuse_roles.html) (incl. `pre_tasks`/`post_tasks` ordering)
- [Ansible Galaxy user guide](https://docs.ansible.com/ansible/latest/galaxy/user_guide.html) · [Jeff Geerling's roles](https://github.com/geerlingguy?tab=repositories&q=ansible-role) — production-grade examples
