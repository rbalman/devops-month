# Day 05 · Bash Scripting I — Variables, Conditionals & Loops

## Learning Objectives

- Write and run Bash scripts
- Use variables, conditionals, and loops to automate repetitive tasks
- Handle user input and basic error conditions

---

## Theory · ~20 min

### Why Bash Scripting?

Every DevOps engineer writes Bash. It is the glue that holds infrastructure together — deploy scripts, health checks, backup jobs, setup scripts. You don't need to be a programmer, but you need to be fluent enough to read, modify, and write scripts confidently.

### Script Structure

Every Bash script starts with a **shebang** line that tells the OS which interpreter to use:

```bash
#!/bin/bash
```

Make it executable and run it:

```bash
chmod +x script.sh
./script.sh
```

### Variables

```bash
NAME="balman"           # no spaces around =
echo $NAME              # use with $
echo "${NAME}_rawat"    # use ${} when adjacent to other chars

# Read-only
readonly VERSION="1.0"

# Command output into a variable
DATE=$(date +%Y-%m-%d)
FILES=$(ls ~/devops-practice)
echo "Today is $DATE"
```

### Conditionals

```bash
# if / elif / else
if [ condition ]; then
    # commands
elif [ other_condition ]; then
    # commands
else
    # commands
fi
```

Common test conditions:

| Test | Meaning |
|---|---|
| `[ -f file ]` | file exists and is a regular file |
| `[ -d dir ]` | directory exists |
| `[ -z "$VAR" ]` | string is empty |
| `[ -n "$VAR" ]` | string is not empty |
| `[ "$A" == "$B" ]` | strings are equal |
| `[ $N -gt 10 ]` | number greater than 10 |
| `[ $N -eq 0 ]` | number equals 0 |

### Loops

```bash
# for loop over a list
for item in one two three; do
    echo "$item"
done

# for loop over files
for file in /etc/*.conf; do
    echo "Found: $file"
done

# while loop
COUNT=0
while [ $COUNT -lt 5 ]; do
    echo "Count: $COUNT"
    COUNT=$((COUNT + 1))
done
```

### Exit Codes

Every command returns an exit code: `0` = success, non-zero = failure.

```bash
ls /nonexistent
echo $?         # prints 1 (or 2) — failure

ls /etc
echo $?         # prints 0 — success
```

Use this in scripts to detect failures:

```bash
if ! mkdir /some/dir; then
    echo "ERROR: could not create directory"
    exit 1
fi
```

---

## Lab · ~50 min

### Step 1 — Your first script

```bash
mkdir -p ~/scripts
cat > ~/scripts/hello.sh << 'EOF'
#!/bin/bash
NAME="DevOps Engineer"
echo "Hello, $NAME!"
echo "Today is: $(date)"
echo "You are running: $(uname -s) $(uname -r)"
EOF

chmod +x ~/scripts/hello.sh
~/scripts/hello.sh
```

### Step 2 — Conditionals in practice

```bash
cat > ~/scripts/check_file.sh << 'EOF'
#!/bin/bash

FILE="/etc/nginx/nginx.conf"

if [ -f "$FILE" ]; then
    echo "nginx config exists at $FILE"
    echo "File size: $(du -h $FILE | cut -f1)"
else
    echo "nginx is not installed or config is missing"
fi
EOF

chmod +x ~/scripts/check_file.sh
~/scripts/check_file.sh
```

### Step 3 — Loop over servers

```bash
cat > ~/scripts/ping_check.sh << 'EOF'
#!/bin/bash

SERVERS=("8.8.8.8" "1.1.1.1" "google.com" "nonexistent.invalid")

for SERVER in "${SERVERS[@]}"; do
    if ping -c 1 -W 2 "$SERVER" &>/dev/null; then
        echo "[OK]   $SERVER is reachable"
    else
        echo "[FAIL] $SERVER is NOT reachable"
    fi
done
EOF

chmod +x ~/scripts/ping_check.sh
~/scripts/ping_check.sh
```

### Step 4 — A disk usage alerter

```bash
cat > ~/scripts/disk_alert.sh << 'EOF'
#!/bin/bash

THRESHOLD=80

# Get usage % for each mounted filesystem
df -h | tail -n +2 | while read line; do
    USAGE=$(echo "$line" | awk '{print $5}' | tr -d '%')
    MOUNT=$(echo "$line" | awk '{print $6}')

    if [ -n "$USAGE" ] && [ "$USAGE" -gt "$THRESHOLD" ] 2>/dev/null; then
        echo "WARNING: $MOUNT is at ${USAGE}% usage!"
    else
        echo "OK: $MOUNT is at ${USAGE:-?}% usage"
    fi
done
EOF

chmod +x ~/scripts/disk_alert.sh
~/scripts/disk_alert.sh
```

### Step 5 — Accept arguments

```bash
cat > ~/scripts/create_user.sh << 'EOF'
#!/bin/bash

if [ $# -lt 1 ]; then
    echo "Usage: $0 <username>"
    exit 1
fi

USERNAME=$1

if id "$USERNAME" &>/dev/null; then
    echo "User $USERNAME already exists"
    exit 0
fi

sudo useradd -m -s /bin/bash "$USERNAME"
echo "User $USERNAME created successfully"
EOF

chmod +x ~/scripts/create_user.sh
~/scripts/create_user.sh            # should print usage
~/scripts/create_user.sh testuser   # should create user
```

---

## Assignment

Write a script `~/scripts/system_report.sh` that prints:

1. Hostname and current date/time
2. OS version (`cat /etc/os-release`)
3. CPU count and model
4. Available RAM (free -h)
5. Disk usage for `/` partition
6. Top 5 processes by CPU usage

The script must:
- Use at least one variable
- Use at least one conditional (e.g., warn if disk > 70%)
- Be executable and run without errors

Push it:
```bash
cp ~/scripts/system_report.sh my-progress/scripts/system_report.sh
git add my-progress/
git commit -m "day-05: bash scripting I"
git push origin main
```

---

## Further Reading

- [Bash scripting cheatsheet](https://devhints.io/bash)
- [ShellCheck](https://www.shellcheck.net/) — paste your script and get lint warnings
- `man bash` — comprehensive reference (search with `/`)
