# Day 07 · Shell Scripting II — Decisions, Loops & Functions

> Yesterday your scripts ran straight through, top to bottom. Today they learn to **think**: choose between actions, repeat work, and organize into reusable functions that take arguments. At the very end, a quick taste of running scripts automatically with **cron**.

## Learning Objectives

- Make decisions with `if`/`elif`/`else` and `case`
- Repeat work with `for` and `while` loops
- Accept **arguments** passed to your script
- Organize code into reusable **functions**
- (Awareness) schedule a script with **cron**

---

## Theory · ~20 min

### One good habit first

Now that scripts get bigger, start them with this safety line. You don't need to master it — just include it:

```bash
#!/bin/bash
set -euo pipefail    # stop on errors and undefined variables instead of charging ahead
```

### Conditionals — making decisions

An `if` runs a block only when a test is true:

```bash
if [[ -f /etc/passwd ]]; then
  echo "the file exists"
else
  echo "the file is missing"
fi
```

The `[[ ... ]]` is the **test**. Common ones (many use the operators from Day 6):

| Test | True when |
|---|---|
| `-f path` | it's a file |
| `-d path` | it's a directory |
| `-z "$s"` | string is empty |
| `-n "$s"` | string is non-empty |
| `$a -gt $b` | number a > b (`-lt -eq -ge …`) |
| `"$a" == "$b"` | strings are equal |

For many possible values, `case` is cleaner than a stack of `elif`s:

```bash
case "$1" in
  start) echo "starting" ;;
  stop)  echo "stopping" ;;
  *)     echo "unknown option" ;;    # * = anything else
esac
```

### Loops — repeating work

A `for` loop repeats once per item in a list:

```bash
for i in 1 2 3; do
  echo "number $i"
done

for f in *.txt; do        # loop over files
  echo "found $f"
done
```

A `while` loop repeats as long as a condition holds:

```bash
n=1
while [[ $n -le 3 ]]; do
  echo "count $n"
  n=$(( n + 1 ))
done
```

### Arguments — input from the command line

Instead of asking with `read`, scripts can take values on the command line:

```bash
# ./deploy.sh staging web
echo "script name: $0"     # ./deploy.sh
echo "first arg:   $1"     # staging
echo "second arg:  $2"     # web
echo "all args:    $@"     # staging web
echo "how many:    $#"     # 2
```

Combine arguments with a loop:

```bash
for name in "$@"; do
  echo "Hello, $name"
done
```

### Functions — organizing and reusing

A **function** is a named block you can call many times. It can take arguments just like a script (`$1`, `$2`, …):

```bash
greet() {
  echo "Hello, $1!"
}

greet Sam        # Hello, Sam!
greet Alex       # Hello, Alex!
```

Use `local` for variables that should stay inside the function:

```bash
add() {
  local sum=$(( $1 + $2 ))
  echo "$sum"
}
add 3 4          # 7
```

### Cron — running scripts on a schedule (a taste)

Once you can write a script, you'll often want it to run **automatically** — a nightly backup, a health check every 5 minutes. **Cron** is the classic Unix scheduler for exactly that.

Edit your schedule with `crontab -e`. Each line has 5 time fields, then the command:

```
┌── minute (0–59)
│ ┌── hour (0–23)
│ │ ┌── day of month
│ │ │ ┌── month
│ │ │ │ ┌── day of week (0=Sun)
│ │ │ │ │
* * * * *  /home/vagrant/scripts/backup.sh
```

| Schedule | Meaning |
|---|---|
| `*/5 * * * *` | every 5 minutes |
| `0 2 * * *` | every day at 02:00 |
| `0 9 * * 1` | every Monday at 09:00 |

!!! tip "Cron is a big topic — this is just a taste"
    We're only showing that the power exists. One rule to remember: cron runs with a **minimal environment**, so always use **absolute paths** (`/home/vagrant/scripts/x.sh`, not `~/scripts/x.sh`) and don't rely on your aliases or custom `PATH`.

---

## Lab · ~50 min

Work **inside your Vagrant VM**. Keep scripts in `~/scripts`.

### Step 1 — Your first decision

