# Day 06 · Bash Scripting II — Functions, Scripts & Cron

## Learning Objectives

- Write reusable Bash functions
- Build a multi-function script with error handling
- Schedule automated tasks with cron

---

## Theory · ~20 min

### Functions

Functions in Bash let you group commands, avoid repetition, and make scripts readable:

```bash
# Define
greet() {
    local NAME=$1           # local = scoped to this function
    echo "Hello, $NAME!"
}

# Call
greet "Balman"
greet "DevOps"
```

Key rules:
- Define before you call
- Use `local` for function-scoped variables (prevents polluting global scope)
- `$1`, `$2`... are positional arguments to the function
- Return values with `return <code>` (exit codes only) or `echo` (actual string output)

```bash
# Return a string value
get_date() {
    echo "$(date +%Y-%m-%d)"
}

TODAY=$(get_date)
echo "Today: $TODAY"
```

### Error Handling

Professional scripts fail loudly and early:

```bash
#!/bin/bash
set -e          # exit immediately if any command fails
set -u          # treat unset variables as errors
set -o pipefail # catch failures in pipes

# A function that handles errors
die() {
    echo "ERROR: $1" >&2    # >&2 writes to stderr
    exit 1
}

[ -f config.txt ] || die "config.txt not found"
```

### Cron — Scheduled Tasks

`cron` is the Linux scheduler. It runs commands on a schedule, defined in a **crontab** (cron table).

```bash
crontab -e      # edit your crontab
crontab -l      # list your cron jobs
```

Cron syntax:

```
* * * * *   command
│ │ │ │ │
│ │ │ │ └── Day of week (0-7, Sun=0 or 7)
│ │ │ └──── Month (1-12)
│ │ └────── Day of month (1-31)
│ └──────── Hour (0-23)
└────────── Minute (0-59)
```

Examples:

```
0 * * * *        /path/script.sh    # every hour at :00
30 2 * * *       /path/script.sh    # daily at 02:30
0 0 * * 0        /path/script.sh    # every Sunday at midnight
*/5 * * * *      /path/script.sh    # every 5 minutes
0 9 * * 1-5      /path/script.sh    # weekdays at 9am
```

!!! tip
    Use [crontab.guru](https://crontab.guru) to verify your cron expressions visually.

---

## Lab · ~50 min

### Step 1 — Functions with error handling

```bash
cat > ~/scripts/deploy.sh << 'EOF'
#!/bin/bash
set -euo pipefail

# Color output helpers
log_info()  { echo "[INFO]  $1"; }
log_ok()    { echo "[OK]    $1"; }
log_error() { echo "[ERROR] $1" >&2; }
die()       { log_error "$1"; exit 1; }

# Check a command exists
require() {
    local CMD=$1
    command -v "$CMD" &>/dev/null || die "$CMD is not installed"
    log_ok "$CMD is available"
}

# Check a service is running
check_service() {
    local SERVICE=$1
    if systemctl is-active --quiet "$SERVICE"; then
        log_ok "$SERVICE is running"
    else
        log_error "$SERVICE is NOT running"
        return 1
    fi
}

# Main
main() {
    log_info "Starting pre-deploy checks..."

    require curl
    require git
    require docker || true    # optional: don't fail if missing

    check_service nginx || log_info "nginx not required, skipping"

    log_info "All checks passed. Ready to deploy."
}

main "$@"
EOF

chmod +x ~/scripts/deploy.sh
~/scripts/deploy.sh
```

### Step 2 — Build a log rotation script

```bash
cat > ~/scripts/rotate_logs.sh << 'EOF'
#!/bin/bash
set -euo pipefail

LOG_DIR="${1:-/var/log/myapp}"
MAX_DAYS=7

rotate() {
    local DIR=$1
    if [ ! -d "$DIR" ]; then
        echo "Log dir $DIR does not exist, skipping"
        return
    fi

    echo "Rotating logs in $DIR (keeping $MAX_DAYS days)"
    find "$DIR" -type f -name "*.log" -mtime +$MAX_DAYS -exec rm -v {} \;
    echo "Done."
}

rotate "$LOG_DIR"
EOF

chmod +x ~/scripts/rotate_logs.sh

# Test with a fake log dir
mkdir -p /tmp/fake-logs
touch /tmp/fake-logs/app.log
~/scripts/rotate_logs.sh /tmp/fake-logs
```

### Step 3 — Schedule with cron

```bash
# First, make sure the log goes somewhere useful
cat > ~/scripts/heartbeat.sh << 'EOF'
#!/bin/bash
echo "$(date '+%Y-%m-%d %H:%M:%S') - system alive, load: $(uptime | awk -F'load average:' '{print $2}')" \
    >> /tmp/heartbeat.log
EOF

chmod +x ~/scripts/heartbeat.sh

# Run it manually first to confirm it works
~/scripts/heartbeat.sh
cat /tmp/heartbeat.log

# Now schedule it every minute
crontab -e
# Add this line:
# * * * * * /home/<your-username>/scripts/heartbeat.sh

# Wait a couple minutes, then check:
cat /tmp/heartbeat.log
```

### Step 4 — Environment variables in scripts

```bash
cat > ~/scripts/backup.sh << 'EOF'
#!/bin/bash
set -euo pipefail

SOURCE="${BACKUP_SOURCE:-$HOME/devops-practice}"
DEST="${BACKUP_DEST:-/tmp/backups}"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p "$DEST"

ARCHIVE="$DEST/backup_${DATE}.tar.gz"
tar -czf "$ARCHIVE" "$SOURCE"

echo "Backup created: $ARCHIVE"
echo "Size: $(du -h $ARCHIVE | cut -f1)"
EOF

chmod +x ~/scripts/backup.sh

# Run with defaults
~/scripts/backup.sh

# Override via environment
BACKUP_SOURCE=/etc/nginx ~/scripts/backup.sh
ls /tmp/backups/
```

---

## Assignment

Write a script `~/scripts/health_check.sh` that:

1. Defines at least 3 functions: `check_disk`, `check_memory`, `check_service`
2. `check_disk` — warns if any partition is over 80% full
3. `check_memory` — warns if available RAM is below 500MB
4. `check_service` — takes a service name as argument, reports OK or FAIL
5. Runs all three checks from a `main` function
6. Schedule it to run every 5 minutes with cron and log output to `/tmp/health.log`

```bash
cp ~/scripts/health_check.sh my-progress/scripts/health_check.sh
git add my-progress/
git commit -m "day-06: bash functions and cron"
git push origin main
```

---

## Further Reading

- [Bash best practices](https://bertvv.github.io/cheat-sheets/Bash.html)
- [crontab.guru](https://crontab.guru) — visual cron expression editor
- [ShellCheck](https://www.shellcheck.net/) — always check your scripts here
