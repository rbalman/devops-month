# Week 3 — IaC & Cloud

This week **Operation: Go Live goes to the cloud** — you'll configure servers with code, run them on AWS, and make the whole thing reproducible. The loop: **configure (Ansible) → run on real cloud (AWS) → codify (Terraform)**.

**Ansible** — configuration as code:

- [Day 1 · Ansible I — Fundamentals & First Playbook](day-15.md) — why config management, agentless/push architecture, idempotency, inventory, ad-hoc commands, and your first playbook against a Vagrant fleet.
- [Day 2 · Ansible II — Variables, Facts, Templates & Roles](day-16.md) — variables & precedence, facts, Jinja2 templates, handlers, loops/conditionals, roles, and Ansible Galaxy.

**AWS** — the cloud primitives, by hand:

- [Day 3 · AWS I — Identity & Compute (IAM + EC2)](day-17.md) — regions/AZs, IAM users/groups/roles/policies, EC2, key pairs, security groups, AMIs — then run your Ansible playbook against a real EC2 host.
- [Day 4 · AWS II — Networking, Load Balancing & Storage](day-18.md) — VPC/subnets/route tables, public vs private, an Application Load Balancer across AZs, Auto Scaling, and S3.
- [Day 5 · AWS III — Serverless (Lambda, SQS, SNS, CloudWatch)](day-19.md) — event-driven architecture: an S3 → Lambda → SNS pipeline, queues, pub/sub, logs, and scheduled events.

**Terraform** — infrastructure as code:

- [Day 6 · Terraform I — Providers, Resources & Core Workflow](day-20.md) — declarative IaC, providers, resources, state, `init/plan/apply/destroy`, variables, outputs, locals, and data sources.
- [Day 7 · Terraform II — Modules, Backends & Capstone](day-21.md) — functions, `for_each`, reusable modules, a remote S3 backend with locking, and an end-to-end capstone tying Terraform + Ansible together.

!!! warning "Mind the meter"
    This week creates real AWS resources. Everything is designed to fit the **Free Tier**, but load balancers, NAT gateways, and idle IPs cost money — **every AWS lab ends with a teardown checklist. Run it.**