```bash
mkdir -p ~/scripts && cd ~/scripts

cat > check.sh << 'EOF'
#!/bin/bash
set -euo pipefail

if [[ -d /etc ]]; then
  echo "/etc is a directory"
else
  echo "/etc is missing?!"
fi
EOF

chmod +x check.sh
./check.sh
```

### Step 2 — A `case` mini-menu

```bash
cat > svc.sh << 'EOF'
#!/bin/bash
set -euo pipefail

case "${1:-}" in
  start)  echo "starting the app" ;;
  stop)   echo "stopping the app" ;;
  status) echo "app is running (pretend)" ;;
  *)      echo "usage: $0 {start|stop|status}" ;;
esac
EOF

chmod +x svc.sh
./svc.sh start
./svc.sh status
./svc.sh
```

### Step 3 — A `for` loop

```bash
cat > countfiles.sh << 'EOF'
#!/bin/bash
set -euo pipefail

for item in /etc/*; do
  if [[ -d "$item" ]]; then
    echo "DIR   $item"
  else
    echo "FILE  $item"
  fi
done
EOF

chmod +x countfiles.sh
./countfiles.sh | head
```

### Step 4 — A `while` loop (countdown)

```bash
cat > countdown.sh << 'EOF'
#!/bin/bash
set -euo pipefail

n=5
while [[ $n -ge 1 ]]; do
  echo "$n..."
  n=$(( n - 1 ))
done
echo "Liftoff!"
EOF

chmod +x countdown.sh
./countdown.sh
```

### Step 5 — Arguments

```bash
cat > greet.sh << 'EOF'
#!/bin/bash
set -euo pipefail

if [[ $# -eq 0 ]]; then
  echo "usage: $0 <name> [name...]"
  exit 1
fi

for name in "$@"; do
  echo "Hello, $name!"
done
EOF

chmod +x greet.sh
./greet.sh Sam Alex Priya
./greet.sh               # prints usage, exits 1
```

### Step 6 — A function

```bash
cat > diskcheck.sh << 'EOF'
#!/bin/bash
set -euo pipefail

check() {
  local used
  used=$(df / | awk 'NR==2 {gsub("%","",$5); print $5}')
  if [[ $used -gt 80 ]]; then
    echo "ALERT: disk ${used}% used"
  else
    echo "OK: disk ${used}% used"
  fi
}

check
EOF

chmod +x diskcheck.sh
./diskcheck.sh
```

### Step 7 — Schedule it with cron (a taste)

```bash
mkdir -p ~/logs
crontab -e        # pick nano (option 1) if asked
```

Add this line (note the **absolute path**), then save and exit:

```cron
*/2 * * * * /home/vagrant/scripts/diskcheck.sh >> /home/vagrant/logs/disk.log 2>&1
```

```bash
crontab -l                 # confirm it's scheduled
tail -f ~/logs/disk.log    # wait ~2 min to see it run; Ctrl+C to stop

crontab -e                 # now delete that line and save to clean up
```

---

## Assignment

Create these in `my-progress/day-07/` and commit the scripts.

1. **`numcheck.sh`** — takes a number as `$1`. If no argument is given, print a usage message and `exit 1`. Otherwise use `if`/`elif`/`else` to say whether it's **positive, negative, or zero**, then use a loop to print the numbers from 1 up to that number.
2. **`greet-all.sh`** — defines a **function** `greet` that prints `Hello, <name>!`, then loops over **all arguments** and greets each one. If no arguments are given, greet `world`.

*(Optional): schedule one of your scripts with cron to run every 5 minutes, confirm it ran via its log file, then remove the entry. Paste your `crontab -l` into `my-progress/day-07.md`.*

```bash
git add my-progress/day-07/
git commit -m "day-07: conditionals, loops, functions, cron"
git push origin main
```

---

## Further Reading

- [crontab.guru](https://crontab.guru/) — build and read cron schedules interactively
- [Bash conditionals & loops (GNU manual)](https://www.gnu.org/software/bash/manual/html_node/Conditional-Constructs.html)
- Run [ShellCheck](https://www.shellcheck.net/) on every script you wrote this week
- [Beyond the Basics](beyond-the-basics.md) — see "systemd timers" for the modern alternative to cron
