# Day 6 · Monitoring & Alerting

> A live, self-deploying app is great — but if it falls over at 3 a.m., **you'd find out from an angry user.** The discipline of observability is knowing what your system is doing *before* anyone else does. This stands up the classic open-source stack — **Prometheus** for metrics, **Loki** for logs, **Grafana** as the single pane of glass — and wires an **alert to Discord** so a problem pages you, not your users. The moving parts are kept few on purpose: three stores, one UI, one notification channel.

!!! info "Where this fits"
    This assumes the end-to-end app (frontend + backend + Postgres) from [Deploy a Full-Stack AWS Project](day-26.md) is running — this is how you watch it. Securing it is covered in [Security Best Practices](day-28.md).

## Learning Objectives

- Distinguish the three pillars — **metrics**, **logs**, and traces — and when each helps
- Run **Prometheus + Loki + Grafana** with collectors, in one Compose stack
- Use **Grafana** as one UI: build a **dashboard**, query **logs** in Explore, define **alerts**
- Send a firing alert to **Discord** via a contact point
- **Lab:** monitor the app host, view its container logs, and trigger a real Discord alert

---

## Prerequisites

- **Day 5 complete** — the end-to-end app running on its EC2
- A host with **Docker + Compose** to run the monitoring stack (the same EC2 is fine for the lab)
- A **Discord server** where you can create a webhook (Server Settings → Integrations → Webhooks)

---

## Theory · ~30 min

### 1. The three pillars of observability

You can't fix what you can't see. Three kinds of signal, each answering a different question:

| Pillar | What it is | Answers | Tool here |
|---|---|---|---|
| **Metrics** | Numbers over time (CPU %, request rate, error count) | "*Is* something wrong, and how much?" | **Prometheus** |
| **Logs** | Timestamped text events | "*What* happened, exactly?" | **Loki** |
| **Traces** | A request's path across services | "*Where* in the chain did it slow down?" | (out of scope) |

The workflow: a **metric** alert tells you something's wrong → you open the **logs** to see what → (in bigger systems) a **trace** shows where. This lab wires the first two and views both through Grafana.

### 2. The stack — few moving parts, on purpose

```text
   ┌── node_exporter ──┐   (host metrics: CPU, mem, disk)
   ├── cAdvisor ───────┤   (container metrics)
   │                   ▼
   │            ┌─────────────┐   scrapes  ┌──────────┐
   │            │ Prometheus  │◀───────────┤  targets  │
   │            └──────┬──────┘             └──────────┘
   │                   │
   └── Alloy ──▶ Loki ─┤            metrics + logs
       (tails          │                   │
        container      ▼                   ▼
        logs)     ┌──────────────────────────────┐
                  │           Grafana            │  ◀── you
                  │  dashboards · Explore · alerts│
                  └───────────────┬──────────────┘
                                  │ alert fires
                                  ▼
                               Discord
```

| Component | Role |
|---|---|
| **Prometheus** | Pulls (**scrapes**) metrics from targets every few seconds and stores them |
| **node_exporter** | Exposes host metrics (CPU, memory, disk) |
| **cAdvisor** | Exposes per-container metrics (your frontend/backend/postgres) |
| **Loki** | Stores logs — "Prometheus, but for logs" (label-based, cheap) |
| **Grafana Alloy** | The log collector — tails container logs and ships them to Loki |
| **Grafana** | One UI over both stores: dashboards, log search, and alerting |

!!! warning "Promtail is dead — use Alloy"
    Older tutorials use **Promtail** to ship logs to Loki. Promtail reached **end-of-life in March 2026** and is unsupported. Its replacement is **Grafana Alloy** — a single collector for logs, metrics, and traces (built on the OpenTelemetry Collector). This course uses Alloy.

### 3. Grafana as the single pane of glass

Grafana doesn't store anything — it **queries** stores you register as **data sources** (Prometheus for metrics, Loki for logs). From one UI you get **dashboards** (PromQL graphs), **Explore** (ad-hoc queries incl. **log search** with LogQL), and **alerting**. Metrics, logs, *and* alerts from one tool — that's what keeps the moving parts few.

### 4. How alerting works

Grafana **unified alerting** has four parts:

```text
Alert rule ──evaluates a query every N sec──▶ [ OK → Pending → Firing ]
                                                            │
                                       routed by a notification policy
                                                            ▼
                                            Contact point (Discord webhook)
```

- **Alert rule** — a query + condition (e.g. `up == 0` for 1 minute).
- **Pending → Firing** — it must stay true for the "for" duration before firing (avoids flapping).
- **Contact point** — where a firing alert goes; Grafana has a **built-in Discord type** — paste a webhook URL, done.

No separate Alertmanager to run — Grafana handles evaluation *and* notification.

---

## Lab · ~45 min

Stand up the stack, watch your host and containers, read their logs, and fire a Discord alert.

### 1. The monitoring stack

In a `monitoring/` folder, **`docker-compose.yml`**:

```yaml
services:
  prometheus:
    image: prom/prometheus:v3.13.1
    volumes: ["./prometheus.yml:/etc/prometheus/prometheus.yml:ro"]
    ports: ["9090:9090"]

  node-exporter:
    image: prom/node-exporter:latest
    ports: ["9100:9100"]

  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
    ports: ["8080:8080"]

  loki:
    image: grafana/loki:3.6.0
    ports: ["3100:3100"]

  alloy:
    image: grafana/alloy:latest
    volumes:
      - ./config.alloy:/etc/alloy/config.alloy:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
    command: run /etc/alloy/config.alloy

  grafana:
    image: grafana/grafana:13.0.0
    ports: ["3000:3000"]
    volumes:
      - ./grafana/provisioning:/etc/grafana/provisioning:ro
    environment:
      GF_SECURITY_ADMIN_PASSWORD: admin
```

