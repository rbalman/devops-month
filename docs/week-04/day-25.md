# Day 4 · Ansible in CI/CD — Automating Configuration with GitHub Actions

> Yesterday you ran Terraform from a pipeline. Today it's **Ansible's** turn. Configuration drifts just like infrastructure — someone SSHes in, tweaks nginx, forgets. Running your playbooks from CI means every config change is **reviewed, linted, dry-run, and applied by a machine** — never by hand on a box nobody else knows about. As with yesterday, we keep the example tiny: one playbook against one server, so the focus stays on the *automation pattern*.

!!! info "Where this fits"
    Day 3 automated Terraform in CI; today automates Ansible. That completes the toolkit — lint/test/build, image publish, IaC, config management, all in GitHub Actions. Day 5 combines them into a git-driven, end-to-end deploy.

## Learning Objectives

- Explain why configuration management belongs in CI, and the gates that make it safe
- Use **`ansible-lint`**, **`--syntax-check`**, and **`--check`** (dry run) as pipeline stages
- Supply an **SSH key** and **Vault password** to a workflow from GitHub secrets
- Apply a playbook on merge, and rely on **idempotency** as a safety net
- **Lab:** a minimal playbook run by GitHub Actions against an EC2 host

---

## Prerequisites

- **Week 3 complete** — Ansible basics, inventory, roles (Days 15–16)
- An **EC2 instance** you can SSH into (from Day 2/3, or launch a fresh `t3.micro`) with its **private key**
- Day 1's `sample-app` repo

---

## Theory · ~30 min

### 1. Why run Ansible in CI

The same argument as Terraform, applied to configuration:

| Manual `ansible-playbook` | Pipeline |
|---|---|
| Run from someone's laptop, ad-hoc | Clean runner, pinned collections, reproducible |
| No review of what changed | Every change is a reviewed **PR** |
| Vault password / SSH key on laptops | Injected from **encrypted secrets** at run time |
| "Did anyone run it on all hosts?" | The pipeline runs it, every time, on the full inventory |

### 2. The Ansible pipeline — gates before you touch a server

Ansible has its own cheap-to-expensive gates, mirroring lint→test→apply:

```text
  PR ──▶ ansible-lint ──▶ --syntax-check ──▶ --check (dry run) ──▶ review
                                                                     │
  merge to main ──────────────────────────────────────────▶ ansible-playbook (apply)
```

| Stage | Catches |
|---|---|
| **`ansible-lint`** | Bad practices, deprecated modules, style |
| **`--syntax-check`** | YAML/playbook structure errors — before connecting anywhere |
| **`--check`** (dry run) | *Would-be* changes, with `--diff` to show them — the "plan" of Ansible |
| **apply** | The real change, on merge |

`--check` is Ansible's answer to `terraform plan`: it reports what **would** change without changing it — so a PR can show the intended effect.

### 3. Secrets: SSH key + Vault password

A CI run needs two secrets to configure a real host:

- The **SSH private key** to reach the host — stored as a repo secret, written to a file at run time.
- The **Ansible Vault password** to decrypt any vaulted vars — stored as a secret, passed via `--vault-password-file`.

Neither ever lives in the repo. The runner is ephemeral, so they exist only for the seconds the job runs.

!!! warning "Reaching the host from a hosted runner"
    GitHub-hosted runners have **dynamic IPs**, so the target's security group must allow SSH from anywhere (`0.0.0.0/0` on 22) with **key-only** auth — acceptable for a lab, not ideal for production. Real setups use a **self-hosted runner inside the VPC**, a **bastion**, or **SSM**. We note it now and use it properly on Day 5.

### 4. Idempotency is your CI safety net

Because playbooks are **idempotent** (Week 3), re-running one is safe — the second apply changes nothing. That's what makes automated config safe to run on every merge: applying an unchanged playbook is a no-op, so the pipeline can run freely without fear of "doing it twice."

---

## Lab · ~45 min

Run a small playbook against an EC2 host from GitHub Actions: lint + syntax + dry-run on PRs, apply on merge.

### 1. The playbook

In your repo, make an `ansible/` folder. **`ansible/playbook.yml`** — install nginx and drop a page (deliberately simple):

```yaml
- hosts: web
  become: true
  tasks:
    - name: Install nginx
      ansible.builtin.apt:
        name: nginx
        state: present
        update_cache: true

    - name: Deploy the landing page
      ansible.builtin.copy:
        content: "Configured by GitHub Actions + Ansible\n"
        dest: /var/www/html/index.html
        mode: "0644"
      notify: reload nginx

  handlers:
    - name: reload nginx
      ansible.builtin.service:
        name: nginx
        state: reloaded
```

**`ansible/inventory.ini`** — your one host (public IP of the EC2):

```ini
[web]
<ec2-public-ip>

[web:vars]
ansible_user=ubuntu
```

