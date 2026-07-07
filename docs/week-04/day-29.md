# Day 29 · Final Project — End-to-End DevOps Pipeline

## Learning Objectives

- Put everything from the course together into a single working system
- Deploy a containerized application to AWS with CI/CD, monitoring, and alerting
- Document your infrastructure as code

---

## The Full Picture

This is what you're building today:

```
GitHub Repository
    │
    ├── app/          ← Flask app with /metrics endpoint
    ├── Dockerfile    ← Containerized app
    ├── docker-compose.yml ← Full monitoring stack
    └── .github/workflows/deploy.yml ← CI/CD pipeline
         │
         ▼
GitHub Actions
    ├── Run tests (pytest)
    ├── Build Docker image
    ├── Push to Docker Hub
    └── Deploy to EC2 via SSH
              │
              ▼
         AWS EC2 Instance
              ├── App Container     (:8080)
              ├── Nginx (reverse proxy) (:80)
              ├── Prometheus        (:9090)
              ├── Node Exporter     (:9100)
              ├── Loki              (:3100)
              ├── Promtail          (sidecar)
              └── Grafana           (:3000)
                       │
                       └── Discord Alerts
```

---

## Project · ~90 min

### Step 1 — Create the final project repo

```bash
mkdir -p ~/final-project/{app,.github/workflows,monitoring/{prometheus,loki,promtail,grafana/provisioning/datasources}}
cd ~/final-project
git init
git checkout -b main
```

### Step 2 — The application

```bash
cat > app/app.py << 'EOF'
from flask import Flask, jsonify, Response, request
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
import time, os, json, logging, socket

class JSONFormatter(logging.Formatter):
    def format(self, record):
        return json.dumps({
            "timestamp": self.formatTime(record),
            "level": record.levelname,
            "message": record.getMessage(),
        })

handler = logging.StreamHandler()
handler.setFormatter(JSONFormatter())
logging.root.handlers = [handler]
logging.root.setLevel(logging.INFO)
logger = logging.getLogger("app")

app = Flask(__name__)

REQUEST_COUNT    = Counter('http_requests_total', 'Total requests', ['method', 'endpoint', 'status'])
REQUEST_DURATION = Histogram('http_request_duration_seconds', 'Duration', ['endpoint'])
ERROR_COUNT      = Counter('http_errors_total', 'Total errors', ['endpoint'])

@app.route("/")
def index():
    start = time.time()
    logger.info(json.dumps({"event": "request", "path": "/"}))
    REQUEST_COUNT.labels("GET", "/", 200).inc()
    REQUEST_DURATION.labels("/").observe(time.time() - start)
    return jsonify({
        "service": "devops-month-app",
        "version": os.getenv("APP_VERSION", "unknown"),
        "commit": os.getenv("GIT_COMMIT", "unknown"),
        "hostname": socket.gethostname(),
    })

@app.route("/health")
def health():
    REQUEST_COUNT.labels("GET", "/health", 200).inc()
    return jsonify({"status": "ok"})

@app.route("/metrics")
def metrics():
    return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)

@app.errorhandler(Exception)
def handle_error(e):
    ERROR_COUNT.labels(request.path).inc()
    logger.error(json.dumps({"event": "error", "path": request.path, "error": str(e)}))
    return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
EOF

cat > app/requirements.txt << 'EOF'
flask==3.0.0
prometheus-client==0.19.0
EOF

cat > Dockerfile << 'EOF'
FROM python:3.11-slim

WORKDIR /app

COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app/app.py .

ARG GIT_COMMIT=unknown
ENV GIT_COMMIT=$GIT_COMMIT

EXPOSE 8080
CMD ["python3", "app.py"]
EOF
```

### Step 3 — Monitoring stack compose file

