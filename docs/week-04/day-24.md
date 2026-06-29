# Day 24 · CI/CD I — GitHub Actions Fundamentals

## Learning Objectives

- Understand CI/CD concepts and the problem they solve
- Write GitHub Actions workflows with triggers, jobs, and steps
- Run automated tests and linting on every push

---

## Theory · ~20 min

### What is CI/CD?

**Continuous Integration (CI)**: Every code change is automatically built and tested. Problems are caught immediately, not days later.

**Continuous Delivery/Deployment (CD)**: Tested code is automatically delivered to a staging or production environment.

Before CI/CD:
- Developers worked on features for weeks in isolation
- "Integration hell" when merging — conflicts everywhere
- Manual releases that took hours and were prone to errors
- Deployment on Friday = weekend on-call

With CI/CD:
- Small, frequent changes merged to main
- Every commit triggers automated tests
- Deployment is automated and reliable
- A broken build is caught in minutes, not weeks

### GitHub Actions

GitHub Actions is GitHub's built-in CI/CD platform. Workflows are YAML files in `.github/workflows/`.

**Key concepts:**

| Term | Meaning |
|---|---|
| **Workflow** | A YAML file defining automated processes |
| **Trigger (on:)** | What causes the workflow to run (push, PR, schedule) |
| **Job** | A set of steps running on a single machine |
| **Step** | A single task within a job (a command or an action) |
| **Action** | A reusable step from the marketplace (`actions/checkout@v4`) |
| **Runner** | The machine that runs the job (`ubuntu-latest`) |
| **Secret** | Encrypted variable stored in GitHub settings |

### Workflow Syntax

```yaml
name: CI

on:                         # trigger
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:                     # job name
    runs-on: ubuntu-latest  # runner

    steps:
      - uses: actions/checkout@v4   # action: checkout your code

      - name: Run tests
        run: |
          echo "Running tests..."
          pytest tests/
```

---

## Lab · ~50 min

### Step 1 — Set up a sample project

```bash
mkdir -p ~/cicd-demo
cd ~/cicd-demo
git init
git checkout -b main

# Create a simple Python app
cat > app.py << 'EOF'
def add(a, b):
    return a + b

def subtract(a, b):
    return a - b

def divide(a, b):
    if b == 0:
        raise ValueError("Cannot divide by zero")
    return a / b
EOF

# Create tests
cat > test_app.py << 'EOF'
import pytest
from app import add, subtract, divide

def test_add():
    assert add(2, 3) == 5
    assert add(-1, 1) == 0

def test_subtract():
    assert subtract(5, 3) == 2

def test_divide():
    assert divide(10, 2) == 5.0

def test_divide_by_zero():
    with pytest.raises(ValueError):
        divide(10, 0)
EOF

# Create requirements
cat > requirements.txt << 'EOF'
pytest==7.4.0
flake8==6.0.0
EOF

# Run locally to verify
pip install -r requirements.txt
pytest test_app.py -v
flake8 app.py

git add .
git commit -m "initial app and tests"
```

### Step 2 — Your first GitHub Actions workflow

```bash
mkdir -p .github/workflows

cat > .github/workflows/ci.yml << 'EOF'
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  lint-and-test:
    name: Lint and Test
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.11"

      - name: Cache pip packages
        uses: actions/cache@v4
        with:
          path: ~/.cache/pip
          key: ${{ runner.os }}-pip-${{ hashFiles('requirements.txt') }}

      - name: Install dependencies
        run: pip install -r requirements.txt

      - name: Lint with flake8
        run: flake8 app.py --max-line-length=100

      - name: Run tests
        run: pytest test_app.py -v --tb=short

      - name: Upload test results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: test-results
          path: "*.xml"
          if-no-files-found: ignore
EOF

git add .github/
git commit -m "add CI workflow"
```

### Step 3 — Push to GitHub and watch it run

```bash
# Create a repo on GitHub first (github.com → New repository → cicd-demo)
git remote add origin https://github.com/<your-username>/cicd-demo.git
git push -u origin main
```

Go to your GitHub repo → **Actions** tab. Watch the workflow run.

### Step 4 — Matrix builds (test across multiple versions)

```bash
cat > .github/workflows/ci.yml << 'EOF'
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  lint-and-test:
    name: Test (Python ${{ matrix.python-version }})
    runs-on: ubuntu-latest

    strategy:
      matrix:
        python-version: ["3.10", "3.11", "3.12"]

    steps:
      - uses: actions/checkout@v4

      - name: Set up Python ${{ matrix.python-version }}
        uses: actions/setup-python@v5
        with:
          python-version: ${{ matrix.python-version }}

      - name: Install dependencies
        run: pip install -r requirements.txt

      - name: Lint
        run: flake8 app.py --max-line-length=100

      - name: Test
        run: pytest test_app.py -v

  security-scan:
    name: Security Scan
    runs-on: ubuntu-latest
    needs: lint-and-test

    steps:
      - uses: actions/checkout@v4

      - name: Run bandit security scan
        run: |
          pip install bandit
          bandit -r app.py -ll
EOF

git add .github/
git commit -m "add matrix builds and security scan"
git push origin main
```

### Step 5 — Workflow triggers and conditionals

```bash
cat > .github/workflows/scheduled.yml << 'EOF'
name: Scheduled Health Check

on:
  schedule:
    - cron: "0 9 * * 1-5"    # 9am UTC, Monday–Friday
  workflow_dispatch:           # allow manual trigger

jobs:
  health:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install dependencies
        run: pip install -r requirements.txt

      - name: Run tests
        run: pytest test_app.py -v

      - name: Notify on failure
        if: failure()
        run: echo "Tests failed! Would send a Discord/Slack notification here."
EOF

git add .github/
git commit -m "add scheduled workflow"
git push origin main
```

---

## Assignment

In `my-progress/day-24.md`:

1. What is the difference between CI and CD?
2. What does `needs: lint-and-test` in the `security-scan` job do?
3. Add a new function `multiply(a, b)` to `app.py` and write a test for it. Push to a branch, open a pull request, and watch the CI run. Paste the link to the workflow run.
4. What are GitHub Actions Secrets and when do you need them? Give an example.

```bash
git add my-progress/day-24.md
git commit -m "day-24: github actions ci fundamentals"
git push origin main
```

---

## Further Reading

- [GitHub Actions documentation](https://docs.github.com/en/actions)
- [GitHub Actions Marketplace](https://github.com/marketplace?type=actions)
- [Workflow syntax reference](https://docs.github.com/en/actions/writing-workflows/workflow-syntax-for-github-actions)
