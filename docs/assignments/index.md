# Assignments

Each day has a take-home assignment. These are meant to be completed before the next session — **not skipped**. If you're stuck, open a GitHub Issue or ask in Discord. Skipping silently is the only wrong approach.

---

## How to Submit

1. Create `my-progress/day-XX.md` in your fork of this repo
2. Write your answers, paste command output, and include any scripts
3. Commit and push to your fork
4. If your assignment includes scripts or config files, put them in `my-progress/` too

```bash
git add my-progress/
git commit -m "day-XX: assignment complete"
git push origin main
```

---

## Weekly Summary

### Week 1 — Foundation

| Day | Topic | Key Assignment |
|---|---|---|
| 01 | DevOps Intro | Describe DevOps in your own words; document your machine setup |
| 02 | Linux Basics I | Find SSH config, count /etc/passwd lines, search conf files |
| 03 | Linux Basics II | File permissions exercise, process count |
| 04 | Package Management | Custom systemd service, journalctl usage |
| 05 | Bash Scripting I | system_report.sh with conditionals and loops |
| 06 | Bash Scripting II | health_check.sh with functions, scheduled with cron |
| 07 | Git & GitHub | Branch, merge, push, open a pull request |

### Week 2 — Networking & Web

| Day | Topic | Key Assignment |
|---|---|---|
| 08 | Networking I | Traceroute analysis, port scan, TCP explanation |
| 09 | Networking II | SSH key to GitHub, DNS TTL, TLS cert inspection |
| 10 | Nginx | Serve second page, understand try_files |
| 11 | Apache & SSL | Self-signed cert, RewriteRule breakdown |
| 12 | Containers I | Alpine vs Ubuntu size, docker run behavior |
| 13 | Containers II | Add APP_ENV variable, extend Dockerfile |
| 14 | Docker Compose | Add Redis, healthcheck, Makefile |

### Week 3 — Infrastructure

| Day | Topic | Key Assignment |
|---|---|---|
| 15 | Vagrant | Custom Vagrantfile with nginx and forwarded port |
| 16 | Ansible | Ad-hoc commands to configure both nodes |
| 17 | Ansible Playbooks | database.yml with PostgreSQL, user, directory |
| 18 | Ansible Roles | roles/app — deploy Flask as a systemd service |
| 19 | Terraform I | Two nginx containers, understand destroy |
| 20 | Terraform II | Module with healthcheck_path variable |
| 21 | Mini Project | Full Terraform + Ansible + Makefile stack |

### Week 4 — Cloud, CI/CD & Monitoring

| Day | Topic | Key Assignment |
|---|---|---|
| 22 | AWS IAM & EC2 | Launch EC2, security group, SSH access |
| 23 | AWS VPC & S3 | Upload my-progress/ to S3, understand subnets |
| 24 | CI/CD I | Add multiply function, open PR, watch CI run |
| 25 | CI/CD II | Add Discord notification to deploy job |
| 26 | Prometheus | Add ERROR_COUNT metric, /error endpoint |
| 27 | Loki | Structured logs, LogQL queries |
| 28 | Grafana | 5-panel dashboard, Discord alert on memory |
| 29 | Final Project | Full pipeline live on EC2 |
| 30 | Job Prep | Career plan, GitHub portfolio polish |

---

!!! tip "When you're stuck"
    1. Re-read the day's theory section
    2. Read the error message carefully (the useful line is rarely the last one)
    3. Search the error + tool name
    4. Ask in Discord with: what you tried, the exact error, and what you expected

    **Ask early. Never sit stuck for more than 30 minutes without asking.**
