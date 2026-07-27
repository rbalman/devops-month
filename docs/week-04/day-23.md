# Day 2 · GitHub Actions II — Build, Push & Deploy

> A CI pipeline that stops at **green tests** is only half the story. The **CD** half takes the tested code, **builds a Docker image**, **pushes it to a registry**, and **deploys it to a server**. Along the way you'll meet the three things every real deployment pipeline needs: **secrets** (so you're not pasting passwords into YAML), a **registry** (a home for your images), and **OIDC** (so your pipeline talks to AWS with *no long-lived keys at all*).

!!! info "Where this fits"
    A basic CI workflow (lint → test → build) is covered in [CI/CD Fundamentals & First Pipeline](day-22.md). This extends the same `sample-app` repo into **build → push → deploy** — pushing to `main` ships a new container image and restarts the app on a server, hands-off.

## Learning Objectives

- Store credentials safely with **repository secrets** and gate deploys behind **environments**
- Build a Docker image in CI and **push it to a registry** (GHCR)
- Understand **OIDC** and why it replaces long-lived AWS access keys in pipelines
- Speed up and scale workflows with **caching**, **matrix**, and **reusable workflows**
- **Lab:** build the API image, push it to GHCR, then **deploy it to an EC2 host over SSH**

---

## Prerequisites

- **Day 1 complete** — the `sample-app` repo with a passing CI workflow
- An **EC2 instance** you can SSH into (Week 3, Day 4) — Ubuntu 24.04, Docker installed, port 22 open to you and 80 open to the world
- The instance's **SSH private key** and its **public IP/DNS**

---

## Theory · ~30 min

### 1. Secrets — never hard-code credentials

A pipeline that deploys needs credentials: a registry token, an SSH key, a database password. **Never** put these in the YAML — it's in git, visible to anyone with read access. Instead, store them as **encrypted secrets** (repo → **Settings → Secrets and variables → Actions**) and read them at run time:

```yaml
steps:
  - run: echo "Deploying with $SSH_KEY"
    env:
      SSH_KEY: ${{ secrets.EC2_SSH_KEY }}   # injected from encrypted storage
```

| Where secrets live | Scope |
|---|---|
| **Repository secrets** | One repo's workflows |
| **Environment secrets** | Only jobs targeting that environment (e.g. `production`) — can add approval gates |
| **Organization secrets** | Shared across many repos |

!!! warning "Secrets are masked, not invisible"
    GitHub masks secret values in logs (they show as `***`), but a malicious workflow step *could* still exfiltrate them. Only run trusted actions, and pin third-party actions to a commit SHA in security-sensitive repos.

### 2. Environments — a gate for deploys

An **environment** (repo → **Settings → Environments**) is a named deploy target (`staging`, `production`) that can carry its own secrets and **protection rules** — most usefully a **required reviewer** so a human must approve before the deploy job runs. This is exactly the "click to release" line between continuous *delivery* and *deployment* from Day 1.

```yaml
jobs:
  deploy:
    environment: production      # uses production's secrets + approval gate
    runs-on: ubuntu-latest
    steps: ...
```

### 3. Registries — where images live

A minimal CI "build" might produce a throwaway tarball. A real build produces a **Docker image** and pushes it to a **container registry** so any server can pull it. You have choices:

| Registry | Address | Notes |
|---|---|---|
| **GHCR** — GitHub Container Registry | `ghcr.io/<owner>/<image>` | Built into GitHub; auth via the automatic `GITHUB_TOKEN` — **used in the lab below** |
| **Amazon ECR** | `<acct>.dkr.ecr.<region>.amazonaws.com/<repo>` | Native to AWS; best when deploying to ECS/EKS |
| **Docker Hub** | `docker.io/<user>/<image>` | Ubiquitous; rate-limited on the free tier |

GHCR wins for this course because it needs **no extra credentials** — GitHub hands each workflow a scoped `GITHUB_TOKEN` that can push to your own repo's registry.

### 4. OIDC — deploy to AWS with no stored keys

To deploy to AWS the old way, you'd store an **access key + secret** as repo secrets. Those are long-lived — leak them and an attacker has your account until you notice. **OIDC (OpenID Connect)** removes them entirely:

```text
GitHub Actions ──(1) here's a signed token proving "I'm repo X, branch main")──▶ AWS
      ▲                                                                          │
      └──────────(2) here's a 15-minute credential scoped to one role───────────┘
```

