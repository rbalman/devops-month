# Day 13 · Containers II — Dockerfile & Building Images

## Learning Objectives

- Write a Dockerfile to package an application
- Build, tag, and push images to a registry
- Understand image layers and how to keep images small

---

## Theory · ~20 min

### The Dockerfile

A Dockerfile is a text file with instructions that Docker reads top-to-bottom to build an image. Each instruction creates a new **layer** in the image.

```dockerfile
FROM ubuntu:22.04          # base image
RUN apt-get update         # creates layer 2
RUN apt-get install nginx  # creates layer 3
COPY index.html /var/www/  # creates layer 4
CMD ["nginx", "-g", "daemon off;"]  # what runs when container starts
```

### Key Dockerfile Instructions

| Instruction | Purpose |
|---|---|
| `FROM` | Base image to build on (always first) |
| `RUN` | Execute a shell command during build |
| `COPY` | Copy files from host into image |
| `ADD` | Like COPY but can untar and fetch URLs |
| `WORKDIR` | Set working directory for subsequent instructions |
| `ENV` | Set environment variables |
| `EXPOSE` | Document which port the container listens on |
| `CMD` | Default command to run when container starts |
| `ENTRYPOINT` | Main command (CMD becomes its arguments) |

### Image Layers and Caching

Docker caches each layer. If a layer hasn't changed, it reuses the cached version — making rebuilds fast.

**Order matters**: Put instructions that change frequently (like `COPY . .`) after instructions that change rarely (like `RUN apt-get install`). Otherwise every code change invalidates the package install cache.

```dockerfile
# BAD — code change invalidates the apt cache
COPY . .
RUN apt-get install -y python3

# GOOD — install packages first, copy code last
RUN apt-get install -y python3
COPY . .
```

### Keeping Images Small

Small images = faster pulls, smaller attack surface:

- Use `alpine` or `slim` base images
- Combine `RUN` commands with `&&` and `\` to reduce layers
- Use `.dockerignore` to exclude files
- Use multi-stage builds (copy only what's needed to the final image)

---

## Lab · ~50 min

### Step 1 — Write your first Dockerfile

```bash
mkdir -p ~/docker-labs/myapp
cd ~/docker-labs/myapp

# Create a simple Python web app
cat > app.py << 'EOF'
from http.server import HTTPServer, BaseHTTPRequestHandler
import json
import os

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        response = {
            "message": "Hello from Docker!",
            "hostname": os.environ.get("HOSTNAME", "unknown"),
            "version": os.environ.get("APP_VERSION", "1.0")
        }
        self.wfile.write(json.dumps(response).encode())

    def log_message(self, format, *args):
        pass  # silence request logs

if __name__ == "__main__":
    server = HTTPServer(("", 8080), Handler)
    print("Server running on port 8080")
    server.serve_forever()
EOF

# Create the Dockerfile
cat > Dockerfile << 'EOF'
FROM python:3.11-slim

WORKDIR /app

COPY app.py .

EXPOSE 8080

ENV APP_VERSION=1.0

CMD ["python3", "app.py"]
EOF

# Create .dockerignore
cat > .dockerignore << 'EOF'
*.pyc
__pycache__/
.git/
*.md
EOF
```

### Step 2 — Build and run

```bash
# Build the image
docker build -t myapp:1.0 .

# See what was built
docker images | grep myapp

# Check the layers
docker history myapp:1.0

# Run it
docker run -d -p 8080:8080 --name myapp myapp:1.0

# Test it
curl http://localhost:8080
```

### Step 3 — Observe layer caching

```bash
# Change the app code slightly
echo "# comment" >> app.py

# Rebuild — watch which layers are cached (CACHED) vs rebuilt
docker build -t myapp:1.1 .

# Now add a dependency and see cache invalidation
cat > requirements.txt << 'EOF'
requests==2.31.0
EOF

# Update Dockerfile to use requirements.txt
cat > Dockerfile << 'EOF'
FROM python:3.11-slim

WORKDIR /app

# Install dependencies FIRST (cache-friendly)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy app code LAST (changes often)
COPY app.py .

EXPOSE 8080
ENV APP_VERSION=2.0

CMD ["python3", "app.py"]
EOF

docker build -t myapp:2.0 .    # First build: all layers run
docker build -t myapp:2.0 .    # Second build: pip install is CACHED
```

### Step 4 — Multi-stage build

Multi-stage builds let you compile in one image and copy only the result to a clean final image:

```bash
mkdir -p ~/docker-labs/multistage
cd ~/docker-labs/multistage

cat > Dockerfile << 'EOF'
# Stage 1: Build (heavy image with build tools)
FROM golang:1.21 AS builder

WORKDIR /build

RUN echo 'package main
import (
    "fmt"
    "net/http"
)
func main() {
    http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
        fmt.Fprintln(w, "Hello from Go in Docker!")
    })
    http.ListenAndServe(":8080", nil)
}' > main.go

RUN CGO_ENABLED=0 go build -o server main.go

# Stage 2: Final (tiny image with just the binary)
FROM scratch

COPY --from=builder /build/server /server

EXPOSE 8080
ENTRYPOINT ["/server"]
EOF

docker build -t go-server:1.0 .
docker images | grep go-server   # see how tiny it is

docker run -d -p 8080:8080 --name go-server go-server:1.0
curl http://localhost:8080

docker stop go-server && docker rm go-server
```

### Step 5 — Push to Docker Hub

```bash
# Create a free account at hub.docker.com first

# Log in
docker login

# Tag your image with your username
docker tag myapp:2.0 <your-dockerhub-username>/myapp:2.0

# Push
docker push <your-dockerhub-username>/myapp:2.0

# Now anyone can pull it
docker pull <your-dockerhub-username>/myapp:2.0
```

---

## Assignment

In `my-progress/day-13.md`:

1. What is a Docker layer? Why does layer order matter for build performance?
2. What is the difference between `CMD` and `ENTRYPOINT`? When would you use each?
3. Extend the `myapp` Dockerfile to accept an `APP_ENV` environment variable (development/production) and print it in the JSON response. Build and test it.
4. What does `.dockerignore` do? What would happen if you accidentally copied a `.git/` directory or `.env` file into an image?

---

## Further Reading

- [Dockerfile best practices](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)
- [Docker multi-stage builds](https://docs.docker.com/build/building/multi-stage/)
- [Dive — tool for inspecting image layers](https://github.com/wagoodman/dive)
