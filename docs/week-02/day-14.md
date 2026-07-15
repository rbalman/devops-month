# Day 7 · Containers III — Docker Compose, Volumes & Networks

> This is where Operation Go Live's web tier becomes **one command**. You have an app image (Day 6), a reverse proxy (Day 4), and you know volumes and networks (Day 5). Today you declare the whole stack — **Nginx → app → Postgres** — in a single file, wire the services together over a private network, keep the database's data in a volume, and bring it all up with `docker compose up`. Reproducible infrastructure, checked into git. That's the finish line for Week 2.

## Learning Objectives

- Define a multi-service application in a **Compose file**
- Wire services together over a **private network** using service-name DNS
- Persist state with **named volumes**; mount config with **bind mounts**
- Order startup and gate on readiness with **`depends_on`** + **healthchecks**
- Manage the stack lifecycle and **scale** a service

---

## Theory · ~20 min

### 1. Why Compose

A real app is several containers — an app, a database, a cache, a proxy. Wiring them by hand with many `docker run` flags is error-prone and impossible to reproduce. **Docker Compose** declares the entire stack in one YAML file you commit to git; `docker compose up` reconciles reality to match it.

### 2. The Compose file

```yaml
services:
  web:                        # service name = its DNS hostname on the network
    image: nginx:alpine
    ports:
      - "8080:80"             # publish host:container
    depends_on:
      - app

  app:
    build: ./app              # build from a Dockerfile instead of pulling
    environment:
      - DB_HOST=db            # reach the 'db' service by name

  db:
    image: postgres:15-alpine
    environment:
      POSTGRES_PASSWORD: secret
    volumes:
      - db_data:/var/lib/postgresql/data   # named volume for persistence

volumes:
  db_data:                    # declared here, managed by Docker
```

!!! note "No `version:` key anymore"
    The modern Compose Specification dropped the top-level `version:` field — the old `version: "3.9"` line is legacy and ignored by Compose v2. Just start with `services:`.

### 3. Networking in Compose

Compose puts every service on a **default network** and gives each a DNS name equal to its service name — so `app` reaches the database at host `db`, no IPs required. For real isolation, define **multiple networks** and attach each service only where it belongs:

```
        frontend net           backend net
Client ─▶ nginx ─▶ app ────────────▶ db
                   (on both)     (backend only)
```

Put `db` on the **backend** network only, and Nginx — on **frontend** — literally cannot reach it. Isolation by topology, not by firewall rules.

### 4. Volumes vs bind mounts

| | Bind mount | Named volume |
|---|---|---|
| Location | A path **you** choose on the host | Managed by Docker |
| Best for | Config & live code in dev | Databases & app **data** in prod |
| Portability | Tied to the host's paths | Portable across machines |
| Example | `./nginx.conf:/etc/nginx/...:ro` | `db_data:/var/lib/postgresql/data` |

### 5. Startup order and health

`depends_on` controls **start order** but, by itself, does **not** wait for a service to be *ready* — Postgres's container can be "started" seconds before it accepts connections. Pair it with a **healthcheck** and `condition: service_healthy` so your app only starts once the database truly answers:

```yaml
db:
  healthcheck:
    test: ["CMD-SHELL", "pg_isready -U admin -d golive"]
    interval: 5s
    timeout: 3s
    retries: 5
app:
  depends_on:
    db:
      condition: service_healthy
```

---

## Lab · ~50 min

Work **inside your Vagrant VM**. Reuse the app from Day 6 (or recreate it below).

### Step 1 — Install the Compose plugin

```bash
sudo apt update && sudo apt install -y docker-compose-plugin
docker compose version                 # note: 'docker compose' (v2), not 'docker-compose'
```

### Step 2 — Lay out the stack

```bash
mkdir -p ~/golive-stack/app ~/golive-stack/nginx && cd ~/golive-stack

# --- the app (Flask + a DB check) ---
cat > app/app.py << 'EOF'
from flask import Flask, jsonify
import os, socket, psycopg2

app = Flask(__name__)

@app.get("/")
def index():
    return jsonify(service="golive", host=socket.gethostname(),
                   env=os.getenv("APP_ENV", "development"))

@app.get("/db")
def db():
    conn = psycopg2.connect(
        host=os.getenv("DB_HOST", "db"), dbname=os.getenv("DB_NAME", "golive"),
        user=os.getenv("DB_USER", "admin"), password=os.getenv("DB_PASS", "secret"))
    cur = conn.cursor(); cur.execute("SELECT version();")
    v = cur.fetchone()[0]; conn.close()
    return jsonify(connected_to=v)

@app.get("/health")
def health():
    return jsonify(status="ok")

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000)
EOF

cat > app/requirements.txt << 'EOF'
flask==3.0.0
psycopg2-binary==2.9.9
EOF

cat > app/Dockerfile << 'EOF'
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py .
EXPOSE 8000
CMD ["python3", "app.py"]
EOF

# --- nginx reverse proxy (same idea as Day 4) ---
cat > nginx/default.conf << 'EOF'
server {
    listen 80;
    location / {
        proxy_pass http://app:8000;          # 'app' resolves via Compose DNS
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
EOF
```

### Step 3 — Write the Compose file