You create an **IAM role** once, tell AWS to **trust tokens from your repo**, and the pipeline exchanges a short-lived GitHub token for **temporary** AWS credentials each run. Nothing long-lived is ever stored.

!!! tip "OIDC vs SSH — two deploy styles"
    The lab below deploys by **SSH** (simple, works anywhere, uses an SSH key secret). OIDC shines when the pipeline calls **AWS APIs** — pushing to ECR, running `terraform apply`, updating an ECS service. Setting up OIDC to run Terraform against AWS is covered in [Terraform in CI/CD](day-24.md). The block looks like:

    ```yaml
    permissions:
      id-token: write        # let the job request an OIDC token
      contents: read
    steps:
      - uses: aws-actions/configure-aws-credentials@v6
        with:
          role-to-assume: arn:aws:iam::<acct>:role/github-actions
          aws-region: us-east-1
    ```

### 5. Three scaling tools, briefly

You'll reach for these as pipelines grow — know they exist:

- **Caching** — `actions/setup-node`'s `cache: npm` (Day 1) and Docker layer caching (`cache-from`/`cache-to`) skip repeating unchanged work, cutting minutes off each run.
- **Matrix** — run one job many times across a grid of inputs (Node 20/22/24, Linux/Windows) without copy-paste.
- **Reusable workflows** — factor a common pipeline into a file other repos `uses:`, so ten services share one deploy definition. DRY, for CI.

---

## Lab · ~45 min

Turn `sample-app`'s CI into full CI/CD: **build** the API into a Docker image, **push** it to GHCR, then **deploy** it to your EC2 host over SSH — all on push to `main`.

### 1. Containerize the API

Add a **`api/Dockerfile`** (multi-stage-ready, but simple here):

```dockerfile
FROM node:24-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev          # production deps only
COPY . .
EXPOSE 3000
CMD ["node", "server.js"]
```

Add a **`api/.dockerignore`** so junk doesn't bloat the image:

```text
node_modules
npm-debug.log
```

Build and run it locally to confirm before automating:

```bash
cd api
docker build -t sample-api .
docker run --rm -p 3000:3000 sample-api
curl localhost:3000/healthz      # {"status":"ok"}
```

### 2. Add a build-and-push job

New workflow **`.github/workflows/deploy.yml`** — its first job builds the image and pushes it to **GHCR**. Note the `permissions` block: `packages: write` is what lets the automatic `GITHUB_TOKEN` push to the registry.

```yaml
name: Deploy

on:
  push:
    branches: [main]
  workflow_dispatch:

env:
  IMAGE: ghcr.io/${{ github.repository }}/api    # ghcr.io/<you>/sample-app/api

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write          # allow pushing to GHCR
    steps:
      - uses: actions/checkout@v7

      - name: Log in to GHCR
        uses: docker/login-action@v4
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}   # auto-provided, no setup needed

      - name: Set up Buildx
        uses: docker/setup-buildx-action@v4

      - name: Build and push
        uses: docker/build-push-action@v7
        with:
          context: ./api
          push: true
          tags: |
            ${{ env.IMAGE }}:latest
            ${{ env.IMAGE }}:${{ github.sha }}    # immutable tag per commit
          cache-from: type=gha
          cache-to: type=gha,mode=max             # cache layers between runs
```

Push to `main`, then check your repo's **Packages** (right sidebar) — your image is there, tagged `latest` and with the commit SHA.

!!! tip "Tag with the commit SHA"
    `:latest` is convenient but ambiguous — you can't tell *which* code is running. Pushing `:${{ github.sha }}` gives every build an **immutable** tag, so a deploy references exactly one commit and rollbacks are trivial.

### 3. Store the deploy secrets

The deploy job SSHes into EC2, so give the repo three secrets (**Settings → Secrets and variables → Actions → New repository secret**):

| Secret | Value |
|---|---|
| `EC2_HOST` | your instance's public IP or DNS |
| `EC2_USER` | `ubuntu` |
| `EC2_SSH_KEY` | the **full contents** of your `.pem` private key |

### 4. Add the deploy job

Append a second job that runs **only after** the image is pushed (`needs:`) and pulls-and-restarts the container on the server:

