# Week 2 — Networking & Containers

This week is **Operation: Go Live** — everything builds toward a containerized app served behind Nginx, over HTTPS, on your own domain.

**Networking** — reach and serve machines:

- [Day 1 · Networking I — Addressing & the Tools to See It](day-08.md) — IPv4, CIDR/subnets, private networks & NAT, ports, TCP/UDP; and the tools to *see* it all (`ss`, `ping`, `traceroute`, `nc`, `tcpdump`).
- [Day 2 · Networking II — DNS & Mail](day-09.md) — how names resolve, `dig`, record types, and the DNS behind email (MX/SPF/DKIM/DMARC).
- [Day 3 · Networking III — SSH & Firewalls](day-10.md) — key-based login, `~/.ssh/config`, `scp`/`rsync`, hardening, `ufw`, VPNs, and bastion hosts.
- [Day 4 · Networking IV — Nginx, Reverse Proxy & TLS](day-11.md) — serve static assets, turn on self-signed HTTPS, shape access logs, reverse-proxy a Python API, and load-balance backends.

**Containers** — package the app and ship the whole stack:

- [Day 5 · Containers I — Docker Basics](day-12.md) — images vs containers, the runtime and registries, the container lifecycle, and data with volumes & networks.
- [Day 6 · Containers II — Building Images & Registries](day-13.md) — write a Dockerfile, master layers & the build cache, shrink images with multi-stage builds, then tag and push to a registry.
- [Day 7 · Containers III — Docker Compose, Volumes & Networks](day-14.md) — declare the full `nginx + app + postgres` stack in one file, with persistent volumes, isolated networks, healthchecks, and scaling.
