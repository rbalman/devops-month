# Day 1 · CI/CD Fundamentals & First Pipeline

> Building and shipping software **by hand** — SSH in, run a command, edit a file, restart nginx — works, but it's slow, easy to get wrong, and impossible for a team to share. A **CI/CD pipeline** is a machine that does it **for you**: push code → it's tested, built, and deployed automatically, with logs to prove it. The tool for it here is **GitHub Actions**. This is the foundation — what CI/CD actually means, how a pipeline is wired, and a first working workflow that runs on every push.

!!! info "The bigger picture — Operation Go Live, automated"
    Week 4 builds toward one thing: an **end-to-end project** (frontend · backend · database) that **provisions itself with Terraform, configures itself with Ansible, and deploys itself with GitHub Actions** — then gets monitored and secured. This is the CI/CD pipeline that drives it.

## Learning Objectives

- Explain what **CI**, **CD** (delivery), and **CD** (deployment) mean and how they differ
- Describe a pipeline as **stages** with **gates** — and why automating them beats doing it by hand
- Name the pieces of **GitHub Actions**: workflow, event/trigger, job, step, runner, action
- Know the four triggers you'll use most: **`push`, `pull_request`, `workflow_dispatch`, `schedule`**
- **Lab:** write a workflow that **lints, tests, and builds** the sample app on every push and PR, and read its logs

---

## Prerequisites

- A **GitHub account** and Git configured (Week 1)
- **Docker** installed locally (Week 2) — for containerizing the app
- Basic command line + a repo you can push to

---

## Theory · ~30 min

### 1. What CI/CD actually means

**CI/CD** is the practice of automating the path from *"I changed some code"* to *"it's running in production"* — so that path is fast, repeatable, and safe. It's three ideas that stack:

| Term | What it means | The question it answers |
|---|---|---|
| **CI** — Continuous **Integration** | Every push is automatically **built and tested**, merged into a shared branch often | "Does the code still work?" |
| **CD** — Continuous **Delivery** | Every change that passes CI is automatically packaged into a **deployable artifact**, ready to release at the click of a button | "Is it *ready* to ship?" |
| **CD** — Continuous **Deployment** | Every change that passes CI/CD is **automatically released to production** — no human click | "Ship it — automatically." |

The distinction that trips people up is the two CDs: **delivery** stops at "ready to deploy, waiting for a human to approve"; **deployment** removes even that click. Delivery is the safe default for most teams; deployment is the goal once you trust your tests.

