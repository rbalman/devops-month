# Day 7 · Shell Scripting II — Logic, Loops & Reuse

> The second half. Yesterday's scripts ran straight through, top to bottom. Today they learn to **think**: choose between actions, repeat work, take arguments, and organize into reusable functions. We finish with how to **debug** a script and a taste of scheduling with **cron**.

## Learning Objectives

- Run scripts safely with `set -euo pipefail`
- Make decisions with `if`/`elif`/`else` and `case`
- Repeat work with `for`, `while`, and the `while read` loop
- Accept and **validate** command-line arguments
- Organize code into reusable **functions**
- Debug with `bash -x`, and schedule with **cron** (awareness)
- Read system and service logs with **journalctl** (and syslog)

---

## Theory · ~25 min

### 1. Start safe — `set -euo pipefail`

Bigger scripts fail in quiet, dangerous ways. Begin every script with this line:

```bash
#!/bin/bash
set -euo pipefail
```

| Flag | Effect |
|---|---|
| `-e` | exit the moment any command fails, instead of charging on |
| `-u` | treat use of an **unset** variable as an error (catches typos) |
| `-o pipefail` | a pipeline fails if **any** stage fails, not just the last |

!!! danger "Why it matters"
    Without `-e`, a script whose `cd /backup` silently failed will happily run `rm -rf *` in the *wrong* directory. `set -euo pipefail` turns silent disasters into loud, early stops.

### 2. Conditionals — `if` / `elif` / `else`

An `if` runs a block only when its test is true; `elif` adds more branches:

```bash
if [[ $age -lt 13 ]]; then
  echo "child"
elif [[ $age -lt 20 ]]; then
  echo "teenager"
else
  echo "adult"
fi
```

`[[ ... ]]` is the **test**. The common ones:

| Test | True when |
|---|---|
| `-f path` / `-d path` | it's a file / a directory |
| `-e path` | it exists (any type) |
| `-z "$s"` / `-n "$s"` | string is empty / non-empty |
| `$a -eq $b` | numbers equal (`-ne -lt -gt -le -ge`) |
| `"$a" == "$b"` | strings equal (`!=` for not-equal) |

Combine tests with `&&` (and) / `||` (or):

```bash
if [[ -f "$file" && -r "$file" ]]; then echo "readable file"; fi
```

### 3. `case` — many branches, cleanly

For one value with several possibilities, `case` beats a stack of `elif`s:

```bash
case "${1:-}" in
  start)   echo "starting" ;;
  stop)    echo "stopping" ;;
  restart) echo "restarting" ;;
  *)       echo "usage: $0 {start|stop|restart}"; exit 1 ;;   # * = anything else
esac
```

`${1:-}` safely defaults the first argument to empty (Day 6) so `set -u` doesn't trip when it's missing.

### 4. Loops — `for`, ranges, and `while`

```bash
for i in 1 2 3; do echo "num $i"; done      # a fixed list
for i in {1..5}; do echo "num $i"; done     # a range: 1 2 3 4 5
for f in *.txt; do echo "file $f"; done     # files, via a glob
```

**Number ranges with brace expansion.** `{1..5}` is *brace expansion* — the shell builds the whole list *before* the loop runs. It does far more than count up:

```bash
echo {1..5}          # 1 2 3 4 5
echo {5..1}          # 5 4 3 2 1        (counts down)
echo {0..20..5}      # 0 5 10 15 20     (step by 5)
echo {01..05}        # 01 02 03 04 05   (zero-padded)
echo {a..e}          # a b c d e        (letters work too)
echo file{1..3}.txt  # file1.txt file2.txt file3.txt
```

That last form is a real time-saver — batch-create files and directories in one line:

```bash
mkdir -p site/{css,js,img}   # three directories at once
touch log{1..3}.txt          # log1.txt log2.txt log3.txt
```

!!! warning "Brace expansion can't see variables"
    Braces expand *before* `$variables` do, so `{1..$n}` stays literal and the loop won't count. For a range up to a **variable**, use `seq` or a C-style loop instead:
    ```bash
    n=5
    for i in $(seq 1 "$n");   do echo "$i"; done   # seq builds the list
    for (( i=1; i<=n; i++ ));  do echo "$i"; done   # C-style counter
    ```

**More on `seq`.** Where brace expansion is fixed at parse time, `seq` is a real program — so it happily takes **variables** and even **decimals**, and can format its output. It prints one number per line by default, which is exactly what a `for` or `while read` loop wants:

```bash
seq 5           # 1 2 3 4 5          (just an end — starts at 1)
seq 2 6         # 2 3 4 5 6          (start … end)
seq 1 2 10      # 1 3 5 7 9          (start STEP end — every 2nd)
seq 10 -2 0     # 10 8 6 4 2 0       (count down with a negative step)
seq 0 0.5 2     # 0 0.5 1 1.5 2      (decimals — braces and $(( )) can't)
seq -w 8 11     # 08 09 10 11        (-w = equal width, zero-padded)
seq -s, 1 5     # 1,2,3,4,5          (-s sets the separator)
```