```bash
cat > docker-compose.yml << 'EOF'
services:
  nginx:
    image: nginx:alpine
    ports:
      - "8080:80"
    volumes:
      - ./nginx/default.conf:/etc/nginx/conf.d/default.conf:ro   # bind mount config
    depends_on:
      - app
    networks:
      - frontend

  app:
    build: ./app
    environment:
      APP_ENV: development
      DB_HOST: db
      DB_NAME: golive
      DB_USER: admin
      DB_PASS: secret
    depends_on:
      db:
        condition: service_healthy      # wait until Postgres is truly ready
    networks:
      - frontend
      - backend

  db:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: golive
      POSTGRES_USER: admin
      POSTGRES_PASSWORD: secret
    volumes:
      - db_data:/var/lib/postgresql/data   # named volume — data persists
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U admin -d golive"]
      interval: 5s
      timeout: 3s
      retries: 5
    networks:
      - backend

volumes:
  db_data:

networks:
  frontend:
  backend:
EOF
```

### Step 4 — Bring it up

```bash
docker compose up -d --build        # build the app image, start all three services
docker compose ps                   # STATUS should show healthy/running
docker compose logs -f app          # Ctrl+C to stop following

curl http://localhost:8080          # through Nginx → app
curl http://localhost:8080/db       # app → Postgres, over the private network
```

### Step 5 — Prove persistence

```bash
# Write a row into the database
docker compose exec db psql -U admin -d golive \
  -c "CREATE TABLE t(msg text); INSERT INTO t VALUES ('i persist');"

docker compose down                 # stop & remove containers — but NOT the volume
docker compose up -d
docker compose exec db psql -U admin -d golive -c "SELECT * FROM t;"   # still there ✅
```

!!! warning "`down -v` deletes your data"
    `docker compose down` removes containers and networks but keeps named volumes. `docker compose down -v` **also deletes the volumes** — your database is gone. Never run `-v` against a stack holding data you care about.

### Step 6 — Prove network isolation

```bash
docker network ls | grep golive-stack          # find the exact network names

# 'app' is on backend → it can resolve 'db'
docker run --rm --network golive-stack_backend  alpine nslookup db   # resolves
# a container on 'frontend' only → cannot
docker run --rm --network golive-stack_frontend alpine nslookup db   # fails to resolve
```

Nginx sits on `frontend` and genuinely has no route to the database. If the proxy is ever compromised, the DB isn't one hop away.

### Step 7 — Lifecycle & scaling

```bash
docker compose stop                 # pause everything (containers kept)
docker compose start                # resume
docker compose up -d --build        # rebuild after a code change and reconcile

docker compose up -d --scale app=3  # three app replicas behind Nginx
docker compose ps                   # see app-1, app-2, app-3
# Nginx load-balances across them via Compose's DNS round-robin
for i in $(seq 6); do curl -s http://localhost:8080 | grep -o '"host":"[^"]*"'; done

docker compose down                 # tear it all down (add -v to also drop the volume)
```

---

## Advanced Topics

- **Profiles** — group optional services (e.g. a `debug` toolbox) and start them only when asked → [docs.docker.com — Profiles](https://docs.docker.com/compose/profiles/)
- **Override files & `.env`** — layer `compose.override.yml` for dev vs prod, and pull secrets/config from a `.env` file → [docs.docker.com — Multiple Compose files](https://docs.docker.com/compose/multiple-compose-files/)
- **Compose secrets** — mount sensitive values as files instead of environment variables → [docs.docker.com — Secrets in Compose](https://docs.docker.com/compose/use-secrets/)
- **Resource limits & restart policies** — cap CPU/memory and auto-restart crashed services with `deploy.resources` and `restart` → [Compose deploy reference](https://docs.docker.com/compose/compose-file/deploy/)
- **From Compose to production** — the same model scales up to Docker Swarm and Kubernetes when one host isn't enough → [kubernetes.io — Basics](https://kubernetes.io/docs/tutorials/kubernetes-basics/)

---

## Assignment

1. **Add a cache and lock it down.** Extend the stack with a **Redis** service (`redis:7-alpine`) on the **backend** network only, and add a `/cache` endpoint (or just wire the `REDIS_HOST` env — a code change is optional). Give **every** service a healthcheck. Then prove your network isolation: show that the `app` container can reach both `db` and `redis`, but `nginx` can reach **neither**. Paste your final `docker-compose.yml` and the commands/output that prove isolation.

2. **Make it reproducible.** Move all secrets (DB password, etc.) out of `docker-compose.yml` into a **`.env`** file, keep the database on a **named volume**, and add a **`Makefile`** with `up`, `down`, `logs`, and `rebuild` targets. Prove the data survives a `make down && make up` cycle. *Stretch:* scale `app` to 3 replicas, hit Nginx a dozen times, and show requests fanning out across all three container hostnames — then explain the difference between `docker compose down` and `docker compose down -v` from what you observed.

---

## Further Reading

- [Compose file reference](https://docs.docker.com/compose/compose-file/) — every key, precisely defined
- [Docker networking overview](https://docs.docker.com/network/) — bridge, host, and user-defined networks
- [Manage data in Docker](https://docs.docker.com/storage/) — volumes, bind mounts, and tmpfs compared
- [The Twelve-Factor App](https://12factor.net/) — the design principles behind container-ready services
