# Day 2 · GitHub Actions II — Build, Push & Deploy

> A first CI workflow runs a few commands and stops. Real pipelines need to **carry data** — a computed version tag, a build's result feeding a deploy — and to **talk to the outside world** with credentials, without leaking them. This covers the pieces that make that possible: **variables and secrets**, **expressions and functions**, passing **outputs** between steps and jobs, **conditions**, and **connecting to AWS** to run the **AWS CLI** — then puts them together to **build a Docker image, push it to Amazon ECR, and deploy the container to a server**.

!!! info "Where this fits"
    A basic CI workflow (lint → test → build) is covered in [CI/CD Fundamentals & First Pipeline](day-22.md). This adds the language features and credentials a real **build → push → deploy** pipeline needs.

## Learning Objectives

- Use **environment variables** and **configuration variables** vs **secrets**, at the right scope
- Write **expressions** (`${{ }}`) with **contexts** and built-in **functions**
- Pass data with **step outputs** and **job outputs**, and reference them downstream
- Gate work with **conditions** (`if:`)
- Authenticate to **AWS** from a workflow (keys via **secrets**, with **OIDC** as the best practice) and run the **AWS CLI**
- **Lab:** add a **Dockerfile** and a **workflow** that build the app's image and push it to **Amazon ECR** — using secrets, a variable, a step output, and AWS auth

---

## Prerequisites

- Day 1's `sample-app` repo with CI passing
- **Docker** installed locally
- An AWS account and an **IAM user with an access key** (or permission to create one)

---

## Theory · ~35 min

### 1. Environment variables

`env:` defines environment variables for `run:` steps. Set them at three **scopes** — workflow, job, or step — where the narrower scope wins:

```yaml
env:
  APP_ENV: production            # workflow scope — visible to every job/step

jobs:
  build:
    runs-on: ubuntu-latest
    env:
      LOG_LEVEL: debug           # job scope — this job's steps
    steps:
      - name: Show them
        env:
          GREETING: hello        # step scope — only this step
        run: echo "$GREETING in $APP_ENV at $LOG_LEVEL"
```

GitHub also injects **default** environment variables into every run:

| Variable | Value |
|---|---|
| `GITHUB_SHA` | the commit SHA that triggered the run |
| `GITHUB_REF` | the branch/tag ref (`refs/heads/main`) |
| `GITHUB_REPOSITORY` | `owner/repo` |
| `GITHUB_RUN_NUMBER` | an incrementing run count |
| `RUNNER_OS` | `Linux` / `Windows` / `macOS` |

The same data is available inside expressions via the `github` context (Section 5).

