# Day 4 · CI/CD II — Build, Push & Deploy to EC2

## Learning Objectives

- Build a Docker image in CI and push it to a registry
- Automate deployment to an EC2 instance via GitHub Actions
- Use GitHub Secrets to store credentials safely

---

## Theory · ~20 min

### A Complete CI/CD Pipeline

A real pipeline has distinct stages with clear responsibilities:

```
Code Push
    ↓
[CI] Lint + Test
    ↓ (only if tests pass)
[CI] Build Docker Image
    ↓
[CI] Push Image to Registry (Docker Hub or ECR)
    ↓ (only on main branch)
[CD] SSH to EC2, pull new image, restart container
    ↓
Application running with new code
```

### GitHub Secrets

Secrets are encrypted key-value pairs stored in your repository settings. They're injected into workflows as environment variables — never visible in logs.

Go to: **Repository → Settings → Secrets and variables → Actions → New repository secret**

Typical secrets for this pipeline:
- `DOCKER_USERNAME` — Docker Hub username
- `DOCKER_PASSWORD` — Docker Hub token (not your password)
- `EC2_HOST` — your EC2 instance's public IP
- `EC2_SSH_KEY` — the private key to SSH into EC2
- `EC2_USER` — usually `ubuntu` for Ubuntu AMIs

### Deployment Strategies

| Strategy | How | Downtime |
|---|---|---|
| Recreate | Stop old, start new | Yes |
| Rolling | Update instances one at a time | No |
| Blue/Green | Run two environments, switch traffic | No |
| Canary | Gradually shift traffic to new version | No |

For this course we'll use **Recreate** — simple and sufficient for a single-server setup.

---

## Lab · ~50 min

### Step 1 — Prepare the application

```bash
cd ~/cicd-demo

# Create a simple Flask app to deploy
cat > app.py << 'EOF'
from flask import Flask, jsonify
import os

app = Flask(__name__)

@app.route("/")
def index():
    return jsonify({
        "message": "Hello from the DevOps Month CI/CD pipeline!",
        "version": os.getenv("APP_VERSION", "unknown"),
        "commit": os.getenv("GIT_COMMIT", "unknown")
    })

@app.route("/health")
def health():
    return jsonify({"status": "ok"})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
EOF

cat > requirements.txt << 'EOF'
flask==3.0.0
pytest==7.4.0
flake8==6.0.0
EOF

cat > test_app.py << 'EOF'
import pytest
from app import app

@pytest.fixture
def client():
    app.testing = True
    return app.test_client()

def test_index(client):
    r = client.get("/")
    assert r.status_code == 200
    data = r.get_json()
    assert "message" in data

def test_health(client):
    r = client.get("/health")
    assert r.status_code == 200
    assert r.get_json()["status"] == "ok"
EOF

cat > Dockerfile << 'EOF'
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

ENV APP_VERSION=1.0

EXPOSE 8080

CMD ["python3", "app.py"]
EOF

cat > .dockerignore << 'EOF'
.git/
.github/
*.pyc
__pycache__/
test_*.py
EOF

git add .
git commit -m "add flask app with dockerfile"
```

### Step 2 — Add GitHub Secrets

In your GitHub repo, go to **Settings → Secrets → Actions** and add:

- `DOCKER_USERNAME` — your Docker Hub username
- `DOCKER_PASSWORD` — Docker Hub access token (Docker Hub → Account Settings → Security → New Access Token)
- `EC2_HOST` — the public IP of your EC2 instance from Day 1
- `EC2_SSH_KEY` — paste the contents of `~/.ssh/devops-month-ec2.pem`
- `EC2_USER` — `ubuntu`

### Step 3 — Write the full CI/CD pipeline

```bash
cat > .github/workflows/deploy.yml << 'EOF'
name: CI/CD Pipeline

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

env:
  IMAGE_NAME: ${{ secrets.DOCKER_USERNAME }}/devops-month-app

jobs:
  test:
    name: Lint and Test
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-python@v5
        with:
          python-version: "3.11"

      - name: Install dependencies
        run: pip install -r requirements.txt

      - name: Lint
        run: flake8 app.py --max-line-length=100

      - name: Test
        run: pytest test_app.py -v

  build-and-push:
    name: Build & Push Image
    runs-on: ubuntu-latest
    needs: test
    if: github.ref == 'refs/heads/main'   # only on main branch

    outputs:
      image_tag: ${{ steps.meta.outputs.version }}

    steps:
      - uses: actions/checkout@v4

      - name: Docker metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.IMAGE_NAME }}
          tags: |
            type=sha,prefix=sha-
            type=raw,value=latest

      - name: Log in to Docker Hub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKER_USERNAME }}
          password: ${{ secrets.DOCKER_PASSWORD }}

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          build-args: |
            GIT_COMMIT=${{ github.sha }}

  deploy:
    name: Deploy to EC2
    runs-on: ubuntu-latest
    needs: build-and-push
    if: github.ref == 'refs/heads/main'

    steps:
      - name: Deploy via SSH
        uses: appleboy/ssh-action@v1
        with:
          host: ${{ secrets.EC2_HOST }}
          username: ${{ secrets.EC2_USER }}
          key: ${{ secrets.EC2_SSH_KEY }}
          script: |
            # Pull latest image
            docker pull ${{ env.IMAGE_NAME }}:latest

            # Stop and remove old container
            docker stop devops-app || true
            docker rm devops-app || true

            # Run new container
            docker run -d \
              --name devops-app \
              --restart unless-stopped \
              -p 80:8080 \
              -e APP_VERSION=${{ github.sha }} \
              -e GIT_COMMIT=${{ github.sha }} \
              ${{ env.IMAGE_NAME }}:latest

            # Health check
            sleep 5
            curl -f http://localhost/health || exit 1
            echo "Deployment successful!"
EOF

git add .github/
git commit -m "add full ci/cd deploy pipeline"
git push origin main
```

### Step 4 — Prepare EC2 for Docker deployments

SSH into your EC2 instance and install Docker:

```bash
ssh -i ~/.ssh/devops-month-ec2.pem ubuntu@$EC2_IP

# On the EC2 instance:
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker ubuntu
newgrp docker
docker --version

exit
```

### Step 5 — Trigger and monitor the pipeline

```bash
# Make a small change and push to trigger the pipeline
echo "# My App" >> README.md
git add README.md
git commit -m "trigger pipeline"
git push origin main
```

Watch the **Actions** tab in GitHub. After the pipeline completes:

```bash
# Test the deployed app
curl http://$EC2_IP
curl http://$EC2_IP/health
```

---

## Assignment

1. What would happen in the pipeline if the `test` job fails? Would `build-and-push` run?
2. What is the `if: github.ref == 'refs/heads/main'` condition doing? Why is this important?
3. Add a Slack or Discord notification step at the end of the `deploy` job that sends a message when deployment succeeds.
4. What is the difference between Docker Hub and AWS ECR as a container registry?

---

## Further Reading

- [GitHub Actions: deploy to EC2](https://docs.github.com/en/actions/deployment/deploying-to-amazon-ec2)
- [Docker build-push-action](https://github.com/docker/build-push-action)
- [appleboy/ssh-action](https://github.com/appleboy/ssh-action)