### 2. Prometheus scrape config

**`monitoring/prometheus.yml`**:

```yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: prometheus
    static_configs: [{ targets: ["localhost:9090"] }]
  - job_name: node
    static_configs: [{ targets: ["node-exporter:9100"] }]
  - job_name: cadvisor
    static_configs: [{ targets: ["cadvisor:8080"] }]
```

### 3. Alloy — ship container logs to Loki

**`monitoring/config.alloy`** — discover Docker containers, tail their logs, write to Loki:

```river
discovery.docker "containers" {
  host = "unix:///var/run/docker.sock"
}

loki.source.docker "logs" {
  host       = "unix:///var/run/docker.sock"
  targets    = discovery.docker.containers.targets
  forward_to = [loki.write.default.receiver]
}

loki.write "default" {
  endpoint { url = "http://loki:3100/loki/api/v1/push" }
}
```

### 4. Auto-provision Grafana's data sources

**`monitoring/grafana/provisioning/datasources/ds.yml`**:

```yaml
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    url: http://prometheus:9090
    isDefault: true
  - name: Loki
    type: loki
    url: http://loki:3100
```

### 5. Bring it up

```bash
cd monitoring && docker compose up -d
```

Open Grafana at `http://<host>:3000` (login `admin` / `admin`). Both data sources are already connected (**Connections → Data sources**).

### 6. A dashboard

Don't build from scratch — import a community one. **Dashboards → New → Import**, enter ID **1860** (Node Exporter Full), pick the Prometheus data source. You now have CPU, memory, disk, and network for your host, live.

### 7. Query container logs in Explore

**Explore** (compass icon) → select **Loki** → run a LogQL query for your backend:

```logql
{container="backend"}      # logs from the API container
```

Hit your app a few times (`curl http://<public_ip>/api/healthz`) and watch the request logs stream in — metrics and logs, same UI. Try `{container="postgres"}` too.

### 8. Alert to Discord

**Create the contact point:** in Discord, make a webhook (Server Settings → Integrations → Webhooks → copy URL). In Grafana: **Alerting → Contact points → Add** → type **Discord** → paste the webhook URL → **Test** (a message appears in Discord).

**Create a rule:** **Alerting → Alert rules → New**. Use a query that will fire — e.g. a scrape target being down:

```promql
up{job="node"} == 0
```

Set **for = 1m**, point it at your Discord contact point, save. Now trigger it:

```bash
docker compose stop node-exporter      # the target goes down
```

Within ~a minute the rule goes **Pending → Firing** and a message lands in Discord. Start it again (`docker compose start node-exporter`) and Grafana sends the **resolved** notice.

!!! success "You closed the loop"
    Metrics, logs, dashboards, and a real alert to Discord — your system now tells *you* when something's wrong. That's production-grade observability from open-source parts.

---

## Advanced Topics

- **postgres_exporter** — database metrics (connections, query rates) into Prometheus → [postgres_exporter](https://github.com/prometheus-community/postgres_exporter)
- **Alertmanager** — Prometheus-native routing/grouping/silencing if you outgrow Grafana alerting → [Alertmanager](https://prometheus.io/docs/alerting/latest/alertmanager/)
- **PromQL & LogQL** — the query languages behind dashboards and log search → [PromQL](https://prometheus.io/docs/prometheus/latest/querying/basics/) · [LogQL](https://grafana.com/docs/loki/latest/query/)
- **SLOs & error budgets** — alert on user-facing objectives, not raw CPU → [Google SRE — SLOs](https://sre.google/workbook/implementing-slos/)
- **Traces** — the third pillar with Grafana **Tempo** + OpenTelemetry → [Tempo](https://grafana.com/docs/tempo/latest/)

---

## Assignment

Monitor the app you built, not just the host.

**Part 1 — An app dashboard + alert.** Add an alert that fires when **the app itself is unreachable** — either scrape a `/metrics` endpoint from the backend, or add a **blackbox** check that probes `http://<public_ip>/api/healthz`. Route it to Discord. Trigger it (stop the backend container) and capture the Discord message.

**Part 2 — Logs to the rescue.** Cause an error in the app (e.g. break the `DATABASE_URL` and redeploy). Use Grafana **Explore** on Loki to **find the error log line** from the backend container, then fix it. Screenshot the failing log query and the recovery.

**Submit:** the `monitoring/` stack files, a screenshot of your dashboard, the **Discord alert** (firing + resolved), and the Explore log query that caught your induced error.

!!! danger "Stop the stack when done"
    `docker compose down` on the monitoring stack, and `terraform destroy` on the app if you're not continuing to Day 7 soon.

---

## Further Reading

**Watch**

- 📺 [Prometheus Monitoring — Beginners Tutorial](https://youtu.be/h4Sl21AKiDg) — TechWorld with Nana; metrics, scraping, and Grafana
- 📺 [Grafana Loki explained](https://youtu.be/1uk8LtQqsZQ) — logs the Loki way

**Reference**

- [Prometheus — Getting started](https://prometheus.io/docs/prometheus/latest/getting_started/) · [Grafana — Data sources](https://grafana.com/docs/grafana/latest/datasources/)
- [Grafana Loki — docs](https://grafana.com/docs/loki/latest/) · [Grafana Alloy — docs](https://grafana.com/docs/alloy/latest/)
- [Grafana — Alerting](https://grafana.com/docs/grafana/latest/alerting/) · [Discord contact point](https://grafana.com/docs/grafana/latest/alerting/configure-notifications/manage-contact-points/integrations/configure-discord/)
- [node_exporter](https://github.com/prometheus/node_exporter) · [cAdvisor](https://github.com/google/cadvisor)
