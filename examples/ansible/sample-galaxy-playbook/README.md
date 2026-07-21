# Sample Ansible Project (Galaxy role)

Serves a minimal static page using a **community role from Ansible Galaxy** —
[`geerlingguy.nginx`](https://github.com/geerlingguy/ansible-role-nginx) —
instead of writing the nginx tasks yourself.

This is the third variant of the same goal, so you can compare approaches:

| Sample | How nginx gets configured |
|---|---|
| [`sample-playbook`](../sample-playbook) | your own tasks, one flat playbook |
| [`sample-role-playbook`](../sample-role-playbook) | your own tasks, packaged as a role |
| **`sample-galaxy-playbook`** (this one) | a **community role** pulled from Galaxy |

## Structure

```
sample-galaxy-playbook/
├── ansible.cfg
├── inventory.ini
├── requirements.yml     # declares the geerlingguy.nginx dependency
├── site.yml             # applies the Galaxy role + deploys the page
└── files/
    └── index.html       # the minimal static page to serve
```

## How it works

- `requirements.yml` lists `geerlingguy.nginx` as a dependency.
- `site.yml` configures the role through its variables (`nginx_vhosts`) — the
  role itself owns *installing* and *configuring* nginx.
- `nginx_remove_default_vhost: true` deletes the vhost the Ubuntu nginx package
  ships (`/etc/nginx/sites-enabled/default`). Without it, that file and our vhost
  both claim `default_server` on port 80 and nginx refuses to start
  (`duplicate default server for 0.0.0.0:80`).
- A `post_tasks` step copies `files/index.html` into the web root the vhost serves.

> You may see a `INJECT_FACTS_AS_VARS` deprecation **warning** during the run —
> it comes from inside the `geerlingguy.nginx` role, not this project, and is
> harmless. It'll go away when the role updates upstream.

## Run it

From the [Day 1 fleet](../../../docs/week-03/day-15.md) (control node driving
`web1` + `web2`), copy this folder onto the control node and:

```bash
cd sample-galaxy-playbook

# 1) Pull the community role from Galaxy (installs to ~/.ansible/roles)
ansible-galaxy install -r requirements.yml

# 2) Check, then run
ansible-playbook site.yml --syntax-check
ansible-playbook site.yml

# 3) Verify
curl http://192.168.56.30
curl http://192.168.56.31
```

> `ansible-playbook` won't find `geerlingguy.nginx` until you've run the
> `ansible-galaxy install` step — the role isn't vendored into this repo, only
> *declared* in `requirements.yml`.
