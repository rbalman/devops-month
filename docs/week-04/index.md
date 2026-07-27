# Week 4 — CI/CD & Monitoring

The final week — **Ship It, Watch It, Secure It**. You'll take an **end-to-end project** (frontend · backend · Postgres) all the way to a **self-deploying, monitored, secured** system: automate the build and release with **GitHub Actions**, provision it with **Terraform** and configure it with **Ansible**, tie it together under **GitOps**, instrument it with **Prometheus, Loki, and Grafana** (alerting to Discord), and harden it with **security best practices**.

**CI/CD with GitHub Actions — one skill per day:**

- [Day 1 · CI/CD Fundamentals & First Pipeline](day-22.md) — CI vs delivery vs deployment, pipeline stages & gates, GitHub Actions anatomy, triggers, and a first lint→test→build workflow.
- [Day 2 · GitHub Actions II — Build, Push & Deploy](day-23.md) — variables & secrets, expressions & functions, step/job outputs, conditions, and connecting to AWS (OIDC + CLI); build an image, push it, and deploy.
- [Day 3 · Terraform in CI/CD](day-24.md) — OIDC keyless AWS auth and running `plan`/`apply` from a pipeline, on a small standalone config.
- [Day 4 · Ansible in CI/CD](day-25.md) — lint, syntax-check, and dry-run gates, secrets from CI, and applying config on merge.

**Bring it together — the end-to-end project (the capstone):**

- [Day 5 · GitOps & the End-to-End Project](day-26.md) — GitOps principles, then the whole app in one repo: frontend + backend + Postgres, a Terraform-provisioned EC2, and Ansible deploying all three as containers — driven by git.

**Operate it:**

- [Day 6 · Monitoring & Alerting](day-27.md) — Prometheus, Loki, and Grafana (via Alloy) for metrics, logs, dashboards, and alerts to Discord.
- [Day 7 · Security Best Practices](day-28.md) — DevSecOps: secrets, least-privilege, network hardening, image + IaC scanning, supply-chain safety; plus course wrap-up and what comes next.

!!! warning "Mind the meter"
    These labs stand up real AWS resources — an EC2 instance for the project, and more in the optional exercises — all billable beyond the free tier. **Every AWS lab ends with a teardown. Run it**, and destroy the capstone once you've captured your screenshots.