!!! tip "seq vs brace expansion"
    Use **`{1..5}`** for quick, literal ranges you type by hand; reach for **`seq`** whenever the start, step, or end comes from a **variable** or needs **decimals**.

A `while` loop runs as long as its test holds:

```bash
n=1
while [[ $n -le 3 ]]; do
  echo "count $n"
  n=$(( n + 1 ))
done
```

Steer a loop with **`break`** (stop entirely) and **`continue`** (skip to the next round):

```bash
for f in *; do
  [[ -f "$f" ]] || continue     # skip anything that isn't a file
  echo "processing $f"
done
```

### 5. `while read` — process input line by line

The workhorse loop of real DevOps: walk a file, a list, or command output one line at a time.

```bash
while IFS= read -r line; do
  echo "→ $line"
done < /etc/hostname
```

!!! note "Memorize `IFS= read -r`"
    `IFS=` preserves leading/trailing spaces and `-r` keeps backslashes literal — together they read a line *exactly* as written. This exact form is the safe way to read lines.

### 6. Arguments — input from the command line

```bash
# ./deploy.sh staging web
echo "script : $0"    # ./deploy.sh
echo "first  : $1"    # staging
echo "all    : $@"    # staging web
echo "count  : $#"    # 2
```

**Validate before you use them:**

```bash
if [[ $# -lt 1 ]]; then
  echo "usage: $0 <environment>" >&2
  exit 1
fi
```

### 7. Functions — organize and reuse

A **function** is a named block you call by name; it takes arguments like a script (`$1`, `$2`, …). Use `local` to keep a variable inside the function:

```bash
greet() {
  local name="$1"
  echo "Hello, $name!"
}
greet Sam
greet Alex
```

Functions communicate two ways — don't mix them up:

- **`echo`** a result the caller captures: `msg=$(greet Sam)`
- **`return N`** sets an exit **status** (0–255) for success/failure, tested with `if`:

```bash
is_root() { [[ $EUID -eq 0 ]]; }         # returns the test's own status
if is_root; then echo "root"; else echo "not root"; fi
```

### 8. Debugging — see exactly what runs

When a script misbehaves, trace every line as it executes:

```bash
bash -x ./script.sh      # print each command (expanded) before running it
```