!!! tip "📺 Watch — *GitHub Actions Tutorial: Basic Concepts & CI/CD Pipeline*"
    A clear 30-minute walkthrough of GitHub Actions concepts and a first CI pipeline.

    [![GitHub Actions Tutorial - Basic Concepts and CI/CD Pipeline with Docker](https://img.youtube.com/vi/R8_veQiYBjI/hqdefault.jpg){ width="360" }](https://youtu.be/R8_veQiYBjI)

    **Chapters:** [what is CI/CD](https://youtu.be/R8_veQiYBjI?t=59) · [GitHub Actions concepts](https://youtu.be/R8_veQiYBjI?t=196) · [workflow syntax](https://youtu.be/R8_veQiYBjI?t=548) · [CI pipeline demo](https://youtu.be/R8_veQiYBjI?t=900)

### 2. Why automate — the pain it removes

You've felt every one of these this month:

- **"Works on my machine."** A pipeline runs on a **clean, identical machine** every time, so environment drift can't hide bugs.
- **Forgotten steps.** Deploying by hand is a checklist you *remember* — until you don't. A pipeline is the checklist, executed the same way every time.
- **Slow feedback.** A broken test caught 30 seconds after you push is trivial; caught a week later in production, it's an incident.
- **Bus factor.** "Only Priya knows how to deploy" is a risk. A pipeline is deploy knowledge written down and runnable by anyone.

The payoff is **confidence to ship often**: small, frequent, automatically-verified changes instead of big, scary, manual releases.

### 3. A pipeline is stages + gates

A pipeline is a sequence of **stages**, each a **gate** that must pass before the next runs. At a high level almost every pipeline looks like this:

```text
  push  ──▶  Build  ──▶  Test  ──▶  Deploy
```

Two rules make this powerful:

- **Fail fast** — cheap checks run before expensive ones, so you learn about a problem in seconds instead of after a long build or a failed deploy.
- **A red gate stops the line** — if a stage fails, nothing downstream runs. Broken code never reaches production.

!!! question "Does *build* come before or after *test*?"
    You'll see it written both ways because **"build" means two different things**:

    - **Build = compile/assemble the code** so it can run. In compiled languages (Java, Go, TypeScript) you *must* do this before tests — you can't test code that doesn't compile. That's the **build → test** order most docs show.
    - **Build = package the deployable artifact** (a Docker image, a release bundle). This happens *after* tests pass — you never want to ship an artifact built from broken code.

    So the fuller picture is **build (compile) → test → build (package) → deploy**. Interpreted languages like JavaScript and Python have no compile step, so their pipelines read **lint → test → package** — which is exactly what the lab below does.

The lab below builds the first stages — **lint, test, and package** the app. Publishing the image to a registry and deploying it are covered in [GitHub Actions II — Build, Push & Deploy](day-23.md).

### 4. GitHub Actions — the anatomy

**GitHub Actions** is CI/CD built into GitHub: you commit a YAML file describing your pipeline, and GitHub runs it on their machines whenever an event you care about happens. Six terms cover the whole model:

| Term | What it is |
|---|---|
| **Workflow** | The whole automated process — one YAML file in `.github/workflows/` |
| **Event / trigger** | What starts a workflow — a push, a PR, a schedule, a manual click (`on:`) |
| **Job** | A group of steps that run together on one runner; jobs run **in parallel** by default |
| **Step** | A single task in a job — either a shell command (`run:`) or an action (`uses:`) |
| **Runner** | The machine that executes a job — GitHub-hosted (`ubuntu-latest`) or self-hosted |
| **Action** | A reusable, packaged step you pull off the shelf — e.g. `actions/checkout` |

The mental model: a **workflow** listens for an **event**, then runs one or more **jobs** on **runners**, each job a list of **steps**, where a step is either your own command (`run:`) or a shared **action** (`uses:`).

Here's the **smallest complete workflow** — save it as `.github/workflows/hello.yml`:

```yaml
name: Hello                   # label shown in the Actions tab
on: [push]                    # the event that triggers this workflow

jobs:                         # a workflow has one or more jobs
  greet:                      # "greet" is a job id you choose
    runs-on: ubuntu-latest    # the runner (VM) the job executes on
    steps:                    # an ordered list of steps
      - uses: actions/checkout@v7      # a step that runs an ACTION (checks out your repo)
      - name: Say hello                # a step that runs a SHELL COMMAND
        run: echo "Hello from GitHub Actions!"
```

Every workflow is built from the same handful of keys — the full **[workflow syntax reference](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax)** documents them all:

| Key | What it does | Required? |
|---|---|---|
| `name:` | The workflow's display name in the **Actions** tab | optional |
| `on:` | The **event(s)** that trigger it (`push`, `pull_request`, …) | **yes** |
| `jobs:` | Map of jobs; they run **in parallel** unless linked with `needs:` | **yes** |
| `<job-id>:` | A name you pick for a job (here, `greet`) | **yes** |
| `runs-on:` | The **runner** image the job runs on (e.g. `ubuntu-latest`) | **yes** |
| `steps:` | The ordered list of steps in a job | **yes** |
| `uses:` | Run a prepackaged **action** — `owner/repo@version` | per-step |
| `run:` | Run **shell commands** on the runner | per-step |
| `name:` (step) | An optional label for a step in the logs | optional |

Two rules the format enforces: it's **YAML**, so indentation is significant (2 spaces, **never tabs**), and the file must live in **`.github/workflows/`** at the repo root to be picked up.

!!! note "Actions are versioned — pin the major"
    `uses: actions/checkout@v7` pins to major version 7; you get bug/security patches within v7 but never a surprise breaking change. Always pin at least the major (`@v7`), never leave it off. This course uses the current majors: `checkout@v7`, `setup-node@v6`, and the Docker/AWS actions we meet on Day 2.

### 5. The four triggers you'll actually use

`on:` decides *when* a workflow runs. Four cover almost everything:

| Trigger | Fires when | Typical use |
|---|---|---|
| `push` | Commits are pushed to a branch | Run CI on every change; deploy on push to `main` |
| `pull_request` | A PR is opened or updated | Test a change **before** it's merged — the safety gate |
| `workflow_dispatch` | You click **Run workflow** in the UI (or via API) | Manual deploys, one-off jobs |
| `schedule` | A cron expression matches | Nightly builds, backups, dependency scans |

You can combine them — most CI workflows trigger on **both** `push` and `pull_request`, and you can scope them to branches or paths:

```yaml
on:
  push:
    branches: [main]          # only pushes to main
  pull_request:               # any PR
  workflow_dispatch:          # + a manual button
```

---

## Lab · ~45 min

Build your first CI pipeline: a workflow that **lints, tests, and builds** the API on every push and pull request. You'll start from the reference app, understand its workflow, push it, and watch GitHub run it.

!!! note "Node here is just a vehicle for CI"
    You don't need to know Node — the *shape* (install deps → lint → test → build) is identical in Python, Go, or Java. Focus on the pipeline, not the language.

### 1. Get the reference app

You won't hand-type the app — a complete, runnable version lives in the course repo at [`examples/cicd/first-pipeline`](https://github.com/rbalman/devops-month/tree/main/examples/cicd/first-pipeline). Start your own repo from it:

```bash
git clone https://github.com/rbalman/devops-month.git
cp -r devops-month/examples/cicd/first-pipeline ~/sample-app
cd ~/sample-app
git init
```

It's a tiny **Node.js / Express API** — just enough to have something real to lint, test, and build:

```text
sample-app/
├── .github/workflows/ci.yml   # the pipeline (Section 2 walks through it)
└── api/
    ├── app.js            # the Express app (exported so tests can import it)
    ├── server.js         # starts the app (separate so tests don't open a port)
    ├── app.test.js       # one test — GET /healthz
    ├── eslint.config.js  # minimal ESLint flat config
    ├── package.json      # scripts: start / test / lint
    └── package-lock.json # exact dep versions — required by `npm ci`
```

| File | Why it's here |
|---|---|
| `app.js` / `server.js` | the app is split from its server start, so tests import the app **without opening a port** |
| `app.test.js` | the thing CI runs — one Jest test hitting `/healthz` |
| `eslint.config.js` | gives `npm run lint` something to check |
| `package-lock.json` | pins exact versions so CI installs are **reproducible** (`npm ci`) |

Verify it runs on your **Ubuntu 24.04** box before automating (install Node 24 first if needed — the [example README](https://github.com/rbalman/devops-month/tree/main/examples/cicd/first-pipeline) has the one-liner):

```bash
cd api
npm ci
npm run lint && npm test      # both should pass
```

### 2. Understand the workflow

The example already ships the pipeline at **`.github/workflows/ci.yml`** — workflows must live in `.github/workflows/` at the **repo root** (not inside `api/`). Open it and read it against [Section 4](#4-github-actions-the-anatomy):

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
  workflow_dispatch:          # lets you trigger it by hand too

jobs:
  build:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: api    # all run: steps execute inside api/
    steps:
      - name: Check out the code
        uses: actions/checkout@v7

      - name: Set up Node.js
        uses: actions/setup-node@v6
        with:
          node-version: 24
          cache: npm
          cache-dependency-path: api/package-lock.json

      - name: Install dependencies
        run: npm ci

      - name: Lint
        run: npm run lint

      - name: Test
        run: npm test

      - name: Build (produce a runnable artifact)
        run: npm pack        # stand-in "build" step — packages the app into a tarball
```

Read it top to bottom against [Section 4](#4-github-actions-the-anatomy): one **workflow** (`CI`), triggered by three **events**, with one **job** (`build`) on an `ubuntu-latest` **runner**, made of **steps** that are either an **action** (`uses:`) or a command (`run:`).

!!! tip "`npm ci` vs `npm install` in CI"
    Use **`npm ci`** in pipelines: it installs **exactly** what's in `package-lock.json` (reproducible) and fails if the lockfile is out of sync — instead of quietly changing it like `npm install` can.

### 3. Push it and watch it run

```bash
cd ~/sample-app
git add .
git commit -m "Sample app + CI workflow"
# create an empty repo on github.com first, then:
git remote add origin https://github.com/<you>/sample-app.git
git branch -M main
git push -u origin main
```

Open your repo on GitHub → **Actions** tab. You'll see the **CI** workflow running. Click into it, then into the **build** job, and expand each step to read its logs — this is where you'll live when something fails.

### 4. Make it fail (on purpose), then fix it

CI only earns trust if you've seen it catch something. Break the test:

```javascript
// in api/app.test.js, change the expectation to a wrong value
expect(res.body.status).toBe("BROKEN");
```

Commit and push. This time the **Test** step goes red, the **Build** step never runs (the gate stopped the line), and the commit gets a ❌ on GitHub. Revert the change, push again, and watch it go green ✅.

### 5. Add a status badge

Show the world your build is green. Add this to a `README.md` at the repo root (swap in your username/repo):

```markdown
![CI](https://github.com/<you>/sample-app/actions/workflows/ci.yml/badge.svg)
```

Commit, push, and the badge renders live in your README — red or green with every push.

!!! success "What you just built"
    A workflow that runs on every push and PR, on a clean machine, and **blocks broken code** at the test gate — the "CI" in CI/CD.

---

## Advanced Topics

Adjacent topics — skim the linked docs:

- **Required status checks / branch protection** — make a green CI a *requirement* to merge a PR → [Protected branches](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches)
- **Matrix builds** — test across many Node/OS versions from one job → [Using a matrix](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/run-variations-of-jobs-in-a-workflow)
- **Caching** — speed up installs by caching dependencies between runs → [Caching dependencies](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-your-workflow-does/cache-dependencies)
- **Concurrency** — cancel superseded runs when you push again quickly → [`concurrency`](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#concurrency)
- **The Actions marketplace** — thousands of prebuilt actions before you write your own → [Marketplace](https://github.com/marketplace?type=actions)

---

## Assignment

Extend this pipeline so it behaves like a real team's CI.

**Part 1 — A second job with a dependency.** Add a **`lint`** job that runs *separately* from `test`, and make the build depend on it so the pipeline reads **lint → build**:

- Move linting into its own job named `lint`.
- Add `needs: lint` to the `build` job so it only runs after lint passes.
- Push a commit with a lint error (e.g. an unused variable) and confirm `build` is **skipped**, not just failed.

**Part 2 — Trigger it on a schedule.** Add a **`schedule`** trigger that runs the workflow every morning at 6:00 UTC, so you'd catch a dependency that breaks even when nobody pushed:

```yaml
on:
  schedule:
    - cron: "0 6 * * *"
```

Use [crontab.guru](https://crontab.guru/) to confirm the expression, and note in your README what time that is in **your** timezone.

**Submit:** your `ci.yml`, a screenshot of the Actions tab showing the `lint` → `build` dependency (one run where `build` was skipped because `lint` failed), and your README with the badge + the schedule note.

!!! tip "Keep this repo"
    It's a working CI foundation you can extend into a full CI/**CD** pipeline — image build, registry push, and deploy.

---

## Further Reading

**Watch**

- 📺 [GitHub Actions Tutorial — Basic Concepts and CI/CD Pipeline with Docker](https://youtu.be/R8_veQiYBjI) — TechWorld with Nana; concepts + a first pipeline, well chaptered

**Reference**

- [GitHub Actions — Understanding GitHub Actions](https://docs.github.com/en/actions/get-started/understand-github-actions) · [Workflow syntax](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax)
- [Events that trigger workflows](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows) · [`workflow_dispatch`](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow)
- [`actions/checkout`](https://github.com/actions/checkout) · [`actions/setup-node`](https://github.com/actions/setup-node)
- [Atlassian — Continuous integration vs delivery vs deployment](https://www.atlassian.com/continuous-delivery/principles/continuous-integration-vs-delivery-vs-deployment)
