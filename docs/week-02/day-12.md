# Day 5 · Containers I — Docker Basics

> You've built the web tier — Nginx serving your app over HTTPS. But it all lives on one hand-configured VM: reproduce it elsewhere and you're back to *"works on my machine."* This week's finale packages the app so it runs **identically** anywhere — your laptop, a teammate's, a cloud box. That package is a **container**. Today you meet the runtime: pulling images, running containers, and giving them storage and a network — the raw materials you'll assemble into Operation Go Live's shippable stack.

## Learning Objectives

- Explain what a **container** is and how it differs from a virtual machine
- Describe Docker's architecture: **client**, **daemon**, **image**, **registry**
- Run, inspect, and manage the full **container lifecycle**
- **Publish** container ports to reach a service from the host
- Persist data with **volumes** and connect containers on a **network**

---

## Theory · ~20 min

### 1. Why containers exist

A **Virtual Machine** virtualizes *hardware*: each VM ships a full guest OS (its own kernel), so it's gigabytes in size and takes minutes to boot. A **container** virtualizes the *operating system*: it shares the host's kernel and packages only your app plus its dependencies — megabytes, and it starts in milliseconds.

```
   Virtual Machines                     Containers
┌────────┐ ┌────────┐            ┌────────┐ ┌────────┐
│  App   │ │  App   │            │  App   │ │  App   │
│ Guest  │ │ Guest  │            │  deps  │ │  deps  │
│  OS    │ │  OS    │            └────────┘ └────────┘
├────────┴─┴────────┤            ├───────────────────┤
│    Hypervisor     │            │  Docker Engine    │
├───────────────────┤            ├───────────────────┤
│      Host OS      │            │   Host OS kernel  │  ← shared!
└───────────────────┘            └───────────────────┘
```

The isolation isn't magic — it's two Linux kernel features: **namespaces** (a container gets its own view of processes, network, mounts, hostname) and **cgroups** (limits on CPU, memory, I/O). Docker just makes them easy to use.

