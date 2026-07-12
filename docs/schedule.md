# 30-Day Schedule

Each session is **1–1.5 hours** of focused work: ~20 min theory + ~50 min hands-on lab + take-home assignment.

---

## Week 1 — Linux System Administration

| Day | Topic | Key Skills |
|---|---|---|
| [Day 01](week-01/day-01.md) | DevOps Intro & Machine Setup | What is DevOps, install tools, set up environment |
| [Day 02](week-01/day-02.md) | Filesystem, Files & Text | History, FHS, navigation, file manipulation, `grep`/`sed`/`awk`, pipes |
| [Day 03](week-01/day-03.md) | Process & Disk Management | `ps`/`top`/`kill`, signals, `df`/`du`/`lsblk`, load average |
| [Day 04](week-01/day-04.md) | Users, Groups & Permissions | Users/groups, `chmod`/`chown`, `rwx`, basic networking checks |
| [Day 05](week-01/day-05.md) | The Shell | Shell types, ~/.bashrc config, env vars, exit codes, aliases, functions |
| [Day 06](week-01/day-06.md) | Shell Scripting I — Fundamentals | Scripts, variables, quoting, input, arithmetic, command substitution, exit codes |
| [Day 07](week-01/day-07.md) | Shell Scripting II — Logic, Loops & Reuse | `set -euo pipefail`, `if`/`case`, loops, `while read`, arguments, functions, debugging, cron |

*See also: [Beyond the Basics](week-01/beyond-the-basics.md) — a reference map of Linux topics, config files, and commands we don't cover in class.*

## Week 2 — Networking & Containers

*Spine: **Operation Go Live** — everything builds toward a containerized app served behind Nginx, over HTTPS, on your own domain.*

| Day | Topic | Key Skills |
|---|---|---|
| [Day 08](week-02/day-08.md) | Networking I — Addressing & the Tools to See It | IPv4, classes, CIDR/subnets, private nets & NAT, ports, TCP/UDP; `ip`/`ss`/`netstat`/`ping`/`traceroute`/`nc`/`tcpdump` |
| [Day 09](week-02/day-09.md) | Networking II — DNS & Mail | Resolution chain, `dig`, record types, `/etc/hosts` & resolv.conf, TTL; MX/SPF/DKIM/DMARC, SMTP by hand |
| [Day 10](week-02/day-10.md) | Networking III — SSH, Tunnels & Firewalls | SSH keys, `~/.ssh/config`, `scp`/`rsync`, server hardening, port-forward tunnels, `ufw`, VPN concepts |
| [Day 11](week-02/day-11.md) | Networking IV — Nginx, Reverse Proxy & TLS | HTTP basics, static assets, virtual hosts, reverse proxy, load balancing, self-signed HTTPS |

!!! info "Containers (Days 12–14) — coming soon"
    Docker basics, building images, and Docker Compose round out the week. Content in progress.

## Week 3 — IaC & Cloud

!!! info "Coming soon"
    The content for this week is still being prepared.

## Week 4 — CI/CD & Monitoring

!!! info "Coming soon"
    The content for this week is still being prepared.

---

!!! tip "Pace yourself"
    Each day builds on the previous. If you fall behind, catch up the same day — don't carry debt into the next session.
