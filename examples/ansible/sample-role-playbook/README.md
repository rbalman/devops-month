# Sample Ansible Project (role-based)

The **same web-server setup** as [`../sample-playbook`](../sample-playbook), but
packaged into a reusable **role**. Compare the two side by side to see exactly
what "turning a playbook into a role" means:

- In the flat sample, `site.yml` holds every task, handler, and `templates/`.
- Here, `site.yml` is three lines — it just calls the `webserver` role, and all
  the logic moves under `roles/webserver/` in Ansible's conventional layout.

## Structure

```
sample-role-playbook/
├── ansible.cfg
├── inventory.ini
├── site.yml                     # tiny — just applies the webserver role
├── group_vars/
│   └── web.yml
├── host_vars/
│   ├── web1.yml
│   └── web2.yml
└── roles/
    └── webserver/
        ├── tasks/main.yml       # base tooling, deploy user, nginx + site config
        ├── handlers/main.yml    # validate → reload, and restart
        ├── templates/
        │   ├── index.html.j2
        │   └── nginx-site.conf.j2
        ├── defaults/main.yml    # lowest-precedence fallbacks
        ├── vars/main.yml        # role-internal constants (web_root)
        └── meta/main.yml        # role metadata (author, platforms, deps)
```

## Why a role?

- **Reuse** — point the role at any inventory; the same `roles: [webserver]`
  works for one host or a hundred.
- **Convention** — `tasks/`, `handlers/`, `templates/`, `defaults/`, `vars/` are
  discovered automatically, so `site.yml` stays trivial.
- **Shareable** — a role is the unit you publish to (or install from)
  **Ansible Galaxy**.

## Scaffolding a role

The empty skeleton for a role is generated with:

```bash
ansible-galaxy role init roles/webserver
```

(This project already contains a filled-in one.)

## Run it

From the [Day 1 fleet](../../../docs/week-03/day-15.md) (control node driving
`web1` + `web2`), copy this folder onto the control node and:

```bash
cd sample-role-playbook
ansible-playbook site.yml --syntax-check   # parse-only: catch errors first
ansible-playbook site.yml

curl http://192.168.56.30
curl http://192.168.56.31
```

Behaviour is identical to the flat sample — web1 and web2 show different
`page_title`s (from `host_vars`), and the handlers fire only on change.
