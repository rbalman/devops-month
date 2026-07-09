# Day 12 · Containers I — Docker Basics

## Learning Objectives

- Understand what containers are and why they exist
- Run, inspect, and manage Docker containers
- Know the difference between an image and a container

---

## Theory · ~20 min

### The Problem Containers Solve

Before containers, the classic complaint was: *"It works on my machine."* Different machines had different OS versions, libraries, dependencies — making deployment unpredictable.

**Virtual Machines** (VMs) solved this by running a full OS inside another OS. But VMs are heavy — gigabytes per VM, minutes to boot.

**Containers** package an application with only its dependencies, sharing the host OS kernel. They're:

- Lightweight — megabytes, not gigabytes
- Fast — start in milliseconds, not minutes
- Portable — same image runs on any Linux host with Docker
- Isolated — containers don't interfere with each other

### How Docker Works

```
Your App Code
    +
Dependencies (libraries, runtime)
    +
OS base (Ubuntu/Alpine/etc.)
= Docker Image (read-only snapshot)

docker run image → Container (running instance of image)
```

A **Docker image** is like a class in programming. A **container** is like an instance of that class — you can run many containers from one image.

### Key Concepts

| Term | Meaning |
|---|---|
| **Image** | Read-only template with app + dependencies |
| **Container** | Running instance of an image |
| **Registry** | Storage for images (Docker Hub, ECR, GCR) |
| **Dockerfile** | Instructions to build an image (Day 13) |
| **Volume** | Persistent storage attached to a container |
| **Network** | Virtual network connecting containers |

---

## Lab · ~50 min

### Step 1 — Install Docker

```bash
# Install Docker Engine
curl -fsSL https://get.docker.com | sudo sh

# Add your user to the docker group (log out and back in after this)
sudo usermod -aG docker $USER

# Verify (may need to log out/in first, or use 'newgrp docker')
newgrp docker
docker --version
docker info
```

### Step 2 — Run your first container

```bash
# Pull and run a hello-world container
docker run hello-world

# What happened:
# 1. Docker looked for 'hello-world' image locally → not found
# 2. Pulled it from Docker Hub (registry)
# 3. Created a container from the image
# 4. Started the container (it printed output and exited)

# Run an Ubuntu container interactively
docker run -it ubuntu:22.04 bash

# Inside the container:
cat /etc/os-release
whoami
ls /
exit              # back to your host
```

### Step 3 — Run a web server in a container

```bash
# Run Nginx in a container, mapping host port 8080 to container port 80
docker run -d -p 8080:80 --name my-nginx nginx

# -d = detached (background)
# -p 8080:80 = host:container port mapping
# --name = give it a friendly name

# Test it
curl http://localhost:8080

# See running containers
docker ps

# See all containers (including stopped)
docker ps -a
```

### Step 4 — Inspect and interact with containers

```bash
# See logs
docker logs my-nginx
docker logs -f my-nginx    # follow live

# Execute a command inside a running container
docker exec my-nginx nginx -v
docker exec -it my-nginx bash   # open a shell

# Inside the container
cat /etc/nginx/nginx.conf
ls /usr/share/nginx/html/
exit

# Inspect container metadata
docker inspect my-nginx | head -60

# See resource usage
docker stats my-nginx    # live (Ctrl+C to stop)
```

### Step 5 — Container lifecycle

```bash
# Stop a running container (graceful)
docker stop my-nginx

# Start it again
docker start my-nginx
docker ps

# Restart
docker restart my-nginx

# Remove a container (must be stopped first)
docker stop my-nginx
docker rm my-nginx

# Force remove (stop + rm in one command)
docker rm -f my-nginx

# See images you have locally
docker images

# Remove an image
docker rmi hello-world

# Clean up all stopped containers and unused images
docker system prune
```

---

## Assignment

1. What is the difference between a Docker image and a container? Use an analogy.
2. Run an Alpine Linux container interactively (`docker run -it alpine sh`). How does its size compare to Ubuntu? Run `du -sh /` inside each. Why is Alpine preferred for production images?
3. Run `docker run -d -p 8080:80 nginx`. Then run the same command again. What happens? How does Docker name the second container?
4. What does `docker system prune` do? Is there anything it does NOT remove by default?

---

## Further Reading

- [Docker overview](https://docs.docker.com/get-started/overview/)
- [Play with Docker](https://labs.play-with-docker.com/) — free browser-based Docker environment
- [Docker Hub](https://hub.docker.com) — browse official images
