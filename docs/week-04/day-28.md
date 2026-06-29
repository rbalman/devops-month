# Day 28 · Grafana Dashboards & Alerting

## Learning Objectives

- Build Grafana dashboards from Prometheus metrics and Loki logs
- Configure alert rules and notification channels
- Send alerts to Discord when something goes wrong

---

## Theory · ~20 min

### Why Dashboards?

Raw metrics and logs are useful for debugging, but dashboards give you:
- At-a-glance health of all your systems
- Trend visibility over time
- Shared context with your team
- A starting point for incident response

A good dashboard answers the question: **"Is my service healthy right now?"** in under 3 seconds.

### The USE Method (for infrastructure)

When building dashboards for infrastructure, follow the USE method:
- **Utilization** — How busy is the resource? (CPU 72%)
- **Saturation** — How much extra work is queued? (queue depth)
- **Errors** — Is it failing? (error rate)

### The RED Method (for services)

For application services:
- **Rate** — How many requests per second?
- **Errors** — What fraction of requests fail?
- **Duration** — How long do requests take?

These two frameworks cover 90% of what you need to monitor.

### Alerting Concepts

An alert fires when a **condition** is met for a **duration**:

```yaml
alert: HighErrorRate
expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.01
for: 2m
labels:
  severity: critical
annotations:
  summary: "High error rate detected"
  description: "Error rate is {{ $value | humanizePercentage }}"
```

`for: 2m` = the condition must be true for 2 minutes before firing. This prevents alert storms from brief spikes.

---

## Lab · ~50 min

### Step 1 — Add Grafana to the stack

```bash
cd ~/monitoring-labs

mkdir -p grafana/provisioning/{datasources,dashboards}

# Provision datasources automatically
cat > grafana/provisioning/datasources/datasources.yml << 'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true

  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
    editable: true
EOF

# Add Grafana to docker-compose
cat >> docker-compose.yml << 'EOF'

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=devops123
      - GF_USERS_ALLOW_SIGN_UP=false
    volumes:
      - ./grafana/provisioning:/etc/grafana/provisioning:ro
      - grafana_data:/var/lib/grafana
    depends_on:
      - prometheus
      - loki
EOF

# Add the volume to the volumes section
# (manually add 'grafana_data:' to the volumes block)

docker compose up -d grafana
```

Open [http://localhost:3000](http://localhost:3000) — login: `admin` / `devops123`

### Step 2 — Build a dashboard manually

In Grafana UI:

1. Click **+** → **New Dashboard** → **Add visualization**
2. Select **Prometheus** as the data source
3. Add these panels one by one:

**Panel 1: Request Rate**
```promql
sum(rate(http_requests_total[5m]))
```
Type: Time series

**Panel 2: Error Rate**
```promql
sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m])) * 100
```
Type: Gauge, unit: Percent

**Panel 3: Average Request Duration**
```promql
rate(http_request_duration_seconds_sum[5m]) / rate(http_request_duration_seconds_count[5m])
```
Type: Time series, unit: Seconds

**Panel 4: CPU Usage**
```promql
100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
```
Type: Gauge, unit: Percent

**Panel 5: Log stream**
- Data source: Loki
- Query: `{container="myapp"}`
- Type: Logs

Save the dashboard as "DevOps Month — App Overview"

### Step 3 — Import a community dashboard

1. Go to [grafana.com/grafana/dashboards](https://grafana.com/grafana/dashboards)
2. Search for "Node Exporter Full" (dashboard ID: **1860**)
3. In Grafana: **+** → **Import** → Enter ID `1860` → Load → Select Prometheus → Import

This gives you a complete infrastructure dashboard instantly.

### Step 4 — Set up Discord alerts

```bash
# First: create a Discord webhook
# In Discord: Server Settings → Integrations → Webhooks → New Webhook
# Copy the webhook URL

# In Grafana: Alerting → Contact points → Add contact point
# Name: Discord
# Type: Discord
# Webhook URL: paste your Discord webhook URL
# Test it!
```

Now create an alert rule in Grafana:

1. Go to **Alerting → Alert rules → New alert rule**
2. Name: "High Request Rate"
3. Query A: `sum(rate(http_requests_total[1m]))`
4. Condition: IS ABOVE `5`
5. Evaluation interval: 1m, Pending period: 1m
6. Add labels: `severity=warning`
7. Save

Generate traffic to trigger it:
```bash
for i in {1..100}; do curl -s http://localhost:8080/ > /dev/null; done
```

Watch for the Discord notification!

### Step 5 — Export dashboard as JSON

Grafana dashboards can be stored as code — version controlled just like your Ansible playbooks:

1. Open your dashboard → settings icon (top right)
2. **JSON Model** → Copy JSON
3. Save it:

```bash
cat > ~/monitoring-labs/grafana/provisioning/dashboards/app-overview.json << 'EOF'
{PASTE THE JSON HERE}
EOF

# Configure Grafana to auto-load dashboards from this directory
cat > ~/monitoring-labs/grafana/provisioning/dashboards/dashboards.yml << 'EOF'
apiVersion: 1
providers:
  - name: default
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    options:
      path: /etc/grafana/provisioning/dashboards
EOF
```

---

## Assignment

In `my-progress/day-28.md`:

1. Build a complete dashboard with at least 5 panels covering both metrics (Prometheus) and logs (Loki). Export the JSON and commit it to your repo.
2. Set up a Discord alert that fires when memory usage goes above 80%. Test it by triggering the condition.
3. What is the `for: 2m` duration in an alert rule? Why is it important?
4. What is the difference between "Alerting" and "Monitoring"? Can you have one without the other?

```bash
cp ~/monitoring-labs/grafana/provisioning/dashboards/*.json my-progress/dashboards/
git add my-progress/
git commit -m "day-28: grafana dashboards and alerting"
git push origin main
```

---

## Further Reading

- [Grafana getting started](https://grafana.com/docs/grafana/latest/getting-started/)
- [Grafana alerting](https://grafana.com/docs/grafana/latest/alerting/)
- [Dashboard best practices](https://grafana.com/docs/grafana/latest/dashboards/build-dashboards/best-practices/)
