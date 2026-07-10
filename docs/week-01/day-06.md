# Day 06 · Shell Scripting I — Fundamentals

> Days 6–7 are your gentle on-ramp to **programming with the shell** — no prior coding needed. **Today (the first half)** is the toolkit every script is built from: writing and running a file, printing, variables, quoting, input, math, and reporting success. **Tomorrow (the second half)** teaches scripts to make decisions, repeat work, and organize into functions. Each idea builds on the last.

## Learning Objectives

- Write, save, and run a script from the shebang up
- Comment your code and print cleanly with `echo` and `printf`
- Store values in **variables** and **quote** them correctly
- Read user **input** and do **arithmetic**
- Capture a command's output with **command substitution**
- Report success or failure with **exit codes**

---

## Theory · ~20 min

### 1. A script is just a file of commands

A script is a plain text file of commands, run top to bottom — type once, run forever. The first line is the **shebang**: it tells the system which interpreter runs the file.

```bash
#!/bin/bash
# lines starting with # are COMMENTS — notes for humans, ignored by bash
echo "This is my first script"
```

Make it executable (Day 4 permissions!) and run it:

```bash
chmod +x myscript.sh     # grant the execute bit
./myscript.sh            # run it  ( ./ = "the file right here" )
```

!!! note "Why `./`?"
    Without `./`, the shell only searches your `PATH` (Day 5) — and the current folder isn't on it. `./myscript.sh` says *run this exact file*.

### 2. Printing — `echo` and `printf`

```bash
echo "Hello, world"
printf "%s is %d years old\n" "Sam" 42    # %s = string, %d = number, \n = newline
```

`echo` is the everyday tool; `printf` gives precise, repeatable formatting — reach for it when output needs to line up or follow an exact shape.

### 3. Variables — store a value

```bash
name="Sam"          # NO spaces around =
count=5
```

!!! warning "No spaces around `=`"
    `name = "Sam"` fails — bash reads `name` as a *command*. It must be `name="Sam"`.

Read a variable back with `$`. Braces `${...}` keep the name separate from surrounding text:

```bash
echo "Hello, $name"
file="report"
echo "${file}.txt"        # report.txt  (without braces, bash looks for $filetxt)
```

### 4. Quoting — the habit that prevents most bugs

Quoting decides whether the shell **expands** what's inside. This is the single biggest source of beginner scripting bugs, so learn it now:

| Quotes | `$var` expands? | Use for |
|---|---|---|
| `"double"` | **yes** | almost everything — text containing variables |
| `'single'` | **no** — fully literal | exact text, or when you mean a literal `$` |
| none | yes, **and splits on spaces** | avoid around values |

```bash
name="Sam Smith"
echo "$name"        # Sam Smith          ← safe
echo '$name'        # $name              ← literal, no expansion
echo $name          # Sam Smith  BUT passed as TWO words — breaks on spaces & globs
```

!!! tip "Rule of thumb"
    **Always wrap variables in double quotes** — `"$name"`, `"$@"`, `"$(cmd)"` — unless you have a specific reason not to.

### 5. Defaults with parameter expansion

`${var:-default}` substitutes `default` when `var` is unset or empty, so a script doesn't break on missing input. `${#var}` gives its length:

```bash
echo "Deploying to ${ENVIRONMENT:-staging}"   # 'staging' when ENVIRONMENT is unset
echo "Name is ${#name} characters"            # length of $name
```

### 6. Reading input

```bash
read -rp "What is your name? " name
echo "Nice to meet you, $name"
```

`-p` shows the prompt; `-r` keeps backslashes literal (always include it).

### 7. Arithmetic

Integer math goes inside `$(( ... ))`:

```bash
a=6; b=4
echo $(( a + b ))     # 10
echo $(( a * b ))     # 24
echo $(( a / b ))     # 1   (integer division)
```

!!! note "Shells do integer math only"
    `$(( 7 / 2 ))` is `3`, not `3.5`. For decimals you'd reach for `bc` or `awk` (see Advanced Topics).

### 8. Command substitution — capture output into a value

`$( ... )` runs a command and hands back its output:

```bash
today=$(date +%F)
echo "Today is $today"
count=$(ls | wc -l)
echo "$count items here"
```

This is how scripts pull live data from the system.

### 9. Exit codes — reporting success or failure

Day 5 showed every command returns an exit code (`$?`): `0` = success, non-zero = failure. Your script sets its own with `exit`:

```bash
mkdir -p ~/backups || exit 1     # bail out (exit 1) if mkdir failed — Day 5's ||
echo "backup dir ready"
exit 0                           # 0 = success (also the default at the end)
```

!!! tip "Send errors to stderr"
    Print error messages with `>&2` so they land on **stderr** (Day 5), not mixed into real output: `echo "something broke" >&2`.

---

## Lab · ~50 min