```bash
cat > monitoring/prometheus/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: prometheus
    static_configs:
      - targets: ["localhost:9090"]

  - job_name: node
    static_configs:
      - targets: ["node-exporter:9100"]

  - job_name: app
    static_configs:
      - targets: ["app:8080"]
EOF

cat > monitoring/loki/config.yml << 'EOF'
auth_enabled: false
server:
  http_listen_port: 3100
ingester:
  lifecycler:
    address: 127.0.0.1
    ring:
      kvstore:
        store: inmemory
      replication_factor: 1
schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h
storage_config:
  boltdb_shipper:
    active_index_directory: /loki/index
    cache_location: /loki/index_cache
    shared_store: filesystem
  filesystem:
    directory: /loki/chunks
EOF

cat > monitoring/promtail/config.yml << 'EOF'
server:
  http_listen_port: 9080
positions:
  filename: /tmp/positions.yaml
clients:
  - url: http://loki:3100/loki/api/v1/push
scrape_configs:
  - job_name: containers
    docker_sd_configs:
      - host: unix:///var/run/docker.sock
        refresh_interval: 5s
    relabel_configs:
      - source_labels: [__meta_docker_container_name]
        regex: '/(.*)'
        target_label: container
EOF

cat > monitoring/grafana/provisioning/datasources/datasources.yml << 'EOF'
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    url: http://prometheus:9090
    isDefault: true
  - name: Loki
    type: loki
    url: http://loki:3100
EOF

cat > docker-compose.yml << 'EOF'
services:
  app:
    image: ${DOCKER_IMAGE:-devops-month-app:local}
    build: .
    container_name: app
    restart: unless-stopped
    ports:
      - "8080:8080"
    environment:
      - APP_VERSION=${APP_VERSION:-dev}

  nginx:
    image: nginx:alpine
    container_name: nginx
    restart: unless-stopped
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro
    depends_on:
      - app

  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./monitoring/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus_data:/prometheus

  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    ports:
      - "9100:9100"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'

  loki:
    image: grafana/loki:2.9.0
    container_name: loki
    ports:
      - "3100:3100"
    volumes:
      - ./monitoring/loki/config.yml:/etc/loki/config.yml:ro
      - loki_data:/loki
    command: -config.file=/etc/loki/config.yml

  promtail:
    image: grafana/promtail:2.9.0
    container_name: promtail
    volumes:
      - ./monitoring/promtail/config.yml:/etc/promtail/config.yml:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
    command: -config.file=/etc/promtail/config.yml
    depends_on:
      - loki

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=devops123
    volumes:
      - ./monitoring/grafana/provisioning:/etc/grafana/provisioning:ro
      - grafana_data:/var/lib/grafana
    depends_on:
      - prometheus
      - loki

volumes:
  prometheus_data:
  loki_data:
  grafana_data:
EOF

cat > nginx.conf << 'EOF'
server {
    listen 80;
    location / {
        proxy_pass http://app:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
    location /health {
        proxy_pass http://app:8080/health;
    }
}
EOF
```

### Step 4 — The CI/CD pipeline

```bash
cat > .github/workflows/deploy.yml << 'EOF'
name: Deploy

on:
  push:
    branches: [main]

env:
  IMAGE: ${{ secrets.DOCKER_USERNAME }}/devops-month-final

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.11"
      - run: pip install flask pytest prometheus-client
      - run: pytest || echo "No tests yet"

  build-push:
    runs-on: ubuntu-latest
    needs: test
    steps:
      - uses: actions/checkout@v4
      - uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKER_USERNAME }}
          password: ${{ secrets.DOCKER_PASSWORD }}
      - uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ${{ env.IMAGE }}:${{ github.sha }},${{ env.IMAGE }}:latest
          build-args: GIT_COMMIT=${{ github.sha }}

  deploy:
    runs-on: ubuntu-latest
    needs: build-push
    steps:
      - uses: actions/checkout@v4
      - uses: appleboy/ssh-action@v1
        with:
          host: ${{ secrets.EC2_HOST }}
          username: ${{ secrets.EC2_USER }}
          key: ${{ secrets.EC2_SSH_KEY }}
          script: |
            cd /opt/devops-month
            git pull origin main
            export DOCKER_IMAGE=${{ env.IMAGE }}:${{ github.sha }}
            export APP_VERSION=${{ github.sha }}
            docker compose pull app
            docker compose up -d
            sleep 10
            curl -f http://localhost/health
            echo "Deploy complete: ${{ github.sha }}"
EOF
```

### Step 5 — Bootstrap the EC2 server

SSH into EC2 and run:

```bash
sudo apt update && sudo apt install -y git docker.io docker-compose-plugin
sudo usermod -aG docker ubuntu
sudo mkdir -p /opt/devops-month
sudo chown ubuntu:ubuntu /opt/devops-month
cd /opt/devops-month
git clone https://github.com/<your-username>/final-project.git .
docker compose up -d
```

Then push your code to trigger the full pipeline:

```bash
git add .
git commit -m "final project: complete devops pipeline"
git push origin main
```

### Verify Everything

```bash
EC2_IP=<your-ec2-ip>

curl http://$EC2_IP/          # app response
curl http://$EC2_IP/health    # health check
curl http://$EC2_IP:9090      # Prometheus UI
# Grafana at http://$EC2_IP:3000 (open in browser)
```

---

## Assignment

Document your final project in `my-progress/day-29.md`:

1. Paste the URL of your deployed app
2. Screenshot your Grafana dashboard (or paste the exported JSON)
3. What broke during the project and how did you fix it?
4. If you had to do this for a production app with a team of 5, what would you change?

