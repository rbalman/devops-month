# Week 2 — Networking & Containers

This week is **Operation: Go Live** — everything builds toward a containerized app served behind Nginx, over HTTPS, on your own domain.

The networking half is ready:

- [Day 08 · Networking I — Addressing & the Tools to See It](day-08.md) — IPv4, CIDR/subnets, private networks & NAT, ports, TCP/UDP; and the tools to *see* it all (`ss`, `ping`, `traceroute`, `nc`, `tcpdump`).
- [Day 09 · Networking II — DNS & Mail](day-09.md) — how names resolve, `dig`, record types, and the DNS behind email (MX/SPF/DKIM/DMARC).
- [Day 10 · Networking III — SSH, Tunnels & Firewalls](day-10.md) — key-based login, `~/.ssh/config`, `scp`/`rsync`, hardening, port-forward tunnels, `ufw`, and VPNs.
- [Day 11 · Networking IV — Nginx, Reverse Proxy & TLS](day-11.md) — serve static assets, reverse-proxy an app, load-balance backends, and turn on HTTPS.

!!! info "Containers (Days 12–14) — coming soon"
    Docker basics, building images, and Docker Compose round out the week. Content is in progress.
