# Day 6 · Containers II — Building Images & Registries

> Yesterday you *ran* other people's images. Today you build **your own** — you'll package the Operation Go Live app into an image, shrink it, tag it with a real version, and push it to a registry so any machine on earth can pull and run it with one command. This is the moment your app stops being "files on a VM" and becomes a **portable artifact**.

## Learning Objectives

- Write a **Dockerfile** that packages an application
- Understand image **layers** and how the **build cache** makes rebuilds fast
- Choose correctly between **`CMD`** and **`ENTRYPOINT`**
- Shrink images with **slim/alpine** bases, **multi-stage builds**, and **`.dockerignore`**
- **Tag** images meaningfully and **push/pull** them from a registry

---

## Theory · ~20 min

### 1. The Dockerfile

A **Dockerfile** is a recipe Docker reads top-to-bottom to assemble an image. Most instructions add one **layer**:

```dockerfile
FROM python:3.11-slim        # base image
WORKDIR /app                 # set the working directory
COPY requirements.txt .      # copy one file in
RUN pip install -r requirements.txt   # run a build command → a layer
COPY app.py .                # copy the code in
EXPOSE 8000                  # document the port (not published automatically)
CMD ["python3", "app.py"]    # the default process when a container starts
```

### 2. Instruction reference

| Instruction | Purpose |
|---|---|
| `FROM` | Base image to build on (always first) |
| `WORKDIR` | Set the directory for later instructions |
| `COPY` | Copy files from the build context into the image |
| `ADD` | Like `COPY`, but can fetch URLs and auto-extract tarballs |
| `RUN` | Execute a command at **build** time (installs, compiles) |
| `ENV` | Set an environment variable |
| `ARG` | A build-time variable (not present at runtime) |
| `EXPOSE` | Document the listening port |
| `CMD` | Default command/args at **run** time (overridable) |
| `ENTRYPOINT` | The fixed executable; `CMD` supplies its default args |
| `HEALTHCHECK` | A command Docker runs to judge container health |

### 3. Layers and the build cache

Every layer is cached. On rebuild, Docker reuses a cached layer as long as **that instruction and everything before it are unchanged**. The first instruction that changes busts the cache for itself and all that follow.

That single rule dictates instruction order: **put what changes rarely first, what changes often last.**

```dockerfile
# ❌ BAD — editing app.py re-runs the slow install every build
COPY . .
RUN pip install -r requirements.txt

# ✅ GOOD — deps install is cached until requirements.txt actually changes
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
```

### 4. `CMD` vs `ENTRYPOINT`

Both define what runs when the container starts — the difference is override behavior:

- **`CMD`** — a *default* that's fully replaced by any command you pass to `docker run`.
- **`ENTRYPOINT`** — the *fixed* program; anything you pass to `docker run` becomes its **arguments**.

```dockerfile
ENTRYPOINT ["python3", "app.py"]   # always runs app.py…
CMD ["--port", "8000"]             # …with this default arg, overridable at run time
```
`docker run img --port 9000` → runs `python3 app.py --port 9000`. Use `ENTRYPOINT` for "this image *is* one tool"; use `CMD` alone when you want an easily replaced default.

### 5. Keeping images small

Small images pull faster, cost less, and expose a smaller attack surface:

- Start from **`-slim`** or **`-alpine`** bases instead of a full OS
- Chain related `RUN` steps with `&&` and clean up in the same layer (`rm -rf /var/lib/apt/lists/*`)
- Add a **`.dockerignore`** so `.git/`, `node_modules/`, secrets, and caches never enter the build
- Use **multi-stage builds**: compile in a heavy stage, copy only the artifact into a tiny final stage

### 6. Registries and tags

A **tag** names a version of an image: `repo:tag`. Pushing means uploading it to a registry so others (and your servers) can pull it.

```
docker.io/alice/golive:1.2.0
          └user┘└name┘ └tag┘
```

Tag with a **real version** (`1.2.0`), not just `latest` — `latest` is just the tag Docker assumes when you omit one; it doesn't mean "newest" and silently drifts. A common pattern is to push both an immutable version tag *and* move `latest`.

---

## Lab · ~50 min

Work **inside your Vagrant VM**.

### Step 1 — Containerize the Go-Live app

```bash
mkdir -p ~/golive-app && cd ~/golive-app

cat > app.py << 'EOF'
from flask import Flask, jsonify
import os, socket

app = Flask(__name__)

@app.get("/")
def index():
    return jsonify(
        service="golive",
        host=socket.gethostname(),
        version=os.getenv("APP_VERSION", "dev"),
    )

@app.get("/health")
def health():
    return jsonify(status="ok")

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000)
EOF

cat > requirements.txt << 'EOF'
flask==3.0.0
EOF

cat > Dockerfile << 'EOF'
FROM python:3.11-slim

WORKDIR /app

# Dependencies first — cached until requirements.txt changes
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Code last — changes most often
COPY app.py .

EXPOSE 8000
ENV APP_VERSION=1.0.0
CMD ["python3", "app.py"]
EOF

cat > .dockerignore << 'EOF'
.git/
__pycache__/
*.pyc
*.md
.env
EOF
```