!!! tip "📺 Watch — *Docker Crash Course for Absolute Beginners* (TechWorld with Nana)"
    The companion video for today (and the start of tomorrow) — a clear walkthrough from the ground up.

    [![Docker Crash Course for Absolute Beginners](https://img.youtube.com/vi/pg19Z8LL06w/hqdefault.jpg){ width="360" }](https://youtu.be/pg19Z8LL06w)

    **Chapters:** [what is Docker](https://youtu.be/pg19Z8LL06w?t=174) · [VM vs Docker](https://youtu.be/pg19Z8LL06w?t=698) · [install](https://youtu.be/pg19Z8LL06w?t=1039) · [images vs containers](https://youtu.be/pg19Z8LL06w?t=1296) · [registries](https://youtu.be/pg19Z8LL06w?t=1592) · [pull & run](https://youtu.be/pg19Z8LL06w?t=1922) · [port binding](https://youtu.be/pg19Z8LL06w?t=2346) · [start & stop](https://youtu.be/pg19Z8LL06w?t=2570)

### 2. Docker's architecture

The `docker` command is only a **client**. It sends requests to the **daemon** (`dockerd`), a background service that does the real work — building images, running containers, pulling from registries.

```
docker CLI ──API──▶ dockerd (daemon) ──┬──▶ containers (running)
                                        ├──▶ images (local cache)
                                        └──▶ registry (Docker Hub) ─ pull/push
```

### 3. Images vs containers

An **image** is a read-only template — your app, its dependencies, and a minimal OS userland, stacked as **layers**. A **container** is a running instance of an image with a thin **writable layer** on top.

> Image is to container as **class** is to **object**: one image, many containers.

Anything you write inside a running container lands in that writable layer and **disappears when the container is removed** — which is exactly why volumes (below) exist.

### 4. Registries and image names

A **registry** stores and distributes images. [Docker Hub](https://hub.docker.com) is the default. An image reference reads:

```
      registry / repository : tag
      docker.io/ library/nginx : 1.27-alpine
                 └─ user ─┘└name┘  └ version ┘
```

Official images (`nginx`, `postgres`, `ubuntu`) live under `library/` and need no username. Omit the tag and Docker assumes `:latest` — convenient, but never rely on it in production, where you want a pinned version.

| Term | Meaning |
|---|---|
| **Image** | Read-only, layered template with app + dependencies |
| **Container** | Running instance of an image (image + writable layer) |
| **Registry** | Storage/distribution for images (Docker Hub, GHCR, ECR) |
| **Volume** | Docker-managed storage that outlives a container |
| **Network** | Virtual network that lets containers talk to each other |

### 5. Containers are ephemeral — volumes and networks fix that

Two consequences of the writable-layer model drive most of today's lab:

- **State is lost on removal.** A database in a bare container loses its data the moment you `docker rm` it. A **volume** stores that data outside the container's lifecycle.
- **Containers are isolated by default.** To let one container reach another (app → database), you put them on the same **user-defined network**, where Docker's embedded DNS resolves containers by name.

**How you can mount storage into a container** — there are four ways, and you'll pick between them by *what* you're storing:

| Type | What it is | Syntax example | Use it for |
|---|---|---|---|
| **Named volume** | Docker-managed storage with a name you choose; lives under `/var/lib/docker/volumes/` | `-v appdata:/data` | Databases, uploads, any **data** you must keep |
| **Anonymous volume** | Like a named volume but Docker generates a random name; easy to lose track of | `-v /data` | Throwaway scratch space; usually you'll prefer a named one |
| **Bind mount** | Maps an **existing host path** straight into the container | `-v ~/site:/usr/share/nginx/html:ro` | Config files and live-editable code in **development** |
| **tmpfs mount** | Stored in the **host's RAM**, never on disk; vanishes when the container stops | `--tmpfs /tmp` | Secrets and temp files you never want written to disk |

The modern, more explicit form is `--mount` (e.g. `--mount type=bind,source=~/site,target=/usr/share/nginx/html,readonly`); `-v` is the older shorthand for the same thing. Add `:ro` (or `readonly`) to mount read-only.

---

## Lab · ~50 min

Work **inside your Vagrant VM** (`vagrant ssh`).

### Step 1 — Install Docker

```bash
curl -fsSL https://get.docker.com | sudo sh      # official install script
sudo usermod -aG docker $USER                    # run docker without sudo
newgrp docker                                    # apply the group now (or log out/in)

docker --version
docker info                                      # talks to the daemon — confirms it's running
```

!!! warning "The `docker` group is root-equivalent"
    Anyone in the `docker` group can start a container that mounts the host's `/` and edit any file as root. On a shared server, treat `docker` group membership like `sudo`.

### Step 2 — Run your first containers

```bash
docker run hello-world        # pulls the image, runs it, prints, exits

# An interactive Ubuntu shell inside a container
docker run -it ubuntu:22.04 bash
cat /etc/os-release           # you're "in" Ubuntu…
hostname                      # …with its own hostname (a namespace)
exit                          # container stops when its main process ends
```

`docker run` does four things: find the image locally, pull it from the registry if missing, create a container, and start it.

### Step 3 — Run a service and publish a port

```bash
docker run -d -p 8080:80 --name web nginx
#         │  │            └ friendly name
#         │  └ host:container port mapping (host 8080 → container 80)
#         └ detached (background)

curl http://localhost:8080    # the Nginx welcome page
docker ps                     # running containers
docker ps -a                  # include stopped ones
```

!!! note "Publishing is opt-in"
    A container's ports are private until you `-p` (publish) them. Without `-p 8080:80`, Nginx is running but unreachable from the host.

### Step 4 — Inspect and interact

```bash
docker logs web               # stdout/stderr of the container
docker logs -f web            # follow live (Ctrl+C to stop)

docker exec web nginx -v      # run a command inside a running container
docker exec -it web bash      # open a shell inside it
  ls /usr/share/nginx/html/   #   poke around, then…
  exit

docker inspect web | less     # full JSON: IP, mounts, env, config
docker stats web              # live CPU/memory (Ctrl+C to stop)
```

### Step 5 — The container lifecycle

```bash
docker stop web               # graceful stop (SIGTERM, then SIGKILL)
docker start web              # start it again — same container, same config
docker restart web

docker rm -f web              # force-remove (stop + rm)

docker images                 # local image cache
docker rmi hello-world        # remove an image
docker system prune           # reclaim: stopped containers, unused networks, dangling images
```

### Step 6 — Persist data with a volume

The writable layer dies with the container. A **named volume** survives:

```bash
docker volume create appdata

# Write into the volume from one container…
docker run --rm -v appdata:/data alpine sh -c 'echo "survives!" > /data/note.txt'

# …then read it back from a brand-new container
docker run --rm -v appdata:/data alpine cat /data/note.txt      # → survives!
```

A **bind mount** maps a host directory into the container instead — perfect for serving files you edit live:

```bash
mkdir -p ~/site && echo '<h1>From the host</h1>' > ~/site/index.html
docker run -d -p 8081:80 -v ~/site:/usr/share/nginx/html:ro --name bindweb nginx
curl http://localhost:8081                    # your file, served from the host dir
docker rm -f bindweb
```

!!! tip "Volume vs bind mount"
    **Named volume** — Docker manages the location; use it for *data* (databases, uploads). **Bind mount** — you pick the host path; use it for *config and live code* in development. You'll use both tomorrow and in Compose.

### Step 7 — Connect containers on a network

On a **user-defined network**, containers find each other by name:

```bash
docker network create appnet

docker run -d --network appnet --name web nginx          # a service…
docker run --rm --network appnet alpine \
  wget -qO- http://web                                    # …reached by NAME, not IP
```

Now prove the default network has **no name resolution**:

```bash
docker run --rm alpine ping -c1 web        # "bad address 'web'" — can't resolve
docker rm -f web
```

That name-based discovery is the whole reason multi-container apps are easy — and it's what Docker Compose automates on Day 7.

---

## Advanced Topics

- **Rootless Docker** — run the daemon as a non-root user to shrink the blast radius → [docs.docker.com — Rootless mode](https://docs.docker.com/engine/security/rootless/)
- **Namespaces & cgroups** — the kernel primitives Docker is built on; understand them and containers stop being magic → [Red Hat — What are namespaces and cgroups?](https://www.redhat.com/en/blog/architecting-containers-part-1-technology-comparison)
- **Alternative runtimes** — Podman (daemonless, rootless), containerd, and the OCI standard that keeps them interchangeable → [opencontainers.org](https://opencontainers.org/)
- **Image provenance & scanning** — where images come from and how to check them for CVEs before you run them → [docs.docker.com — Docker Scout](https://docs.docker.com/scout/)

---

## Assignment

1. **Prove persistence.** Run a `postgres:15-alpine` container with a **named volume** for its data and a password via `-e POSTGRES_PASSWORD=...`. Create a table and insert a row (`docker exec -it <c> psql -U postgres -c "..."`). Then **remove the container entirely** and start a *new* one pointing at the same volume. Show the row is still there. Paste every command and its output, and explain in one line what would have happened **without** the volume.

2. **Two containers, one network.** Create a user-defined network and run an `nginx` container named `web` on it. From a second, throwaway container on the **same** network, fetch `web`'s page **by name** (`wget -qO- http://web`). Then attempt the same from a container **not** on that network and show it fails. *Stretch:* run `docker network inspect <net>` and report the subnet and each container's IP — then explain why you were told to use names instead of those IPs.

---

## Further Reading

- [Docker overview](https://docs.docker.com/get-started/overview/) — the mental model, start to finish
- [Play with Docker](https://labs.play-with-docker.com/) — a free, throwaway Docker playground in the browser
- [Docker Hub](https://hub.docker.com) — browse official and community images
- 📺 [Docker Crash Course for Absolute Beginners](https://youtu.be/pg19Z8LL06w) (TechWorld with Nana, ~1h) — the whole Docker workflow, hands-on
- `docker <command> --help` — every subcommand is self-documenting
