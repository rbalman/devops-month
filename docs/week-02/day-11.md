# Day 11 · Apache & SSL/TLS

## Learning Objectives

- Configure Apache with virtual hosts
- Understand self-signed vs CA-signed certificates
- Enable HTTPS on a local server using a self-signed cert

---

## Theory · ~20 min

### Apache vs Nginx

Both Apache and Nginx are production-grade web servers. In the real world, you'll encounter both:

| | Apache | Nginx |
|---|---|---|
| Model | Process/thread per connection | Event-driven, async |
| Config style | `.htaccess` per-directory | Centralized server blocks |
| Dynamic content | Direct via modules (mod_php) | Always via proxy |
| Flexibility | Very (per-dir config) | Less, but that's a feature |
| Use case | Shared hosting, PHP apps | High-traffic proxy/static |

Apache's biggest advantage: `.htaccess` files let per-directory config override the server config — useful in shared hosting. In DevOps/container environments, Nginx is usually preferred.

### Virtual Hosts

Apache calls its site blocks **Virtual Hosts** (`<VirtualHost>`). Multiple sites can run on one server, differentiated by hostname or port.

```apache
<VirtualHost *:80>
    ServerName mysite.local
    DocumentRoot /var/www/mysite
    ErrorLog ${APACHE_LOG_DIR}/mysite_error.log
    CustomLog ${APACHE_LOG_DIR}/mysite_access.log combined
</VirtualHost>
```

### SSL/TLS in Practice

Three types of certificates:

| Type | Use Case | Cost |
|---|---|---|
| **Self-signed** | Local dev, internal tools | Free (you sign it) |
| **Let's Encrypt** | Public websites | Free (automated CA) |
| **Commercial CA** | Enterprise, EV certs | Paid |

Browsers will warn about self-signed certs (they aren't trusted by a CA), but the encryption is identical. For this lab, we'll use self-signed.

The certificate chain:
```
Root CA (trusted by OS/browser)
  └── Intermediate CA
        └── Your certificate (for yourdomain.com)
```

Browsers trust your cert because they trust the chain back to a Root CA.

---

## Lab · ~50 min

### Step 1 — Install Apache

```bash
# Stop nginx first (both use port 80 by default)
sudo systemctl stop nginx

sudo apt update && sudo apt install -y apache2
sudo systemctl enable apache2
sudo systemctl start apache2
sudo systemctl status apache2

curl http://localhost   # should show Apache default page
```

### Step 2 — Configure a Virtual Host

```bash
# Create web root
sudo mkdir -p /var/www/apache-site
sudo tee /var/www/apache-site/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head><title>Apache Site</title></head>
<body>
  <h1>Served by Apache!</h1>
</body>
</html>
EOF

sudo chown -R www-data:www-data /var/www/apache-site

# Create virtual host config
sudo tee /etc/apache2/sites-available/apache-site.conf << 'EOF'
<VirtualHost *:80>
    ServerName localhost
    DocumentRoot /var/www/apache-site

    ErrorLog ${APACHE_LOG_DIR}/apache-site_error.log
    CustomLog ${APACHE_LOG_DIR}/apache-site_access.log combined

    <Directory /var/www/apache-site>
        Options -Indexes
        AllowOverride None
        Require all granted
    </Directory>
</VirtualHost>
EOF

# Enable the site, disable the default
sudo a2dissite 000-default.conf
sudo a2ensite apache-site.conf

# Test config
sudo apache2ctl configtest

# Reload
sudo systemctl reload apache2

curl http://localhost
```

### Step 3 — Generate a self-signed TLS certificate

```bash
# Create a directory for certs
sudo mkdir -p /etc/ssl/localcerts

# Generate private key and self-signed certificate
sudo openssl req -x509 -nodes -days 365 \
    -newkey rsa:2048 \
    -keyout /etc/ssl/localcerts/server.key \
    -out /etc/ssl/localcerts/server.crt \
    -subj "/C=NP/ST=Bagmati/L=Kathmandu/O=DevOpsMonth/CN=localhost"

# Check what was generated
sudo openssl x509 -in /etc/ssl/localcerts/server.crt -noout -text | head -30
```

### Step 4 — Enable HTTPS on Apache

```bash
# Enable SSL module
sudo a2enmod ssl
sudo a2enmod rewrite

# Update virtual host config
sudo tee /etc/apache2/sites-available/apache-site.conf << 'EOF'
# Redirect HTTP to HTTPS
<VirtualHost *:80>
    ServerName localhost
    RewriteEngine On
    RewriteRule ^(.*)$ https://%{HTTP_HOST}$1 [R=301,L]
</VirtualHost>

# HTTPS server
<VirtualHost *:443>
    ServerName localhost
    DocumentRoot /var/www/apache-site

    SSLEngine on
    SSLCertificateFile      /etc/ssl/localcerts/server.crt
    SSLCertificateKeyFile   /etc/ssl/localcerts/server.key

    ErrorLog ${APACHE_LOG_DIR}/apache-site_ssl_error.log
    CustomLog ${APACHE_LOG_DIR}/apache-site_ssl_access.log combined

    <Directory /var/www/apache-site>
        Options -Indexes
        AllowOverride None
        Require all granted
    </Directory>
</VirtualHost>
EOF

sudo apache2ctl configtest
sudo systemctl reload apache2

# Test HTTPS (ignore cert warning with -k)
curl -k https://localhost
curl -kI https://localhost    # headers only
```

### Step 5 — Compare Apache and Nginx config side by side

```bash
# Apache: list enabled modules
apache2ctl -M

# Apache: list enabled sites
ls /etc/apache2/sites-enabled/

# Nginx equivalent commands (reference)
# nginx -T         ← dump full config
# ls /etc/nginx/sites-enabled/

# Stop Apache and restart Nginx
sudo systemctl stop apache2
sudo systemctl start nginx
```

---

## Assignment

1. What is the difference between a self-signed certificate and a Let's Encrypt certificate? When is each appropriate?
2. What does `Options -Indexes` do in an Apache config? Why is it a good security practice?
3. What does the `RewriteRule ^(.*)$ https://%{HTTP_HOST}$1 [R=301,L]` rule do? Break down each part.
4. Check the TLS certificate you generated with `openssl x509 -in /etc/ssl/localcerts/server.crt -noout -dates`. What is the expiry? Why would a long-lived self-signed cert be a bad idea in production?

---

## Further Reading

- [Apache documentation](https://httpd.apache.org/docs/)
- [Let's Encrypt — free certs for public sites](https://letsencrypt.org/)
- [TLS explained — Mozilla](https://developer.mozilla.org/en-US/docs/Web/Security/Transport_Layer_Security)
