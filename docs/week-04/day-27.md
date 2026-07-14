# Day 6 · Monitoring II — Loki & Log Aggregation

## Learning Objectives

- Understand why centralized log aggregation matters
- Run Loki and collect logs from containers with Promtail
- Query logs with LogQL

---

## Theory · ~20 min

### The Problem with Logs at Scale

On a single server, you can just `tail -f /var/log/app.log`. But in a real environment:
- 10+ servers each writing their own logs
- Containers that are ephemeral — logs disappear when the container is removed
- Multiple services with different log files and formats

You need a **centralized log aggregation** system where all logs flow to one place, can be searched, and are retained even after containers die.

### The Grafana Observability Stack

```
Metrics:  Prometheus → Grafana
Logs:     Loki       → Grafana
Traces:   Tempo      → Grafana
```

**Loki** is designed as the "Prometheus for logs." Instead of indexing the full text of every log line (like Elasticsearch), it only indexes the **labels** (metadata). The log content itself is stored compressed.

Result: Loki is much cheaper to run than Elasticsearch at scale.

### Loki Architecture

```
Application logs
    ↓
Promtail (log agent — runs on each machine)
    ↓ (pushes log streams with labels)
Loki (stores logs, handles queries)
    ↓
Grafana (query via LogQL, build dashboards)
```

### LogQL

LogQL is Loki's query language, inspired by PromQL.

```logql
# All logs from the nginx container
{container="nginx"}

# Filter for error logs
{container="myapp"} |= "error"

# Filter with regex
{container="myapp"} |~ "status=[45][0-9][0-9]"

# Count error rate per minute
count_over_time({container="myapp"} |= "error" [1m])

# Parse structured logs (JSON)
{container="myapp"} | json | status >= 500
```

---

## Lab · ~50 min

### Step 1 — Add Loki and Promtail to the stack

```bash
cd ~/monitoring-labs

mkdir -p loki promtail

cat > loki/config.yml << 'EOF'
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
    final_sleep: 0s
  chunk_idle_period: 5m
  chunk_retain_period: 30s

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

limits_config:
  reject_old_samples: true
  reject_old_samples_max_age: 168h

chunk_store_config:
  max_look_back_period: 0s

table_manager:
  retention_deletes_enabled: false
  retention_period: 0s
EOF

cat > promtail/config.yml << 'EOF'
server:
  http_listen_port: 9080
  grpc_listen_port: 0

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
      - source_labels: [__meta_docker_container_log_stream]
        target_label: stream

  - job_name: system
    static_configs:
      - targets:
          - localhost
        labels:
          job: varlogs
          __path__: /var/log/*.log
EOF

# Update docker-compose.yml
cat > docker-compose.yml << 'EOF'
services:
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.retention.time=7d'

  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    ports:
      - "9100:9100"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'

  loki:
    image: grafana/loki:2.9.0
    container_name: loki
    ports:
      - "3100:3100"
    volumes:
      - ./loki/config.yml:/etc/loki/config.yml:ro
      - loki_data:/loki
    command: -config.file=/etc/loki/config.yml

  promtail:
    image: grafana/promtail:2.9.0
    container_name: promtail
    volumes:
      - ./promtail/config.yml:/etc/promtail/config.yml:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /var/log:/var/log:ro
    command: -config.file=/etc/promtail/config.yml
    depends_on:
      - loki

  app:
    build: ./app
    container_name: myapp
    ports:
      - "8080:8080"
    depends_on:
      - loki

volumes:
  prometheus_data:
  loki_data:
EOF

docker compose up -d

# Generate logs
for i in {1..30}; do curl -s http://localhost:8080/ > /dev/null; done

# Check Loki is ready
curl http://localhost:3100/ready
```

### Step 2 — Query logs via Loki API

```bash
# Query logs for the last 5 minutes (URL-encoded LogQL)
curl -G \
  "http://localhost:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={container="myapp"}' \
  --data-urlencode "start=$(date -d '5 minutes ago' +%s)000000000" \
  --data-urlencode "end=$(date +%s)000000000" \
  | python3 -m json.tool | head -40

# Query for specific strings
curl -G \
  "http://localhost:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={container="myapp"} |= "GET"' \
  --data-urlencode "start=$(date -d '10 minutes ago' +%s)000000000" \
  --data-urlencode "end=$(date +%s)000000000" \
  | python3 -m json.tool
```

### Step 3 — Add structured logging to the app

Structured logs (JSON) are much easier to query and parse:

```bash
cat > ~/monitoring-labs/app/app.py << 'EOF'
from flask import Flask, jsonify, Response, request
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
import time
import os
import json
import logging

# Structured JSON logging
class JSONFormatter(logging.Formatter):
    def format(self, record):
        return json.dumps({
            "timestamp": self.formatTime(record),
            "level": record.levelname,
            "message": record.getMessage(),
            "logger": record.name,
        })

handler = logging.StreamHandler()
handler.setFormatter(JSONFormatter())
logging.root.handlers = [handler]
logging.root.setLevel(logging.INFO)
logger = logging.getLogger("app")

app = Flask(__name__)

REQUEST_COUNT = Counter('http_requests_total', 'Total requests', ['method', 'endpoint', 'status'])
REQUEST_DURATION = Histogram('http_request_duration_seconds', 'Request duration', ['endpoint'])

@app.route("/")
def index():
    start = time.time()
    logger.info(json.dumps({"event": "request", "path": "/", "method": request.method}))
    result = jsonify({"message": "Hello!", "version": os.getenv("APP_VERSION", "1.0")})
    REQUEST_COUNT.labels("GET", "/", 200).inc()
    REQUEST_DURATION.labels("/").observe(time.time() - start)
    return result

@app.route("/health")
def health():
    REQUEST_COUNT.labels("GET", "/health", 200).inc()
    return jsonify({"status": "ok"})

@app.route("/metrics")
def metrics():
    return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
EOF

docker compose build app
docker compose up -d app

# Generate traffic
for i in {1..20}; do curl -s http://localhost:8080/ > /dev/null; done

# See structured logs from the container
docker logs myapp
```

### Step 4 — LogQL queries to know

In the Loki API or (tomorrow) Grafana:

```logql
# All logs from myapp
{container="myapp"}

# Only error-level logs
{container="myapp"} |= "ERROR"

# Parse JSON and filter
{container="myapp"} | json | level = "ERROR"

# Count log lines per minute
count_over_time({container="myapp"}[1m])

# Rate of log lines
rate({container="myapp"}[5m])
```

---

## Assignment

1. What is the difference between Loki and Elasticsearch for log storage? What trade-offs does each make?
2. What are Loki labels? Why does Loki use labels instead of full-text indexing?
3. Modify the app to log a different message for `/health` vs `/` endpoints. Query Loki to show only health check logs.
4. What does `count_over_time({container="myapp"}[5m])` return? How is it different from `rate()`?

---

## Further Reading

- [Loki documentation](https://grafana.com/docs/loki/latest/)
- [LogQL cheat sheet](https://grafana.com/docs/loki/latest/query/)
- [Promtail configuration](https://grafana.com/docs/loki/latest/send-data/promtail/)
