# DevOps Month

> A hands-on, 30-day remote DevOps course — taught by [Balman Rawat](https://balmanrawat.com.np)

Welcome. This is not a lecture series. Every session is built around doing things — spinning up servers, writing scripts, deploying apps, debugging real issues. The theory is here to support the practice, not the other way around.

By the end of this course, you will have:

- Better knowledge around the DevOps technology landspace
- Basic knowledge on Cloud
- Deployed a containerized application through a CI/CD pipeline
- Set up monitoring and log aggregation with Prometheus, Loki, and Grafana
- Basic alerts to send alerts in a team communication channel.

That is the full picture of what a DevOps engineer does on the job, compressed into 30 days.

---

## Who This Is For

- Computer Science, Engineering, or IT students (final year preferred)
- Recent graduates looking for their first DevOps/SRE/infrastructure role
- Anyone who already knows some programming, networking basics, and Git

---

## What You Need

| Requirement | Minimum | Recommended |
|---|---|---|
| RAM | 8 GB | 16 GB |
| Free Disk | 256 GB | 512 GB |
| Internet | Stable | Stable |

Software you'll need before Day 1:

- A terminal (Linux, macOS, or WSL2 on Windows)
- [Git](https://git-scm.com/)
- [VS Code](https://code.visualstudio.com/) or any editor you're comfortable with
- A [GitHub](https://github.com) account
- [VirtualBox](https://www.virtualbox.org/) or [VMware](https://www.vmware.com/) (for Vagrant labs)

## The End Goal

```
Your Code (GitHub Repo)
    │
    ▼
GitHub Actions (CI/CD)
    │  ─ build Docker image
    │  ─ run tests
    │  ─ push to registry
    ▼
AWS EC2 Server
    │  ─ pull & run container
    │  ─ Nginx reverse proxy
    ▼
Prometheus + Loki + Grafana
    │  ─ collect metrics & logs
    │  ─ trigger alerts
    ▼
Discord / Slack Notification
```

---

## Get Started

1. Read the [Schedule](schedule.md) to understand the 30-day plan
2. Start with [Day 1](week-01/day-01.md)

Questions? Open a [GitHub Issue](https://github.com/rbalman/devops-month/issues) or ask in Discord.