### Step 2 — Build, run, and inspect

```bash
docker build -t golive:1.0.0 .

docker images | grep golive        # your image and its size
docker history golive:1.0.0        # the layers, newest on top

docker run -d -p 8000:8000 --name golive golive:1.0.0
curl http://localhost:8000         # JSON from your own image 🎉
curl http://localhost:8000/health
```

### Step 3 — Watch the build cache

```bash
echo "# a tiny change" >> app.py
docker build -t golive:1.0.1 .     # note: the pip install layer says CACHED
```

Only the `COPY app.py` layer and everything after it rebuild — the dependency install is reused. Now imagine `COPY . .` had come *before* the install: every code edit would reinstall Flask. **That's** why order matters.

### Step 4 — Shrink it with a multi-stage build

Multi-stage builds keep build tooling out of the final image. Here's the technique at its most extreme — a compiled binary on top of `scratch` (an empty image):

```bash
mkdir -p ~/multistage && cd ~/multistage

cat > main.go << 'EOF'
package main
import ("fmt"; "net/http")
func main() {
    http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
        fmt.Fprintln(w, "Hello from a scratch image!")
    })
    http.ListenAndServe(":8000", nil)
}
EOF

cat > Dockerfile << 'EOF'
# Stage 1: build (heavy — full Go toolchain)
FROM golang:1.21 AS builder
WORKDIR /build
COPY main.go .
RUN CGO_ENABLED=0 go build -o server main.go

# Stage 2: final (tiny — just the binary)
FROM scratch
COPY --from=builder /build/server /server
EXPOSE 8000
ENTRYPOINT ["/server"]
EOF

docker build -t go-server:1.0.0 .
docker images | grep -E 'go-server|golang'   # compare final vs the builder base
docker run -d -p 8001:8000 --name go-server go-server:1.0.0
curl http://localhost:8001
docker rm -f go-server
```

### Step 5 — Push to a registry

Create a free account at [hub.docker.com](https://hub.docker.com), then:

```bash
docker login                                    # prompts for your Docker Hub credentials

# Tag with your username + an immutable version, and also move 'latest'
docker tag golive:1.0.0 <your-username>/golive:1.0.0
docker tag golive:1.0.0 <your-username>/golive:latest

docker push <your-username>/golive:1.0.0
docker push <your-username>/golive:latest
```

Prove it's portable — remove the local copy and pull it back:

```bash
docker rm -f golive
docker rmi <your-username>/golive:1.0.0
docker run -d -p 8000:8000 <your-username>/golive:1.0.0   # pulled fresh from the registry
curl http://localhost:8000
```

!!! tip "Log in without leaving your password on disk"
    `docker login` stores credentials in `~/.docker/config.json`. On servers and CI, use a **scoped access token** (Docker Hub → Account Settings → Security) instead of your account password, and pipe it in: `echo "$TOKEN" | docker login -u <user> --password-stdin`.

---

## Advanced Topics

- **BuildKit & `buildx`** — the modern builder: parallel stages, build secrets, and **multi-architecture** images (amd64 + arm64 from one command) → [docs.docker.com — Multi-platform builds](https://docs.docker.com/build/building/multi-platform/)
- **Distroless & scratch** — final images with no shell or package manager, so there's almost nothing to exploit → [GoogleContainerTools/distroless](https://github.com/GoogleContainerTools/distroless)
- **Vulnerability scanning** — `docker scout cves` or `trivy image` to catch known CVEs before you ship → [aquasecurity/trivy](https://github.com/aquasecurity/trivy)
- **Private registries** — GitHub Container Registry (GHCR), AWS ECR, or self-hosted Harbor for images you don't want public → [docs.docker.com — Registry](https://docs.docker.com/registry/)
- **`dive`** — explore an image layer by layer and find wasted space → [wagoodman/dive](https://github.com/wagoodman/dive)

---

## Assignment

1. **Optimize and ship.** Starting from the `golive` image, produce a smaller variant — measure the `docker images` size **before and after** at least two of: switching the base to `slim`/`alpine`, adding a tighter `.dockerignore`, and collapsing `RUN` layers. Report the two sizes and what you changed. Then push your optimized image to Docker Hub tagged `2.0.0`, and paste the exact `docker run` command a teammate on a clean machine would use to run it.

2. **Make the entrypoint configurable.** Convert the app so its greeting/behavior is driven by an environment variable (e.g. `APP_ENV=production`), reflected in the `/` JSON response. Rebuild and run it **twice** with different `-e APP_ENV=...` values to show the same image behaving differently. *Stretch:* add a `HEALTHCHECK` instruction that curls `/health`, then show the `STATUS` column in `docker ps` transition to `healthy`.

---

## Further Reading

- [Dockerfile reference](https://docs.docker.com/engine/reference/builder/) — every instruction, precisely defined
- [Dockerfile best practices](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)
- [Docker multi-stage builds](https://docs.docker.com/build/building/multi-stage/)
- [Semantic Versioning](https://semver.org/) — what `MAJOR.MINOR.PATCH` actually promises
