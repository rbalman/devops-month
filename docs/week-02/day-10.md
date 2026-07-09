# Day 10 · Web Servers — Nginx

## Learning Objectives

- Install and understand Nginx's configuration structure
- Serve static files and configure a reverse proxy
- Read and use Nginx access and error logs

---

## Theory · ~20 min

### What is a Web Server?

A web server listens on a port (typically 80/443), receives HTTP requests, and returns responses. It can:

- **Serve static files** — HTML, CSS, JS, images
- **Reverse proxy** — forward requests to a backend app (Node, Python, etc.)
- **Load balance** — distribute requests across multiple backends
- **Terminate TLS** — handle HTTPS so your app doesn't have to

**Nginx** (pronounced "engine-x") is the most widely deployed web server. It's known for high performance, low memory usage, and excellent configuration flexibility. Most production stacks use it as a reverse proxy in front of application servers.

### Nginx Architecture

Nginx uses an **event-driven, non-blocking** model. One master process manages multiple worker processes. Workers handle thousands of connections concurrently without spawning a thread per connection — unlike Apache's older threaded model.

### Configuration Structure

```
/etc/nginx/
├── nginx.conf          ← main config (global settings, includes)
├── sites-available/    ← all server block configs (disabled)
├── sites-enabled/      ← symlinks to active configs
├── conf.d/             ← alternative: drop-in config files
└── snippets/           ← reusable config fragments
```

A **server block** is Nginx's equivalent of Apache's VirtualHost — it defines how a server responds to requests for a specific hostname/port:

```nginx
server {
    listen 80;
    server_name example.com;

    root /var/www/example;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }
}
```

A **location block** matches URL paths and defines how to handle them.

---

## Lab · ~50 min

### Step 1 — Install and verify Nginx

```bash
sudo apt update && sudo apt install -y nginx
sudo systemctl enable nginx
sudo systemctl start nginx
sudo systemctl status nginx

curl http://localhost     # should return Nginx default page
```

### Step 2 — Serve a static site

```bash
# Create the web root
sudo mkdir -p /var/www/mysite

# Create a simple HTML page
sudo tee /var/www/mysite/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head><title>DevOps Month</title></head>
<body>
  <h1>Hello from Nginx!</h1>
  <p>Served by Nginx on Linux.</p>
</body>
</html>
EOF

# Set correct ownership
sudo chown -R www-data:www-data /var/www/mysite

# Create an Nginx server block config
sudo tee /etc/nginx/sites-available/mysite << 'EOF'
server {
    listen 80;
    server_name localhost;

    root /var/www/mysite;
    index index.html;

    access_log /var/log/nginx/mysite_access.log;
    error_log  /var/log/nginx/mysite_error.log;

    location / {
        try_files $uri $uri/ =404;
    }
}
EOF

# Enable the site (create symlink to sites-enabled)
sudo ln -s /etc/nginx/sites-available/mysite /etc/nginx/sites-enabled/

# Disable the default site
sudo rm -f /etc/nginx/sites-enabled/default

# Test the config before reloading
sudo nginx -t

# Reload Nginx (no downtime)
sudo systemctl reload nginx

curl http://localhost
```

### Step 3 — Configure a reverse proxy

A reverse proxy forwards incoming HTTP requests to a backend service.

```bash
# Start a simple backend (Python)
python3 -m http.server 3000 &
BACKEND_PID=$!

# Update Nginx config to proxy to it
sudo tee /etc/nginx/sites-available/mysite << 'EOF'
server {
    listen 80;
    server_name localhost;

    access_log /var/log/nginx/mysite_access.log;
    error_log  /var/log/nginx/mysite_error.log;

    # Serve static files directly
    location /static/ {
        root /var/www/mysite;
    }

    # Proxy everything else to the backend
    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
EOF

sudo nginx -t && sudo systemctl reload nginx

curl http://localhost

# Clean up background server
kill $BACKEND_PID
```

### Step 4 — Read and understand logs

```bash
# Generate some requests
for i in {1..10}; do curl -s http://localhost > /dev/null; done
curl http://localhost/nonexistent

# Read the access log
sudo tail -20 /var/log/nginx/mysite_access.log

# The default Combined Log Format:
# IP - user [timestamp] "method path version" status_code bytes "referer" "user-agent"

# Read error log
sudo tail -20 /var/log/nginx/mysite_error.log

# Live monitoring
sudo tail -f /var/log/nginx/mysite_access.log
# (send a few requests, then Ctrl+C)
```

### Step 5 — Nginx status page (health check)

```bash
sudo tee /etc/nginx/sites-available/mysite << 'EOF'
server {
    listen 80;
    server_name localhost;

    root /var/www/mysite;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }

    location /nginx_status {
        stub_status on;
        allow 127.0.0.1;
        deny all;
    }
}
EOF

sudo nginx -t && sudo systemctl reload nginx
curl http://localhost/nginx_status
```

---

## Assignment

1. What is the difference between `systemctl reload nginx` and `systemctl restart nginx`? When would you use each?
2. What does `try_files $uri $uri/ =404;` mean? Break it down step by step.
3. Modify your static site to serve a second page at `/about`. Add a link from the main page to `/about`. Test it with curl.
4. Make a request to a path that doesn't exist. What does the Nginx error log show? What HTTP status code is returned?

---

## Further Reading

- [Nginx beginner's guide](https://nginx.org/en/docs/beginners_guide.html)
- [Nginx location block matching explained](https://www.digitalocean.com/community/tutorials/understanding-nginx-server-and-location-block-selection-algorithms)
- `man nginx`
