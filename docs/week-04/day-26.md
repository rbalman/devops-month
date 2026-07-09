# Day 26 · Monitoring I — Prometheus & Metrics

## Learning Objectives

- Understand why monitoring matters and the difference between metrics and logs
- Run Prometheus and scrape metrics from an application
- Write PromQL queries to inspect system state

---

## Theory · ~20 min

### Why Monitoring?

You can't fix what you can't see. Monitoring answers:

- Is my service up?
- Is it slow?
- How much CPU/memory/disk is it using?
- Did the error rate spike after the last deploy?

A monitoring system that only pages you when users complain is not monitoring — it's user testing in production.

### The Three Pillars of Observability

| Pillar | What it is | Tool |
|---|---|---|
| **Metrics** | Numeric measurements over time | Prometheus + Grafana |
| **Logs** | Timestamped event records | Loki + Grafana |
| **Traces** | End-to-end request journeys | Jaeger, Tempo |

This week covers metrics and logs (traces are an advanced topic).

### Prometheus

Prometheus is an open-source monitoring system built at SoundCloud, now a CNCF project. It:

- **Pulls** (scrapes) metrics from targets at a configurable interval
- Stores metrics as time-series data: `metric_name{labels} value timestamp`
- Provides a query language: **PromQL**
- Fires alerts via **Alertmanager**

### Metric Types

| Type | Description | Example |
|---|---|---|
| **Counter** | Only goes up (resets on restart) | `http_requests_total` |
| **Gauge** | Goes up and down | `memory_usage_bytes` |
| **Histogram** | Samples observations in buckets | `request_duration_seconds` |
| **Summary** | Computes quantiles client-side | `rpc_duration_seconds` |

### How Prometheus Works

```
Your App → /metrics endpoint → Prometheus scrapes it → Stores in TSDB → PromQL queries → Grafana dashboards
```

`/metrics` returns data like:
```
# HELP http_requests_total Total HTTP requests
# TYPE http_requests_total counter
http_requests_total{method="GET",status="200"} 1027
http_requests_total{method="POST",status="500"} 3
```

---

## Lab · ~50 min

### Step 1 — Run Prometheus with Docker Compose

```bash
mkdir -p ~/monitoring-labs
cd ~/monitoring-labs

mkdir -p prometheus

cat > prometheus/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: "prometheus"
    static_configs:
      - targets: ["localhost:9090"]

  - job_name: "node"
    static_configs:
      - targets: ["node-exporter:9100"]

  - job_name: "myapp"
    static_configs:
      - targets: ["app:8080"]
    metrics_path: /metrics
EOF

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

volumes:
  prometheus_data:
EOF

docker compose up -d

# Verify
docker compose ps
curl http://localhost:9090/-/healthy
curl http://localhost:9100/metrics | head -20
```

### Step 2 — Explore the Prometheus UI

Open [http://localhost:9090](http://localhost:9090) in your browser.

Go to **Status → Targets** — you should see `prometheus` and `node` as UP.

In the query box, try these PromQL expressions:

```promql
# Current CPU usage across all cores
rate(node_cpu_seconds_total{mode!="idle"}[5m])

# Total memory available
node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes * 100

# Disk usage percentage
(1 - node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100

# Prometheus itself: rate of samples ingested
rate(prometheus_tsdb_head_samples_appended_total[1m])
```

### Step 3 — Instrument your application

Add Prometheus metrics to the Flask app from Day 25:

```bash
mkdir -p ~/monitoring-labs/app

cat > ~/monitoring-labs/app/app.py << 'EOF'
from flask import Flask, jsonify, Response
from prometheus_client import Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST
import time
import os

app = Flask(__name__)

# Define metrics
REQUEST_COUNT = Counter(
    'http_requests_total',
    'Total HTTP requests',
    ['method', 'endpoint', 'status']
)

REQUEST_DURATION = Histogram(
    'http_request_duration_seconds',
    'HTTP request duration',
    ['endpoint']
)

ACTIVE_REQUESTS = Gauge(
    'http_active_requests',
    'Currently active HTTP requests'
)

@app.before_request
def before_request():
    ACTIVE_REQUESTS.inc()

@app.after_request
def after_request(response):
    ACTIVE_REQUESTS.dec()
    return response

@app.route("/")
def index():
    start = time.time()
    result = jsonify({"message": "Hello!", "version": os.getenv("APP_VERSION", "1.0")})
    duration = time.time() - start
    REQUEST_COUNT.labels(method="GET", endpoint="/", status=200).inc()
    REQUEST_DURATION.labels(endpoint="/").observe(duration)
    return result

@app.route("/health")
def health():
    REQUEST_COUNT.labels(method="GET", endpoint="/health", status=200).inc()
    return jsonify({"status": "ok"})

@app.route("/metrics")
def metrics():
    return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
EOF

cat > ~/monitoring-labs/app/requirements.txt << 'EOF'
flask==3.0.0
prometheus-client==0.19.0
EOF

cat > ~/monitoring-labs/app/Dockerfile << 'EOF'
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py .
EXPOSE 8080
CMD ["python3", "app.py"]
EOF

# Add app to compose
cat >> ~/monitoring-labs/docker-compose.yml << 'EOF'

  app:
    build: ./app
    container_name: myapp
    ports:
      - "8080:8080"
EOF

cd ~/monitoring-labs
docker compose up -d --build

# Generate some traffic
for i in {1..20}; do curl -s http://localhost:8080/ > /dev/null; done
for i in {1..5}; do curl -s http://localhost:8080/health > /dev/null; done

# Check raw metrics
curl http://localhost:8080/metrics
```

### Step 4 — Query application metrics

Back in the Prometheus UI ([http://localhost:9090](http://localhost:9090)):

```promql
# Total requests to the app
http_requests_total

# Request rate per second (last 1 minute)
rate(http_requests_total[1m])

# Average request duration
rate(http_request_duration_seconds_sum[5m]) / rate(http_request_duration_seconds_count[5m])

# Requests by endpoint
sum by (endpoint) (rate(http_requests_total[1m]))
```

---

## Assignment

1. What is the difference between a Counter and a Gauge? Give an example of each from the node-exporter metrics you can see at `http://localhost:9100/metrics`.
2. What does `rate(http_requests_total[5m])` compute? Why can't you use `http_requests_total` directly to see the current request rate?
3. Add an `ERROR_COUNT` Counter to the app that increments on any unhandled exception. Write a `/error` endpoint that raises an exception on purpose. Query the metric in Prometheus.
4. What does `scrape_interval: 15s` mean? What happens if your app takes longer than 15s to respond to Prometheus's scrape request?

---

## Further Reading

- [Prometheus getting started](https://prometheus.io/docs/prometheus/latest/getting_started/)
- [PromQL basics](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [prometheus_client Python library](https://github.com/prometheus/client_python)
