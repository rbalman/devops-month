# Day 11 · Networking IV — Nginx, Reverse Proxy & TLS

> Four days of networking come together today. You can address machines, resolve names, and reach them securely — now you'll run the thing that *serves* them. **Nginx** is the front door of most of the internet: it hands out static files, forwards requests to your app, spreads load across many app copies, and wraps it all in **HTTPS**. Build all four, and Operation Go Live has its web tier.

## Learning Objectives

- Explain what a web server does and read the anatomy of an HTTP request/response
- Install Nginx and understand its configuration layout
- Serve **static assets** from a `server` block (virtual host)
- Put Nginx in front of an app as a **reverse proxy**
- Spread traffic across multiple backends as a **load balancer**
- Understand TLS and serve your site over **HTTPS** with a self-signed certificate

---

## Theory · ~20 min

### 1. HTTP — the request/response you'll serve

You typed one by hand on Day 08. Every web interaction is a **request** and a **response**:

```
GET /index.html HTTP/1.1      ← method + path + version
Host: example.com             ← headers
                              ← blank line ends the request
```
```
HTTP/1.1 200 OK               ← version + status code
Content-Type: text/html       ← headers
                              ← blank line
<html>...</html>              ← body
```

Status codes tell the story: **2xx** success, **3xx** redirect, **4xx** you (client) erred (404 not found), **5xx** the server erred (502 bad gateway). You'll read these in logs all week.

### 2. What a web server actually does

A **web server** listens on a port (80 for HTTP, 443 for HTTPS) and, for each request, does one of four jobs:

| Job | Meaning |
|---|---|
| **Serve static files** | Hand back HTML/CSS/JS/images from disk |
| **Reverse proxy** | Forward the request to a backend app and relay its reply |
| **Load balance** | Distribute requests across several backends |
| **Terminate TLS** | Handle HTTPS so the app behind it can speak plain HTTP |

**Nginx** ("engine-x") does all four and is the most-deployed web server in the world. Its event-driven model handles thousands of connections cheaply — which is why it usually sits at the front of production stacks.

### 3. Nginx config layout

```
/etc/nginx/
├── nginx.conf          ← global settings; includes the rest
├── sites-available/    ← every site config you've written (may be inactive)
├── sites-enabled/      ← symlinks to the ones that are ON
└── snippets/           ← reusable fragments (e.g. TLS settings)
```

The unit of config is a **`server` block** — Nginx's virtual host. It decides how to answer requests for a given name/port:

```nginx
server {
    listen 80;
    server_name example.com;      # which hostname this block answers for
    root /var/www/example;        # where files live
    index index.html;

    location / {                  # match URL paths
        try_files $uri $uri/ =404;
    }
}
```

`try_files $uri $uri/ =404` means: try the file, then the directory, else return 404.

### 4. Reverse proxy vs load balancer

A **reverse proxy** stands in front of one backend app and forwards to it — the client only ever talks to Nginx. Turn one backend into a **pool** and Nginx becomes a **load balancer**, rotating requests across them (round-robin by default) so no single app instance is overwhelmed and any one can die without downtime.

```
              ┌─▶ app :3001
Client ─▶ Nginx ─▶ app :3002    (load balancer: one front, many backends)
              └─▶ app :3003
```

### 5. TLS — the padlock

**TLS** (Transport Layer Security; the successor to **SSL**) encrypts the connection so nobody between client and server can read or tamper with it. When Nginx "terminates TLS," it holds the certificate and does the crypto, handing plain HTTP to your app behind it.

A quick tour of the handshake:

