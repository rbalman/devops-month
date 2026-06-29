# Day 04 · Linux Basics III — Package Management & Services

## Learning Objectives

- Install, remove, and manage software packages
- Start, stop, enable, and inspect system services with systemd
- Write and run your own systemd service unit

---

## Theory · ~20 min

### Package Managers

Every Linux distribution has a package manager — a tool for installing software from trusted repositories. No need to download `.exe` files or run installers.

| Distro | Package Manager | Install Command |
|---|---|---|
| Ubuntu/Debian | `apt` | `sudo apt install nginx` |
| CentOS/RHEL | `yum` / `dnf` | `sudo dnf install nginx` |
| Arch | `pacman` | `sudo pacman -S nginx` |
| macOS | `brew` | `brew install nginx` |

`apt` is what you'll use in this course (Ubuntu-based labs).

Key operations:

```bash
sudo apt update               # refresh the package index
sudo apt upgrade              # upgrade installed packages
sudo apt install <package>    # install
sudo apt remove <package>     # uninstall (keeps config)
sudo apt purge <package>      # uninstall + delete config
apt search <keyword>          # search available packages
apt show <package>            # show details about a package
dpkg -l | grep nginx          # list installed packages matching nginx
```

### systemd and Services

Modern Linux systems use **systemd** as the init system — it starts and manages all services (background processes) on your machine.

A **service** (also called a daemon) is a process that runs in the background. Examples: `nginx` (web server), `sshd` (SSH server), `cron` (scheduled jobs).

```bash
systemctl start nginx         # start a service
systemctl stop nginx          # stop a service
systemctl restart nginx       # stop + start
systemctl reload nginx        # reload config without restart
systemctl status nginx        # show current state and recent logs
systemctl enable nginx        # start automatically on boot
systemctl disable nginx       # don't start on boot
systemctl list-units --type=service   # all running services
```

### Service Unit Files

Services are defined by **unit files** in `/etc/systemd/system/` or `/lib/systemd/system/`. You can write your own.

```ini
[Unit]
Description=My App
After=network.target

[Service]
ExecStart=/usr/bin/python3 /opt/myapp/app.py
Restart=always
User=www-data

[Install]
WantedBy=multi-user.target
```

Understanding unit files is important — you'll write them when deploying custom apps.

---

## Lab · ~50 min

### Step 1 — Practice with apt

```bash
# Update package list
sudo apt update

# Install some useful tools
sudo apt install -y htop tree jq net-tools

# Verify
htop --version
tree --version
jq --version

# See what was installed and where
which htop
dpkg -L htop | head -10     # files installed by htop package

# Remove a package
sudo apt remove tree
tree --version               # should fail now

# Reinstall
sudo apt install -y tree
```

### Step 2 — Install and manage nginx

```bash
sudo apt install -y nginx

# Check status immediately after install
systemctl status nginx

# View the default page
curl http://localhost

# Stop the service
sudo systemctl stop nginx
curl http://localhost        # should fail now

# Start it again
sudo systemctl start nginx
curl http://localhost        # works again

# Enable auto-start on reboot
sudo systemctl enable nginx
```

### Step 3 — Read service logs

```bash
# View nginx logs with journalctl
sudo journalctl -u nginx
sudo journalctl -u nginx -n 50        # last 50 lines
sudo journalctl -u nginx --since "10 minutes ago"
sudo journalctl -u nginx -f           # follow live (Ctrl+C to stop)

# Also check file-based logs
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

### Step 4 — Write a custom service

Create a simple Python HTTP server and run it as a systemd service:

```bash
# Create the app
sudo mkdir -p /opt/myapp
sudo tee /opt/myapp/server.py << 'EOF'
import http.server
import socketserver

PORT = 8080
Handler = http.server.SimpleHTTPRequestHandler

with socketserver.TCPServer(("", PORT), Handler) as httpd:
    print(f"Serving on port {PORT}")
    httpd.serve_forever()
EOF

# Create the service unit file
sudo tee /etc/systemd/system/myapp.service << 'EOF'
[Unit]
Description=My Python HTTP Server
After=network.target

[Service]
ExecStart=/usr/bin/python3 /opt/myapp/server.py
WorkingDirectory=/opt/myapp
Restart=always
User=www-data

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd to pick up the new unit file
sudo systemctl daemon-reload

# Start and enable
sudo systemctl start myapp
sudo systemctl enable myapp
sudo systemctl status myapp

# Test it
curl http://localhost:8080
```

### Step 5 — Verify on reboot (optional)

```bash
# Check what's enabled to start on boot
systemctl list-unit-files --type=service | grep enabled
```

---

## Assignment

In `my-progress/day-04.md`:

1. What is the difference between `apt remove` and `apt purge`?
2. What does `Restart=always` in a systemd unit file do? Why is it useful for production services?
3. Modify the `myapp.service` to run as your own user instead of `www-data`. Restart the service and confirm it works.
4. Use `journalctl` to find the exact time nginx started on your machine today.

```bash
git add my-progress/day-04.md
git commit -m "day-04: package management and services"
git push origin main
```

---

## Further Reading

- `man systemctl`, `man journalctl`
- [systemd unit file options reference](https://www.freedesktop.org/software/systemd/man/systemd.service.html)
- [Understanding apt vs apt-get](https://itsfoss.com/apt-vs-apt-get-difference/)