Work **inside your Vagrant VM**. Keep scripts in `~/scripts`:

```bash
mkdir -p ~/scripts && cd ~/scripts
```

### Step 1 — Your first script

```bash
cat > first.sh << 'EOF'
#!/bin/bash
# my very first script
echo "Hello from my first script!"
EOF

chmod +x first.sh
./first.sh
```

### Step 2 — Variables and braces

```bash
cat > vars.sh << 'EOF'
#!/bin/bash
name="DevOps Student"
week=1
echo "Hello, $name"
echo "You are in week ${week}"
EOF

chmod +x vars.sh
./vars.sh
```

### Step 3 — Quoting in action

See the three quoting styles diverge with your own eyes:

```bash
cat > quotes.sh << 'EOF'
#!/bin/bash
who="Sam Smith"
echo "double: $who"     # expands
echo 'single: $who'     # literal
echo naked:  $who       # expands AND splits — watch the spacing collapse
EOF

chmod +x quotes.sh
./quotes.sh
```

### Step 4 — Read input and do math

```bash
cat > calc.sh << 'EOF'
#!/bin/bash
read -rp "First number:  " a
read -rp "Second number: " b
echo "Sum:     $(( a + b ))"
echo "Product: $(( a * b ))"
EOF

chmod +x calc.sh
./calc.sh
```

### Step 5 — Command substitution: a system snapshot

```bash
cat > snapshot.sh << 'EOF'
#!/bin/bash
user=$(whoami)
host=$(hostname)
today=$(date +%F)
items=$(ls "$HOME" | wc -l)
printf "%s@%s — %s — %d items in home\n" "$user" "$host" "$today" "$items"
EOF

chmod +x snapshot.sh
./snapshot.sh
```

### Step 6 — Defaults and an exit code

```bash
cat > backupdir.sh << 'EOF'
#!/bin/bash
# create a backup dir named by today's date, with a sensible default location
base="${1:-$HOME/backups}"
dir="$base/$(date +%F)"

mkdir -p "$dir" || { echo "could not create $dir" >&2; exit 1; }
echo "ready: $dir"
exit 0
EOF

chmod +x backupdir.sh
./backupdir.sh                 # uses the default ~/backups
./backupdir.sh /tmp/mybackups  # uses the path you pass
echo "exit code: $?"
```

Notice how each script adds exactly one new idea on top of the last — small, composable steps.

---

## Advanced Topics

You have everything you need to write useful scripts. When you want to go deeper, these are the next rungs — read the linked resource for each:

- **Quoting & word splitting in depth** — why `"$@"` differs from `$*`, and how splitting really works → [wooledge — Quotes](https://mywiki.wooledge.org/Quotes)
- **Full parameter expansion** — `${var:=default}`, `${var:?error}`, `${var/old/new}`, substrings → [GNU — Shell Parameter Expansion](https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html)
- **Common beginner pitfalls** — the mistakes that bite everyone, with fixes → [wooledge — Bash Pitfalls](https://mywiki.wooledge.org/BashPitfalls)
- **Write scripts the way pros do** — naming, structure, and safety conventions → [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)

---

## Assignment

Three short scripts, each drilling one core skill — the kind of "gather and report" work you do every time you log into an unfamiliar server. They use only today's tools.

1. **`sysinfo.sh` — the first-login snapshot** *(command substitution + quoting)*. Print a clean report of who and where you are: hostname, the user running the script, kernel version (`uname -r`), uptime (`uptime -p`), and the current date & time. Format it with `printf`, **quote every variable**, and start the file with a comment header.

2. **`meminfo.sh` — memory used %** *(arithmetic)*. From `free -m`, read total and used RAM and compute the **used percentage yourself** with `$(( ))`. *Hints:* `free -m | awk 'NR==2 {print $2, $3}'` gives you total and used to capture with command substitution; and since shells do **integer math**, `used * 100 / total` (multiply first) — `used / total * 100` would give `0`.

3. **`diskusage.sh` — inspect any directory** *(parameter defaults + exit codes)*. Take a directory as `$1`, defaulting to `$HOME` (`${1:-$HOME}`). Print its total size (`du -sh`) and the disk space used on `/` (`df -h /`). If `du` fails on the path, print an error to **stderr** and `exit 1` (use Day 5's `||`).

Run every script through [ShellCheck](https://www.shellcheck.net/) before you consider it done.

---

## Further Reading

- [Bash for Beginners (video series, Microsoft)](https://learn.microsoft.com/en-us/shows/bash-for-beginners/)
- [ShellCheck](https://www.shellcheck.net/) — paste a script and it flags mistakes (`sudo apt install shellcheck`)
- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html) — how professionals structure shell scripts
- [explainshell.com](https://explainshell.com) — paste any command to see each part explained
- `help read`, `help echo`, `help printf` — bash built-in help