```yaml
  deploy:
    needs: build-and-push
    runs-on: ubuntu-latest
    environment: production        # optional: add a required reviewer here
    steps:
      - name: Deploy over SSH
        uses: appleboy/ssh-action@v1
        with:
          host: ${{ secrets.EC2_HOST }}
          username: ${{ secrets.EC2_USER }}
          key: ${{ secrets.EC2_SSH_KEY }}
          script: |
            echo "${{ secrets.GITHUB_TOKEN }}" | docker login ghcr.io -u ${{ github.actor }} --password-stdin
            docker pull ${{ env.IMAGE }}:${{ github.sha }}
            docker rm -f api || true
            docker run -d --name api --restart unless-stopped \
              -p 80:3000 ${{ env.IMAGE }}:${{ github.sha }}
```

!!! note "Make the image pullable"
    New GHCR packages are **private** by default. Either keep the `docker login` line above (the server authenticates), or set the package to **public** (package → Settings → Change visibility) to pull without auth. For a real deploy, prefer auth.

### 5. Ship it

```bash
git add .
git commit -m "Add build-push-deploy pipeline"
git push
```

Watch the **Actions** tab: `build-and-push` runs, then `deploy` runs after it. When both are green, hit your instance:

```bash
curl http://<EC2_HOST>/healthz      # {"status":"ok"} — served by the freshly deployed container
```

Change the `/` route's text in `api/app.js`, push, and watch a new image build and redeploy within a minute or two — **that's continuous deployment**.

!!! success "What you just built"
    Push to `main` → tested → image built → pushed to GHCR → pulled and restarted on EC2, no human touching the server. Automating **Terraform** and **Ansible** in CI — and combining them to provision and deploy the end-to-end project — is covered in the [Terraform](day-24.md), [Ansible](day-25.md), and [GitOps](day-26.md) days.

---

## Advanced Topics

- **OIDC to AWS in depth** — the IAM role + trust policy, then `configure-aws-credentials@v6` → [Configuring OpenID Connect in AWS](https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- **Push to Amazon ECR** — `aws-actions/amazon-ecr-login` instead of GHCR → [amazon-ecr-login](https://github.com/aws-actions/amazon-ecr-login)
- **Reusable workflows** — one deploy definition, many repos → [Reusing workflows](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows)
- **Environments & approvals** — required reviewers, wait timers, deployment branches → [Using environments for deployment](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/manage-environments)
- **Pin actions to a SHA** — supply-chain hardening for third-party actions → [Security hardening](https://docs.github.com/en/actions/security-for-github-actions/security-guides/security-hardening-for-github-actions#using-third-party-actions)

---

## Assignment

Harden and extend the deploy pipeline.

**Part 1 — Gate production behind a review.** Configure the `production` **environment** with a **required reviewer** (yourself). Push a change and confirm the `deploy` job **waits** for your approval before running, then approve it and watch it finish. Screenshot the pending-approval state.

**Part 2 — Deploy a specific version, not just `latest`.** Add a **`workflow_dispatch`** input called `image_tag` (default `latest`) and make the deploy job run whichever tag you type — so you can **redeploy an older commit** (a rollback) by pasting its SHA. Test it by deploying the *previous* commit's SHA and confirming the app reverts.

```yaml
on:
  workflow_dispatch:
    inputs:
      image_tag:
        description: "Image tag/SHA to deploy"
        default: "latest"
```

**Submit:** both workflow files, a screenshot of the approval gate, and a screenshot of the manual `workflow_dispatch` run that rolled back to a previous SHA.

!!! danger "Don't leave the instance running"
    If this EC2 host is only for the lab, **stop or terminate it** when done (Week 3 teardown habits) — a running instance bills even while idle.

---

## Further Reading

**Watch**

- 📺 [GitHub Actions — Build & Push Docker images](https://youtu.be/R8_veQiYBjI?t=900) — the CI-pipeline-with-Docker segment of the GitHub Actions walkthrough

**Reference**

- [Publishing images to GHCR](https://docs.github.com/en/actions/how-tos/package-your-software/publishing-and-installing-a-package-with-github-actions) · [About `GITHUB_TOKEN`](https://docs.github.com/en/actions/security-for-github-actions/security-guides/automatic-token-authentication)
- [`docker/build-push-action`](https://github.com/docker/build-push-action) · [`docker/login-action`](https://github.com/docker/login-action) · [`docker/setup-buildx-action`](https://github.com/docker/setup-buildx-action)
- [Encrypted secrets](https://docs.github.com/en/actions/how-tos/security-for-github-actions/security-guides/using-secrets-in-github-actions) · [Using environments](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/manage-environments)
- [`aws-actions/configure-aws-credentials`](https://github.com/aws-actions/configure-aws-credentials)