1. Client connects; server presents its **certificate** (contains the domain, a public key, an expiry, and a CA's signature).
2. Client checks the certificate is signed by a **Certificate Authority (CA)** it trusts.
3. The two sides agree on a session key; everything after is encrypted.

**Certificates come in three flavors:**

| Type | Trusted by browsers? | Use |
|---|---|---|
| **Self-signed** | No (warning shown) | Local dev, internal tools — *today's lab* |
| **Let's Encrypt** | Yes (free, automated CA) | Public sites — *your Week 4 Go-Live* |
| **Commercial CA** | Yes (paid) | Enterprise/EV needs |

!!! note "Self-signed today, Let's Encrypt in production"
    A self-signed cert uses the **exact same encryption** as a real one — browsers just don't *trust* the signer, so they warn. It's perfect for learning offline. A real Let's Encrypt cert needs a **public domain pointing at a reachable server on port 80** to validate, which you'll have in Week 4 on a real cloud box. See [Advanced Topics](#advanced-topics).

---

## Lab · ~50 min

Work **inside your Vagrant VM**. (If you enabled `ufw` on Day 10, ports 80 and 443 are already allowed.)

### Step 1 — Install Nginx

```bash
sudo apt update && sudo apt install -y nginx
sudo systemctl enable --now nginx
curl -I http://localhost                # 200 OK from the Nginx default page
```

### Step 2 — Serve a static site

```bash
sudo mkdir -p /var/www/golive
sudo tee /var/www/golive/index.html << 'EOF'
<!DOCTYPE html>
<html>
  <head><title>Operation Go Live</title></head>
  <body><h1>Served by Nginx 🚀</h1><p>Static assets, live.</p></body>
</html>
EOF
sudo chown -R www-data:www-data /var/www/golive

sudo tee /etc/nginx/sites-available/golive << 'EOF'
server {
    listen 80;
    server_name localhost;

    root /var/www/golive;
    index index.html;

    access_log /var/log/nginx/golive_access.log;
    error_log  /var/log/nginx/golive_error.log;

    location / {
        try_files $uri $uri/ =404;
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/golive /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default    # disable the default site
sudo nginx -t                                  # ALWAYS test before reloading
sudo systemctl reload nginx

curl http://localhost                          # your page
```

!!! tip "`nginx -t` then `reload`, every time"
    `nginx -t` validates the config; `reload` applies it with **zero downtime** (existing connections finish). Never `restart` a busy server when `reload` will do.

### Step 3 — Become a reverse proxy

Start a tiny backend app, then have Nginx forward to it:

```bash
python3 -m http.server 3000 --bind 127.0.0.1 &     # a stand-in "app" on :3000
BACKEND=$!

sudo tee /etc/nginx/sites-available/golive << 'EOF'
server {
    listen 80;
    server_name localhost;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
EOF

sudo nginx -t && sudo systemctl reload nginx
curl http://localhost                              # served by the backend, THROUGH Nginx
kill $BACKEND
```

Those `proxy_set_header` lines pass the real client info to the backend — without them the app thinks every request came from Nginx itself.

### Step 4 — Turn it into a load balancer

Run **three** backends, then define an `upstream` pool and watch Nginx rotate between them:

```bash
# Three tiny backends, each reporting its own port
for p in 3001 3002 3003; do
  ( echo "Backend on port $p" > /tmp/be-$p.txt
    cd /tmp && python3 -m http.server "$p" --bind 127.0.0.1 ) &
done

sudo tee /etc/nginx/sites-available/golive << 'EOF'
upstream app_pool {
    server 127.0.0.1:3001;
    server 127.0.0.1:3002;
    server 127.0.0.1:3003;
}

server {
    listen 80;
    server_name localhost;

    location / {
        proxy_pass http://app_pool;
        proxy_set_header Host $host;
    }
}
EOF

sudo nginx -t && sudo systemctl reload nginx

# Hit it several times — watch the port change round-robin
for i in $(seq 6); do curl -s http://localhost/be-300{1,2,3}.txt 2>/dev/null; done
for i in $(seq 6); do curl -s http://localhost/ | head -1; done
```

Requests fan out across `3001 → 3002 → 3003 → 3001 …`. Kill one backend and Nginx routes around it — that's zero-downtime resilience in three lines.

```bash
pkill -f "http.server 300"     # stop all three backends
```

### Step 5 — Serve HTTPS with a self-signed certificate

Generate a key + self-signed cert, then add a TLS `server` block:

```bash
sudo mkdir -p /etc/nginx/certs
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/nginx/certs/golive.key \
  -out    /etc/nginx/certs/golive.crt \
  -subj "/C=NP/ST=Bagmati/L=Kathmandu/O=DevOpsMonth/CN=localhost"

sudo tee /etc/nginx/sites-available/golive << 'EOF'
# Redirect all HTTP to HTTPS
server {
    listen 80;
    server_name localhost;
    return 301 https://$host$request_uri;
}

# HTTPS
server {
    listen 443 ssl;
    server_name localhost;

    ssl_certificate     /etc/nginx/certs/golive.crt;
    ssl_certificate_key /etc/nginx/certs/golive.key;

    root /var/www/golive;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }
}
EOF

sudo nginx -t && sudo systemctl reload nginx

curl -kI https://localhost          # -k accepts the self-signed cert; note "HTTP/1.1 200"
curl -I  http://localhost           # note the 301 redirect to https
```

Inspect the certificate you issued:

```bash
openssl x509 -in /etc/nginx/certs/golive.crt -noout -subject -dates
```

The browser would warn (untrusted signer), but the connection is fully encrypted — the same TLS a real cert uses.

---

## Advanced Topics

- **Real certificates with Let's Encrypt** — `certbot --nginx` issues and auto-renews a trusted cert; needs a public domain + port 80. You'll run this for real on your Go-Live server in Week 4 → [certbot.eff.org](https://certbot.eff.org/)
- **Load-balancing strategies** — `least_conn`, `ip_hash`, weights, and health checks → [Nginx — HTTP load balancing](https://nginx.org/en/docs/http/load_balancing.html)
- **HTTP hardening** — HSTS, gzip/brotli, caching headers, HTTP/2 → [Mozilla SSL Config Generator](https://ssl-config.mozilla.org/)
- **Location matching** — exact, prefix, and regex `location` rules and their precedence → [DigitalOcean — Nginx location blocks](https://www.digitalocean.com/community/tutorials/understanding-nginx-server-and-location-block-selection-algorithms)
- **Apache, the other server** — you'll meet it in the wild; the same ideas, `<VirtualHost>` syntax → [Apache docs](https://httpd.apache.org/docs/)

---

## Assignment

1. **Name-based virtual hosts.** Configure Nginx to serve **two different sites on port 80** from the same VM, chosen by hostname — `site-a.local` and `site-b.local` — each with its own `root` and a distinct `index.html`. Add both names to `/etc/hosts` pointing at `127.0.0.1` (you did this on Day 09), then prove each returns its own page with `curl -H "Host: site-a.local" http://localhost` and the same for `site-b`. Paste both configs and both outputs.

2. **Read the story in the logs.** With your site running, make a successful request, a request to a path that doesn't exist, and (bonus) stop your backend and hit the proxy. Then from `/var/log/nginx/` find the log lines and report: the **status code** for each case (expect a 200, a 404, and a 502), and one sentence on what a **502 Bad Gateway** tells you about where the problem is.

---

## Further Reading

- [Nginx beginner's guide](https://nginx.org/en/docs/beginners_guide.html)
- [Cloudflare — What is a reverse proxy?](https://www.cloudflare.com/learning/cdn/glossary/reverse-proxy/)
- [Cloudflare — How does TLS work?](https://www.cloudflare.com/learning/ssl/what-is-ssl/)
- [What happens when you type a URL](https://github.com/alex/what-happens-when) — the whole networking week, end to end
- `man nginx`, `man openssl`
