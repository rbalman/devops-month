# Sample Ansible Project (non-role)

A complete, runnable version of the project built across **Week 3, Day 1 & Day 2**.
It configures the `web` group (the `web1` + `web2` Vagrant nodes) to serve a small
homepage with nginx — written as a **single, flat playbook** so you can read the
whole workflow top to bottom.

> A separate sample will show how to package this same logic into a reusable
> **role**. This one deliberately keeps everything in one playbook.

## Structure

```
sample-playbook/
├── ansible.cfg              # project config (inventory path)
├── inventory.ini            # hosts & groups: [web] web1, web2
├── site.yml                 # the whole playbook — tasks + handlers inline
├── group_vars/
│   └── web.yml              # variables for every host in the web group
├── host_vars/
│   ├── web1.yml             # per-host overrides for web1
│   └── web2.yml             # per-host overrides for web2
└── templates/
    ├── index.html.j2        # Jinja2 homepage using variables + facts
    └── nginx-site.conf.j2   # nginx server block, rendered per host
```

## Concepts it demonstrates

- **Variables & precedence** — `group_vars/` vs `host_vars/`
  (web1 and web2 show different `page_title`s from their `host_vars`).
- **Facts** — the template prints IP, OS, and vCPU count gathered per host.
- **Loop + conditional** — base packages installed via `loop:` guarded by `when:`.
- **More than nginx** — the playbook also creates a `deploy` user and deploys an
  nginx **server-block config**, so a task list looks like a real server build,
  not a one-liner.
- **Jinja2 templates** — both the homepage and the nginx site config.
- **Handler chain** — changing the site config notifies *Validate nginx config*
  (`nginx -t`), which in turn notifies *Reload nginx*; the homepage change
  triggers a *Restart nginx*.

## Run it

From the [Day 1 fleet](../../../docs/week-03/day-15.md) (control node driving
`web1` + `web2`), copy this folder onto the control node and:

```bash
cd sample-playbook
ansible-playbook site.yml --syntax-check   # parse-only: catch YAML/structure errors first
ansible-playbook site.yml

# then check each node — note the different titles / per-host facts
curl http://192.168.56.30
curl http://192.168.56.31
```

> `--syntax-check` parses the playbook without touching any host — the fastest
> way to catch an indentation or key error. Add `--check` for a dry run that
> reports what *would* change, and `ansible-lint site.yml` for best-practice hints.

Run it a second time: the template tasks report `ok` (no change), so the
handlers do **not** fire — idempotency in action.