### 2. Store the secrets

Repo → **Settings → Secrets and variables → Actions**:

| Secret | Value |
|---|---|
| `SSH_PRIVATE_KEY` | full contents of your `.pem` |

(No Vault secret needed for this simple playbook — you'll add one on Day 5.)

### 3. The workflow

**`.github/workflows/ansible.yml`**:

```yaml
name: Ansible

on:
  pull_request:
    paths: ["ansible/**"]
  push:
    branches: [main]
    paths: ["ansible/**"]

jobs:
  ansible:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: ansible
    steps:
      - uses: actions/checkout@v7

      - uses: actions/setup-python@v6
        with:
          python-version: "3.12"

      - name: Install Ansible + lint
        run: pip install ansible ansible-lint

      - name: Lint
        run: ansible-lint playbook.yml

      - name: Syntax check
        run: ansible-playbook --syntax-check -i inventory.ini playbook.yml

      - name: Set up SSH key
        run: |
          mkdir -p ~/.ssh
          echo "${{ secrets.SSH_PRIVATE_KEY }}" > ~/.ssh/id_rsa
          chmod 600 ~/.ssh/id_rsa

      - name: Dry run (on PRs)
        if: github.event_name == 'pull_request'
        run: ansible-playbook -i inventory.ini playbook.yml --check --diff
        env:
          ANSIBLE_HOST_KEY_CHECKING: "False"

      - name: Apply (on merge to main)
        if: github.ref == 'refs/heads/main' && github.event_name == 'push'
        run: ansible-playbook -i inventory.ini playbook.yml
        env:
          ANSIBLE_HOST_KEY_CHECKING: "False"
```

### 4. Run the cycle

1. Open a **PR**. Watch `ansible-lint` → `--syntax-check` → `--check --diff` run; the dry-run's `--diff` shows the file it *would* write.
2. **Merge.** The apply step runs the playbook for real. Visit `http://<ec2-public-ip>` — your page is live.
3. Change the page text on a branch, open a PR — the dry run shows the diff. Merge to apply it.

### 5. See idempotency in CI

Re-run the apply (re-run the workflow, or push an empty change). The playbook reports **ok**, not **changed** — nothing to do. That's why running config on every merge is safe.

!!! success "What you just built"
    A reviewed, linted, dry-run-then-applied Ansible pipeline. You've now automated all four building blocks — **test, image, Terraform, Ansible**. Day 5 assembles them into the end-to-end project under GitOps.

---

## Advanced Topics

- **Molecule** — test roles in throwaway containers as a CI gate → [Molecule](https://ansible.readthedocs.io/projects/molecule/)
- **Self-hosted runners in the VPC** — reach private hosts without opening SSH to the world → [Self-hosted runners](https://docs.github.com/en/actions/how-tos/manage-runners/self-hosted-runners)
- **`--check --diff` limits** — some modules can't predict changes; know where dry-run is blind → [Check mode](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_checkmode.html)
- **Dynamic inventory in CI** — query AWS by tag instead of hard-coding IPs → [`amazon.aws.aws_ec2`](https://docs.ansible.com/ansible/latest/collections/amazon/aws/aws_ec2_inventory.html)

---

## Assignment

Harden the Ansible pipeline.

**Part 1 — Vaulted secret + password from CI.** Add a **vaulted** variable (e.g. a message string or a fake token) with `ansible-vault`, use it in the playbook, and pass the **vault password from a GitHub secret** via `--vault-password-file`. Confirm the workflow decrypts and applies it without the password ever appearing in the repo or logs.

**Part 2 — Fail the PR on drift.** Make the **`--check`** step run on PRs with `--diff` and treat *any* would-be change as a signal: using `--check`, a PR that expects "no changes" should come back clean. Manually change the file on the server (`echo hacked > /var/www/html/index.html`), then run a check-mode job and show it **reports the drift** it would revert.

**Submit:** your `ansible.yml`, the vaulted file (encrypted — safe to commit), a screenshot of the dry-run `--diff` on a PR, and the check-mode run that detected your manual drift.

!!! danger "Don't leave the box running"
    If this EC2 is only for the lab, **stop or terminate it** when done.

---

## Further Reading

**Watch**

- 📺 [Ansible in CI/CD pipelines](https://youtu.be/1id6ERvfozo) — linting, check mode, and automated runs

**Reference**

- [`ansible-lint`](https://ansible.readthedocs.io/projects/lint/) · [Check mode (`--check`)](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_checkmode.html)
- [Ansible Vault](https://docs.ansible.com/ansible/latest/vault_guide/index.html) · [`actions/setup-python`](https://github.com/actions/setup-python)
- [Using secrets in GitHub Actions](https://docs.github.com/en/actions/how-tos/security-for-github-actions/security-guides/using-secrets-in-github-actions)
