# Day 5 · Deploy a Full-Stack AWS Project

> This week's CI/CD pieces come together into one project: a real three-tier app (frontend · backend · Postgres) on production-shaped AWS — **VPC, ALB with HTTPS, ECR, EC2** — provisioned by **Terraform**, deployed by **Ansible**, and driven from **GitHub Actions**. It's the capstone; keep it for your portfolio.

!!! danger "This builds real, billable AWS resources"
    Run the teardown in the project README when you're done.

## Do it

The complete, runnable project lives in the course repo. **Clone it and follow its `README` end to end:**

### [`examples/demo-app`](https://github.com/rbalman/devops-month/tree/main/examples/demo-app)

The README takes you through the one-time AWS setup, the GitHub variables + secrets, and the three deploy stages — **provision infra → build & push images → deploy the app** — all the way to the app live over HTTPS.

---

## Assignment

Deploy the demo-app's **`prod`** environment.
