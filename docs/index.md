# DevOps Month

> A hands-on, 30-day remote DevOps course — taught by [Balman Rawat](https://balmanrawat.com.np)

Welcome. This is not a lecture series. Every session is built around doing things — spinning up servers, writing scripts, deploying apps, debugging real issues. The theory is here to support the practice, not the other way around.

By the end of this course, you will have:

- Provisioned a cloud server on AWS
- Deployed a containerized application through a CI/CD pipeline
- Set up monitoring and log aggregation with Prometheus, Loki, and Grafana
- Sent real alerts to a communication channel

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

---

## Course Rules

!!! warning "Attendance"
    Missing more than **5 sessions** means you cannot continue the course.

!!! info "Assignments"
    Complete each day's assignment **before** the next session. If you're stuck, ask early — in Discord or as a GitHub Issue. Don't skip it silently.

!!! tip "Mindset"
    This is a **50-50 partnership**. Content and guidance comes from the instructor. Effort and consistency comes from you. Both are required.

---

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

1. Fork this repository to your GitHub account
2. Read the [Schedule](schedule.md) to understand the 30-day plan
3. Start with [Day 1](week-01/day-01.md)

Questions? Open a [GitHub Issue](https://github.com/rbalman/devops-month/issues) or ask in Discord.