Or trace just a section from inside the script with `set -x` … `set +x`. Combined with [ShellCheck](https://www.shellcheck.net/) (which catches mistakes *before* you run), this is most of debugging.

### 9. Cron — running scripts on a schedule (a taste)

Once you can write a script, you'll want it to run **automatically** — a nightly backup, a health check every 5 minutes. **Cron** is the classic Unix scheduler. Edit your schedule with `crontab -e`; each line is 5 time fields, then the command:

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

!!! tip "Cron runs with a minimal environment"
    Always use **absolute paths** (`/home/vagrant/scripts/x.sh`, not `~/scripts/x.sh`) and don't rely on your aliases or custom `PATH`. Redirect output to a log so you can see what happened.

### 10. Viewing logs — `journalctl` and syslog

When a scheduled job or a service misbehaves, the logs tell you what actually happened. **Ubuntu 24.04 collects logs in systemd's journal** (`systemd-journald`), which you read with `journalctl`:

```bash
journalctl -e                            # jump to the newest entries
journalctl -f                            # follow live, like 'tail -f'; Ctrl-C to stop
journalctl -n 50                         # the last 50 lines
journalctl -u ssh                        # logs for ONE service/unit (ssh, cron, nginx…)
journalctl -u cron --since "10 min ago"  # did my cron job actually run?
journalctl -p err -b                     # only errors, since this boot
journalctl -k                            # kernel messages (same as 'dmesg')
```

!!! note "syslog on Ubuntu 24.04"
    The classic flat files — `/var/log/syslog`, `/var/log/auth.log` — are written by **rsyslog**, which is **not installed by default** on Ubuntu 24.04; logs now live in the journal. If a machine does have rsyslog, read them the usual way:
    ```bash
    sudo tail -f /var/log/syslog        # live system log
    sudo grep sshd /var/log/auth.log    # authentication events
    ```
    Install it with `sudo apt install rsyslog` only if you specifically need the flat files.

---

## Lab · ~50 min

Work **inside your Vagrant VM**. Keep scripts in `~/scripts`:

```bash
mkdir -p ~/scripts && cd ~/scripts
```

### Step 1 — Decisions with `if`/`elif`/`else`

```bash
cat > classify.sh << 'EOF'
#!/bin/bash
set -euo pipefail

n="${1:-0}"
if   [[ $n -gt 0 ]]; then echo "$n is positive"
elif [[ $n -lt 0 ]]; then echo "$n is negative"
else                      echo "$n is zero"
fi
EOF

chmod +x classify.sh
./classify.sh 7
./classify.sh -3
./classify.sh 0
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
  *)      echo "usage: $0 {start|stop|status}" >&2; exit 1 ;;
esac
EOF

chmod +x svc.sh
./svc.sh start
./svc.sh status
./svc.sh            # prints usage to stderr, exits 1
```

### Step 3 — Loops, ranges, and `continue`

```bash
cat > listetc.sh << 'EOF'
#!/bin/bash
set -euo pipefail

for item in /etc/*; do
  [[ -d "$item" ]] || continue      # skip files, keep only directories
  echo "DIR  $item"
done
EOF

chmod +x listetc.sh
./listetc.sh | head
```

### Step 4 — `while read`: process lines

```bash
cat > shells.sh << 'EOF'
#!/bin/bash
set -euo pipefail

# print each real login shell listed on this system
while IFS= read -r shell; do
  echo "shell: $shell"
done < /etc/shells
EOF

chmod +x shells.sh
./shells.sh
```

### Step 5 — Arguments with validation

```bash
cat > greet.sh << 'EOF'
#!/bin/bash
set -euo pipefail

if [[ $# -eq 0 ]]; then
  echo "usage: $0 <name> [name...]" >&2
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

### Step 7 — Debug it with `bash -x`

```bash
bash -x ./diskcheck.sh    # watch each command expand and run — great for "why did that happen?"
```

### Step 8 — Schedule it with cron (a taste)

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

journalctl -u cron --since "5 min ago"   # the system's own record that cron fired your job

crontab -e                 # now delete that line and save to clean up
```

---

## Advanced Topics

You can now write real, decision-making scripts. When you're ready to level up, these are the next rungs — read the linked resource for each:

- **Arrays** — hold and loop over lists of values properly → [GNU — Arrays](https://www.gnu.org/software/bash/manual/html_node/Arrays.html)
- **`[ ]` vs `[[ ]]` and every test operator** — why `[[ ]]` is safer, and the full operator set → [GNU — Conditional Expressions](https://www.gnu.org/software/bash/manual/html_node/Bash-Conditional-Expressions.html) · [wooledge — BashFAQ 031](https://mywiki.wooledge.org/BashFAQ/031)
- **`getopts` & `trap`** — parse real `-flags`, and run cleanup on exit or Ctrl-C → [GNU — Shell Builtins](https://www.gnu.org/software/bash/manual/html_node/Bourne-Shell-Builtins.html)
- **systemd timers** — the modern, observable alternative to cron → [ArchWiki — systemd/Timers](https://wiki.archlinux.org/title/Systemd/Timers)

---

## Assignment

These are two scripts you'll genuinely reuse as a DevOps engineer — a real backup tool and a real monitor. Start both with `set -euo pipefail`.

1. **`backup.sh` — a timestamped backup tool.** Take a source directory as `$1`. If it's missing or isn't a directory, print usage to **stderr** and `exit 1`. Otherwise create a compressed archive under `~/backups` (create the dir if needed) named with a **timestamp** so backups never overwrite each other — `backup-YYYYmmdd-HHMMSS.tar.gz` (*hint:* `date +%Y%m%d-%H%M%S` inside command substitution). Use `tar -czf`, and on success print the archive's path and its human-readable size (`du -h`). Run it twice a few seconds apart and confirm you get **two distinct files**.

2. **`healthguard.sh` — a threshold monitor.** Turn yesterday's numbers into decisions. Write a **function** `check` that takes a *label*, a *current value*, and a *limit*, and prints `OK` or `ALERT` using `if`/`elif`/`else`. Call it for **disk %** and **RAM %** (reuse the commands from your Day 6 `diskusage.sh` and `meminfo.sh`). Make the whole script **`exit 1` if anything is in ALERT**, so a scheduler or CI job can detect the failure automatically.

*Stretch — backup retention.* Extend `backup.sh` (or write `rotate.sh`) to keep only the **5 most recent** backups in `~/backups`, deleting older ones — feed a sorted list into a `while read` loop (*hint:* `ls -1t ~/backups/backup-*.tar.gz | tail -n +6` lists everything past the newest five). Then schedule `backup.sh` with **cron** to run every 2 minutes, confirm two runs produced two archives, and remove the cron entry.

Run every script through [ShellCheck](https://www.shellcheck.net/), and trace at least one with `bash -x` to see it execute.

---

## Further Reading

- [crontab.guru](https://crontab.guru/) — build and read cron schedules interactively
- [GNU Bash manual — Conditional Constructs](https://www.gnu.org/software/bash/manual/html_node/Conditional-Constructs.html) — the reference for `if`, `case`, and loops
- [wooledge — BashGuide](https://mywiki.wooledge.org/BashGuide) — the best free end-to-end bash tutorial
- [journalctl(1) manual](https://man7.org/linux/man-pages/man1/journalctl.1.html) · [ArchWiki — systemd/Journal](https://wiki.archlinux.org/title/Systemd/Journal) — reading logs in depth
- Run [ShellCheck](https://www.shellcheck.net/) on every script you wrote this week
- [Beyond the Basics](beyond-the-basics.md) — see "systemd timers" for the modern alternative to cron
