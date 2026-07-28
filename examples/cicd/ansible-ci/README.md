# Ansible in CI/CD — Sample Project

A complete, runnable version of the project used in **Week 4, Day 4** to run an Ansible
playbook from a GitHub Actions pipeline: **lint → syntax-check → dry-run** on pull
requests, **apply** on merge to `main`. The playbook is intentionally tiny — install
nginx and drop a landing page on one host — so the focus is the **automation pattern**.

> This is its **own repo/project** — it does not reuse the `sample-app` from Day 1.

## Structure

```
ansible-ci/
├── .github/
│   └── workflows/
│       └── ansible.yml      # lint → syntax-check → --check (PR) → apply (merge)
└── ansible/
    ├── playbook.yml         # install nginx + deploy an index.html (with a handler)
    └── inventory.ini        # one [web] host — set your EC2's public IP
```

## Before it will run

1. **A target host** — an EC2 (Ubuntu 24.04) you can SSH into. Put its public IP in
   `ansible/inventory.ini`, replacing `CHANGEME-ec2-public-ip`.
2. **SSH key secret** — add the instance's private key as the `SSH_PRIVATE_KEY` repo
   secret. (Because GitHub-hosted runners have dynamic IPs, the host's security group
   must allow SSH with key-only auth; a self-hosted runner / bastion / SSM is the
   production alternative.)

## Check it locally

The playbook lints and syntax-checks with no host needed:

```bash
cd ansible
ansible-playbook --syntax-check -i inventory.ini playbook.yml
ansible-lint playbook.yml        # clean
```

> Verified with `ansible-playbook --syntax-check` and `ansible-lint`.

## The pipeline

Copy this folder to a new repo's root; GitHub reads workflows from `.github/workflows/`
at the **repo root** (not from inside `examples/`), so the copy here is a reference.
Open a PR → lint/syntax/`--check --diff`; merge to `main` → the playbook applies.

See [Week 4, Day 4](../../../docs/week-04/day-25.md) for the full walkthrough.
