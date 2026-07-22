# 30-Day Schedule

Each session is **1–1.5 hours** of focused work: ~20 min theory + ~50 min hands-on lab + take-home assignment.

---

## Week 1 — Linux System Administration

| Day | Topic | Key Skills |
|---|---|---|
| [Day 1](week-01/day-01.md) | DevOps Intro & Machine Setup | What is DevOps, install tools, set up environment |
| [Day 2](week-01/day-02.md) | Filesystem, Files & Text | History, FHS, navigation, file manipulation, `grep`/`sed`/`awk`, pipes |
| [Day 3](week-01/day-03.md) | Process & Disk Management | `ps`/`top`/`kill`, signals, `df`/`du`/`lsblk`, load average |
| [Day 4](week-01/day-04.md) | Users, Groups & Permissions | Users/groups, `chmod`/`chown`, `rwx`, basic networking checks |
| [Day 5](week-01/day-05.md) | The Shell | Shell types, ~/.bashrc config, env vars, exit codes, aliases, functions |
| [Day 6](week-01/day-06.md) | Shell Scripting I — Fundamentals | Scripts, variables, quoting, input, arithmetic, command substitution, exit codes |
| [Day 7](week-01/day-07.md) | Shell Scripting II — Logic, Loops & Reuse | `set -euo pipefail`, `if`/`case`, loops, `while read`, arguments, functions, debugging, cron |

*See also: [Beyond the Basics](week-01/beyond-the-basics.md) — a reference map of Linux topics, config files, and commands we don't cover in class.*

## Week 2 — Networking & Containers

*Spine: **Operation Go Live** — everything builds toward a containerized app served behind Nginx, over HTTPS, on your own domain.*

| Day | Topic | Key Skills |
|---|---|---|
| [Day 1](week-02/day-08.md) | Networking I — Addressing & the Tools to See It | IPv4, classes, CIDR/subnets, private nets & NAT, ports, TCP/UDP; `ip`/`ss`/`netstat`/`ping`/`traceroute`/`nc`/`tcpdump` |
| [Day 2](week-02/day-09.md) | Networking II — DNS & Mail | DNS hierarchy & resolution flow, `dig`, record types, `/etc/hosts` & resolv.conf, TTL; MX/SPF/DKIM/DMARC, real mail-server demo (GreenMail) |
| [Day 3](week-02/day-10.md) | Networking III — SSH & Firewalls | SSH keys, `~/.ssh/config`, `scp`/`rsync`, server hardening, `ufw`, VPNs & bastion hosts |
| [Day 4](week-02/day-11.md) | Networking IV — Nginx, Reverse Proxy & TLS | Static assets, virtual hosts, self-signed HTTPS, log formatting, reverse proxy, load balancing |
| [Day 5](week-02/day-12.md) | Containers I — Docker Basics | Images vs containers, Docker architecture, registries, lifecycle, volumes, container networking |
| [Day 6](week-02/day-13.md) | Containers II — Building Images & Registries | Dockerfile, layers & build cache, `CMD`/`ENTRYPOINT`, multi-stage builds, tagging, push/pull |
| [Day 7](week-02/day-14.md) | Containers III — Docker Compose, Volumes & Networks | Compose files, service DNS, named volumes, network isolation, healthchecks, scaling |

## Week 3 — IaC & Cloud

| Day | Topic | Key Skills |
|---|---|---|
| [Day 1](week-03/day-15.md) | Ansible I — Fundamentals & First Playbook | Why config management, agentless/push architecture, idempotency, inventory & groups, ad-hoc commands, plays/tasks/modules, `become`; Vagrant control + managed nodes |
| [Day 2](week-03/day-16.md) | Ansible II — Variables, Facts, Templates & Roles | Variables & precedence, facts, Jinja2 templates, handlers, loops/`when`, roles, Ansible Galaxy |
| [Day 3](week-03/day-17.md) | AWS I — Cloud Foundations & the Console | IaaS/PaaS/SaaS, major providers, AWS history & market share, regions/AZs, Management Console navigation, billing alarms |
| [Day 4](week-03/day-18.md) | AWS II — Launch an EC2 Machine + IAM | IAM users/groups/roles/policies, EC2 (AMI, instance type, key pair, security group, VPC), CLI, instance pricing; Ansible → EC2 |
| [Day 5](week-03/day-19.md) | AWS III — VPC, Route 53, ALB & TLS | Custom VPC/subnets/IGW/route tables, Route 53 hosted zone + domain, ALB + target groups, ACM/HTTPS; other AWS services |
| [Day 6](week-03/day-20.md) | Terraform I — IaC, HCL & Core Workflow | What IaC is & tools, Terraform/OpenTofu, Terraform vs Ansible, HCL, architecture, variables/locals/resources/data/outputs, `init`/`plan`/`apply`/`destroy` |
| [Day 7](week-03/day-21.md) | Terraform II — State, Backends & the Day 5 Stack | State file & drift, remote S3 backend, functions & expressions, loops (`count`/`for_each`/`for`), rebuild the Day 5 stack (EC2 + ALB + ACM + Route 53) in Terraform |

## Week 4 — CI/CD & Monitoring

!!! info "Coming soon"
    The content for this week is still being prepared.

---

!!! tip "Pace yourself"
    Each day builds on the previous. If you fall behind, catch up the same day — don't carry debt into the next session.
