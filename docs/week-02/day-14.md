# Day 14 · Docker Compose — Multi-Container Apps

## Learning Objectives

- Run multi-container applications with Docker Compose
- Configure volumes for persistent data and bind mounts for development
- Understand container networking (how containers talk to each other)

---

## Theory · ~20 min

### Why Docker Compose?

A real application rarely runs in a single container. You'll typically have:

- **App container** — your Python/Node/Go service
- **Database container** — Postgres, MySQL, or MongoDB
- **Cache container** — Redis
- **Reverse proxy** — Nginx

Managing these with individual `docker run` commands is error-prone and hard to reproduce. **Docker Compose** lets you define and manage the entire stack in a single YAML file.

### docker-compose.yml Structure

```yaml
version: "3.9"   # compose file version

services:
  web:           # service name (also its DNS hostname on the network)
    image: nginx:alpine
    ports:
      - "80:80"
    volumes:
      - ./html:/usr/share/nginx/html
    depends_on:
      - app

  app:
    build: ./app     # build from a Dockerfile in ./app
    environment:
      - DB_HOST=db   # refers to the 'db' service below
    restart: unless-stopped

  db:
    image: postgres:15
    environment:
      POSTGRES_PASSWORD: secret
    volumes:
      - db_data:/var/lib/postgresql/data

volumes:
  db_data:         # named volume (persists between restarts)
```

### Container Networking in Compose

Compose creates a **default bridge network** for all services in the file. Services can reach each other by their **service name** as a hostname:

```python
# In 'app' container, connect to 'db' container:
conn = psycopg2.connect(host="db", port=5432, ...)
```

No IP addresses needed — Docker's embedded DNS resolves service names.

### Volumes vs Bind Mounts

| | Bind Mount | Named Volume |
|---|---|---|
| Location | Specific path on host | Managed by Docker |
| Use case | Dev (live code reload) | Production data persistence |
| Portability | Host-path dependent | Portable |
| Example | `./app:/app` | `db_data:/var/lib/postgresql/data` |

---

## Lab · ~50 min

### Step 1 — Install Docker Compose

```bash
# Compose v2 is bundled with Docker Desktop
# On Linux, install the plugin:
sudo apt install -y docker-compose-plugin

docker compose version
```

### Step 2 — A simple Nginx + app stack

```bash
mkdir -p ~/docker-labs/compose-demo
cd ~/docker-labs/compose-demo

# Create the app
mkdir -p app
cat > app/app.py << 'EOF'
from flask import Flask, jsonify
import os, socket

app = Flask(__name__)

@app.route("/")
def index():
    return jsonify({
        "service": "app",
        "hostname": socket.gethostname(),
        "env": os.getenv("APP_ENV", "development")
    })

@app.route("/health")
def health():
    return jsonify({"status": "ok"})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
EOF

cat > app/requirements.txt << 'EOF'
flask==3.0.0
EOF

cat > app/Dockerfile << 'EOF'
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py .
EXPOSE 5000
CMD ["python3", "app.py"]
EOF

# Nginx config
mkdir -p nginx
cat > nginx/default.conf << 'EOF'
server {
    listen 80;

    location / {
        proxy_pass http://app:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location /health {
        proxy_pass http://app:5000/health;
    }
}
EOF

# The Compose file
cat > docker-compose.yml << 'EOF'
services:
  nginx:
    image: nginx:alpine
    ports:
      - "8080:80"
    volumes:
      - ./nginx/default.conf:/etc/nginx/conf.d/default.conf:ro
    depends_on:
      - app

  app:
    build: ./app
    environment:
      - APP_ENV=development
    restart: unless-stopped
EOF
```

### Step 3 — Start and inspect the stack

```bash
# Start everything (build images if needed)
docker compose up -d

# See running containers
docker compose ps

# See logs from all services
docker compose logs

# Follow logs from a specific service
docker compose logs -f app

# Test the app through nginx
curl http://localhost:8080
curl http://localhost:8080/health
```

### Step 4 — Add a database

```bash
cat > docker-compose.yml << 'EOF'
services:
  nginx:
    image: nginx:alpine
    ports:
      - "8080:80"
    volumes:
      - ./nginx/default.conf:/etc/nginx/conf.d/default.conf:ro
    depends_on:
      - app

  app:
    build: ./app
    environment:
      - APP_ENV=development
      - DB_HOST=db
      - DB_PORT=5432
      - DB_NAME=devops
      - DB_USER=admin
      - DB_PASS=secret
    restart: unless-stopped
    depends_on:
      - db

  db:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: devops
      POSTGRES_USER: admin
      POSTGRES_PASSWORD: secret
    volumes:
      - db_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"   # exposed so you can connect from host

volumes:
  db_data:
EOF

docker compose up -d

# Check logs
docker compose logs db

# Connect to the database from the host
docker compose exec db psql -U admin -d devops -c "\l"

# Connect from the app container
docker compose exec app bash -c "apt-get install -y postgresql-client -q && psql -h db -U admin -d devops -c '\l'"
```

### Step 5 — Compose management commands

```bash
# Stop services (keep containers and volumes)
docker compose stop

# Start stopped services
docker compose start

# Stop and remove containers (keep volumes)
docker compose down

# Stop, remove containers AND volumes (data is gone!)
docker compose down -v

# Rebuild images after code changes
docker compose build
docker compose up -d --build   # rebuild and restart

# Scale a service to multiple replicas
docker compose up -d --scale app=3   # run 3 app containers
docker compose ps
```

---

## Assignment

Extend the stack in `~/docker-labs/compose-demo`:

1. Add a **Redis** service to the Compose file (image: `redis:7-alpine`)
2. Update the `app` service to connect to Redis (you can just add the env vars; no code change needed)
3. Add a **healthcheck** to the `app` service that curls `/health` every 30 seconds
4. Write a `Makefile` (or shell script) with targets: `up`, `down`, `logs`, `rebuild`

In `my-progress/day-14.md`, answer:
- What is the difference between `docker compose down` and `docker compose down -v`?
- What does `depends_on` guarantee? What doesn't it guarantee?

---

## Further Reading

- [Docker Compose file reference](https://docs.docker.com/compose/compose-file/)
- [Docker networking overview](https://docs.docker.com/network/)
- [12-factor app methodology](https://12factor.net/) — principles for container-ready apps