→ **Reference:** [Store information in variables](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/store-information-in-variables) · [Default environment variables](https://docs.github.com/en/actions/reference/workflows-and-actions/variables)

### 2. Variables vs secrets

Two ways to inject configuration, chosen by **sensitivity**. Both are set under **Settings → Secrets and variables → Actions**:

| | **Configuration variables** | **Secrets** |
|---|---|---|
| Reference | `${{ vars.NAME }}` | `${{ secrets.NAME }}` |
| Stored under | the **Variables** tab | the **Secrets** tab |
| Visible? | Yes, plain text | **Encrypted**, masked in logs as `***` |
| Use for | region, image name, non-sensitive config | passwords, tokens, keys |

```yaml
env:
  AWS_REGION: ${{ vars.AWS_REGION }}          # non-sensitive → a variable
steps:
  - run: ./deploy.sh
    env:
      API_TOKEN: ${{ secrets.API_TOKEN }}     # sensitive → a secret
```

!!! note "`env:` variables vs `vars` — not the same thing"
    - **`env:`** (Section 1) is defined **in the workflow file** and becomes a real **environment variable** on the runner — read it as `$NAME` in `run:` or `${{ env.NAME }}`. It's local to that workflow/job/step, and changing it means editing YAML.
    - **`vars`** are set in the **repo/org/environment settings UI**, shared across *all* your workflows, and changed without touching code. They are read **only** via `${{ vars.NAME }}` — they are *not* automatically environment variables. To use one as a shell env var, surface it into `env:` first, exactly as `AWS_REGION` does above.

Both `vars` and secrets come in **repository**, **environment**, and **organization** scopes. And every workflow automatically gets a **`GITHUB_TOKEN`** secret — a short-lived token scoped to the repo (used to push to GHCR, comment on PRs, etc.). Grant it least privilege with a `permissions:` block.

!!! warning "Secrets are masked, not bulletproof"
    GitHub masks secret values in logs, but a malicious step could still exfiltrate them. Only run trusted actions, and pin third-party actions to a commit SHA (see [Security Best Practices](day-28.md)).

→ **Reference:** [Configuration variables](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/store-information-in-variables) · [Using secrets](https://docs.github.com/en/actions/how-tos/security-for-github-actions/security-guides/using-secrets-in-github-actions) · [`GITHUB_TOKEN`](https://docs.github.com/en/actions/security-for-github-actions/security-guides/automatic-token-authentication)

### 3. Conditions — `if:`

An `if:` on a **job** or a **step** decides whether it runs. Inside `if:`, the `${{ }}` is optional:

```yaml
deploy:
  needs: build
  if: github.ref == 'refs/heads/main'        # only deploy from main
  runs-on: ubuntu-latest
  steps:
    - run: ./deploy.sh
    - name: Notify on failure
      if: failure()                          # only if an earlier step failed
      run: ./notify.sh
```

Common patterns: `if: github.event_name == 'pull_request'`, `if: github.ref == 'refs/heads/main'`, `if: contains(github.event.head_commit.message, '[deploy]')`, and status functions like `failure()`. What you write inside an `if:` is just an **expression**, built from **functions** (Section 4) and **contexts** (Section 5).

→ **Reference:** [`jobs.<job_id>.if`](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#jobsjob_idif)

### 4. Expressions & functions

Anything inside **`${{ }}`** is an **expression**, evaluated before the step runs. Expressions combine **contexts** (Section 5), operators (`==`, `!=`, `&&`, `||`, `!`), and built-in **functions**:

| Function | Does |
|---|---|
| `contains(a, b)` | `true` if `a` contains `b` |
| `startsWith(a, b)` · `endsWith(a, b)` | prefix / suffix test |
| `format('{0}-{1}', x, y)` | string templating |
| `hashFiles('**/package-lock.json')` | hash of matching files — a great cache key |
| `toJSON(x)` | dump a whole context (debugging) |

Plus **status functions** used in conditions (Section 3): `success()`, `failure()`, `cancelled()`, `always()`.

```yaml
- run: echo "building ${{ github.repository }} @ ${{ github.sha }}"
- run: echo "this is a tag build"
  if: startsWith(github.ref, 'refs/tags/')
```

→ **Reference:** [Expressions & functions](https://docs.github.com/en/actions/reference/workflows-and-actions/expressions)

### 5. Contexts

A **context** is an object of run data you read inside an expression with dot notation (`github.sha`). The ones you'll reach for most:

| Context | Holds |
|---|---|
| `github` | event data — `github.sha`, `github.ref`, `github.actor`, `github.repository` |
| `env` | your `env:` variables |
| `vars` / `secrets` | configuration variables / secrets |
| `steps` | outputs of earlier steps (Section 6) |
| `needs` | outputs of jobs this one depends on (Section 6) |
| `runner` | runner info (`runner.os`) |

→ **Reference:** [Contexts](https://docs.github.com/en/actions/reference/workflows-and-actions/contexts)

### 6. Passing data — step & job outputs

Steps and jobs are isolated, so values are passed **explicitly**.

**Step → step:** give a step an `id`, write `name=value` to the `$GITHUB_OUTPUT` file, then read it from the `steps` context:

```yaml
steps:
  - id: meta
    run: echo "tag=$(git rev-parse --short HEAD)" >> "$GITHUB_OUTPUT"
  - run: echo "image tag is ${{ steps.meta.outputs.tag }}"
```

**Job → job:** a job declares `outputs:` (pointing at a step output); a downstream job that `needs:` it reads `needs.<job>.outputs.<name>`:

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    outputs:
      tag: ${{ steps.meta.outputs.tag }}       # expose it to other jobs
    steps:
      - id: meta
        run: echo "tag=$(git rev-parse --short HEAD)" >> "$GITHUB_OUTPUT"

  deploy:
    needs: build                                # required to read its outputs
    runs-on: ubuntu-latest
    steps:
      - run: echo "deploying tag ${{ needs.build.outputs.tag }}"
```

→ **Reference:** [Pass information between jobs](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/pass-information-between-jobs) · [`jobs.<job_id>.outputs`](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#jobsjob_idoutputs)

### 7. Connecting to AWS & running the AWS CLI

To deploy to AWS, the pipeline needs credentials. The simplest way to see how it works: create an **IAM user**, give it an **access key** (an access key ID + a secret access key), store both as **GitHub secrets**, and hand them to `aws-actions/configure-aws-credentials` — which configures the **AWS CLI** (preinstalled on GitHub runners) for the rest of the job:

```yaml
steps:
  - uses: aws-actions/configure-aws-credentials@v6
    with:
      aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}          # read from GitHub secrets
      aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
      aws-region: ${{ vars.AWS_REGION }}
  - run: aws sts get-caller-identity                                # authenticated — "who am I?"
```

After that step, **every `aws` command in the job is authenticated**.

!!! danger "Never hard-code credentials — and prefer OIDC in production"
    Two rules that matter more than anything else here:

    1. **Never put an access key in the YAML** (or anywhere in git). Always reference it through `${{ secrets.* }}`, exactly as above — the workflow file never contains the actual key.
    2. Access keys are **long-lived** — if one leaks, it stays valid until you rotate it. The production best practice is **OIDC**: GitHub presents a short-lived, signed token and AWS exchanges it for **temporary** credentials, so **no keys are stored at all**. It's set up in [Terraform in CI/CD](day-24.md) — prefer it for anything real.

    Use access keys here to *learn the flow*; reach for OIDC in production.

→ **Reference:** [`aws-actions/configure-aws-credentials`](https://github.com/aws-actions/configure-aws-credentials) · [Configuring OIDC in AWS](https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)

---

## Lab · ~45 min

Extend your **`sample-app`** repo (from Day 1) to build the API into a Docker image and push it to **Amazon ECR**. You'll add a **Dockerfile** and a new **workflow file** — the workflow exercises the secrets, variable, step output, and AWS authentication from the theory.

### 1a. Add a Dockerfile

In the `sample-app` repo, add **`api/Dockerfile`**:

```dockerfile
FROM node:24-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev
COPY . .
EXPOSE 3000
CMD ["node", "server.js"]
```

Add **`api/.dockerignore`** (`node_modules`, `npm-debug.log`), then build it once locally to confirm it works:

```bash
cd api
docker build -t sample-api .
docker run --rm -p 3000:3000 sample-api &
curl localhost:3000/healthz      # {"status":"ok"}
```

### 1b. Create the ECR repository and AWS credentials

**Amazon ECR** (Elastic Container Registry) is AWS's private image registry. Create a repository for the image — console → ECR → *Create repository*, or the CLI:

```bash
aws ecr create-repository --repository-name sample-api --region us-east-1
```

Then, in the GitHub repo (**Settings → Secrets and variables → Actions**):

- **Variable** `AWS_REGION = us-east-1`.
- **Secrets** `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` — the access key of an IAM user allowed to push to ECR (stored as **secrets**, never in the YAML — see [Section 7](#7-connecting-to-aws-running-the-aws-cli)).

### 1c. Add the workflow

Add **`.github/workflows/ecr.yml`** — authenticate to AWS, log in to ECR, then build and push the image tagged with the commit SHA:

```yaml
name: Build and push to ECR

on:
  push:
    branches: [main]
  workflow_dispatch:

env:
  ECR_REPOSITORY: sample-api            # the ECR repo you created
  IMAGE_TAG: ${{ github.sha }}          # immutable tag — this commit

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7

      - name: Authenticate to AWS
        uses: aws-actions/configure-aws-credentials@v6
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}          # a secret
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ vars.AWS_REGION }}                           # a variable

      - name: Log in to Amazon ECR
        id: ecr
        uses: aws-actions/amazon-ecr-login@v2       # exposes the registry URL as an output

      - name: Build and push
        uses: docker/build-push-action@v7
        with:
          context: ./api
          push: true
          tags: ${{ steps.ecr.outputs.registry }}/${{ env.ECR_REPOSITORY }}:${{ env.IMAGE_TAG }}
```

Notice how the theory shows up: **secrets** for the keys, a **variable** for the region, **environment variables** for the repo name and tag, and the ECR login **step output** (`steps.ecr.outputs.registry`) — assembled inline in `tags:`.

### 1d. Push and verify

```bash
cd ~/sample-app
git add . && git commit -m "Build & push image to ECR" && git push
```

Open the **Actions** tab and watch the **Build and push to ECR** workflow run. When it's green, confirm the image landed:

```bash
aws ecr list-images --repository-name sample-api --region us-east-1
```

(or open the repository in the ECR console) — the image is there, tagged with your commit SHA.

!!! success "What you just built"
    A workflow that builds your app into a Docker image and publishes it to a private AWS registry — wired together with secrets, a variable, step outputs, and AWS authentication from the theory.

!!! danger "Clean up"
    Stored images cost a little each month. Remove the repo when you're done:

    ```bash
    aws ecr delete-repository --repository-name sample-api --force --region us-east-1
    ```

---

## Advanced Topics

Powerful features to layer on once the basics click:

- **Caching** — cache dependencies/Docker layers between runs with a `hashFiles()` key → [Caching dependencies](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-your-workflow-does/cache-dependencies)
- **Matrix builds** — run one job across a grid (Node 20/22/24 × OS) from a single definition → [Using a matrix](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/run-variations-of-jobs-in-a-workflow)
- **Reusable workflows** — factor a pipeline into a `workflow_call` file that many repos share → [Reusing workflows](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows)
- **Environments** — a named target (`staging`/`production`) with its own secrets and a **required-reviewer** approval gate → [Using environments](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/manage-environments)
- **Self-hosted / custom runners** — your own machines (private network access, special hardware, more compute) via `runs-on: self-hosted` → [Self-hosted runners](https://docs.github.com/en/actions/how-tos/manage-runners/self-hosted-runners)
- **Workflow permissions** — scope the automatic `GITHUB_TOKEN` to least privilege with a `permissions:` block → [`permissions` syntax](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#permissions) · [Automatic token authentication](https://docs.github.com/en/actions/security-for-github-actions/security-guides/automatic-token-authentication)

---

## Assignment

**Goal:** run the image you pushed to ECR on a real server — pulled and started by **Ansible**, not by hand.

1. **Launch an EC2 instance** (Ubuntu 24.04, `t3.micro`) with a security group that allows **SSH** from your IP and **HTTP** (port 80) from anywhere. Give it an IAM role (or credentials) that can **read from ECR**.
2. **Write an Ansible playbook** (building on Week 3) that, on the instance:
   - installs **Docker**,
   - logs in to ECR (`aws ecr get-login-password | docker login ...`),
   - **pulls your image** from ECR, and
   - **runs it** as a container, publishing container port 3000 on host port 80.
3. **Run the playbook**, then `curl http://<ec2-public-ip>/healthz` — you should get `{"status":"ok"}`, served by the container Ansible deployed.

**Submit:** your playbook + inventory, and the `curl` output showing the app responding from the EC2.

!!! danger "Clean up"
    Terminate the EC2 and delete the ECR repository when you're done.

---

## Further Reading

**Watch**

- 📺 [GitHub Actions — Build & Push Docker images](https://youtu.be/R8_veQiYBjI?t=900) — the CI-pipeline-with-Docker segment of the GitHub Actions walkthrough

**Reference**

- [Variables](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/store-information-in-variables) · [Using secrets](https://docs.github.com/en/actions/how-tos/security-for-github-actions/security-guides/using-secrets-in-github-actions)
- [Expressions](https://docs.github.com/en/actions/reference/workflows-and-actions/expressions) · [Contexts](https://docs.github.com/en/actions/reference/workflows-and-actions/contexts) · [`GITHUB_TOKEN`](https://docs.github.com/en/actions/security-for-github-actions/security-guides/automatic-token-authentication)
- [Passing information between jobs (outputs)](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/pass-information-between-jobs) · [`if` conditions](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#jobsjob_idif)
- [Configuring OIDC in AWS](https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services) · [`aws-actions/configure-aws-credentials`](https://github.com/aws-actions/configure-aws-credentials) · [`docker/build-push-action`](https://github.com/docker/build-push-action)
