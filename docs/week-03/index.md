# Week 3 — IaC & Cloud

This week **Operation: Go Live goes to the cloud** — you'll configure servers with code, run them on AWS, and make the whole thing reproducible. The loop: **configure (Ansible) → run on real cloud (AWS) → codify (Terraform)**.

**Ansible** — configuration as code:

- [Day 1 · Ansible I — Fundamentals & First Playbook](day-15.md) — why config management, agentless/push architecture, idempotency, inventory, ad-hoc commands, and your first playbook against a Vagrant fleet.
- [Day 2 · Ansible II — Variables, Facts, Templates & Roles](day-16.md) — variables & precedence, facts, Jinja2 templates, handlers, loops/conditionals, roles, and Ansible Galaxy.

**AWS** — the cloud primitives, by hand:

- [Day 3 · AWS I — Cloud Foundations & the Console](day-17.md) — IaaS/PaaS/SaaS, major providers, AWS history & market, regions/AZs, and navigating the Management Console; create an account and set a billing alarm.
- [Day 4 · AWS II — Launch an EC2 Machine + IAM](day-18.md) — IAM users/groups/roles/policies, then launch an EC2 instance (AMI, instance type, key pair, security group, VPC) and point yesterday's Ansible playbook at it.
- [Day 5 · AWS III — VPC, Route 53, ALB & TLS](day-19.md) — build a VPC, delegate a domain to Route 53, load-balance across AZs with an ALB, and serve HTTPS with an ACM certificate — Go Live, for real.

**Terraform** — infrastructure as code:

- [Day 6 · Terraform I — IaC, HCL & Core Workflow](day-20.md) — what IaC is, Terraform vs OpenTofu, Terraform vs Ansible, HCL, architecture, variables/locals/resources/data/outputs, and `init/plan/apply/destroy`.
- [Day 7 · Terraform II — State, Backends & Modules](day-21.md) — the state file & drift, best practices for managing state, a modern remote S3 backend with native locking (`use_lockfile`, no DynamoDB), Terraform modules, and building a reusable VPC module.

!!! warning "Mind the meter"
    This week creates real AWS resources. Everything is designed to fit the **Free Tier**, but load balancers, NAT gateways, and idle IPs cost money — **every AWS lab ends with a teardown checklist. Run it.**
