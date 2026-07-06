# Day 03 · Everything Is a File — Text Processing

## Learning Objectives

- Understand the Unix "everything is a file" philosophy and why it matters
- Read, filter, and transform text with the core text-processing tools
- Combine small tools with pipes to answer real questions about a system
- Know when to reach for `grep`, `sed`, `awk`, `cut`, `tr`, `sort`, and friends

---

## Theory · ~25 min

### "Everything is a file"

One of Unix's defining ideas: almost everything the system exposes is represented as a **file** — something you can open, read, and often write with the same handful of tools.

- Regular files and directories — obvious ones
- **Devices** — your disk is `/dev/sda`, the "black hole" is `/dev/null`
- **Processes** — each has a directory under `/proc/<pid>/`
- **Kernel & hardware state** — readable under `/proc` and `/sys`
- **Pipes and sockets** — inter-process communication, also file-like

Why this matters: because everything looks like a stream of bytes (usually text), the **same small tools work everywhere**. `cat` reads a config file, a log, or `/proc/cpuinfo` identically. Learn the text tools once and you can inspect the entire system.

### Standard streams

Every command has three streams. Understanding them is the key to redirection and pipes:

| Stream | Number | Default |
|---|---|---|
| stdin | 0 | keyboard |
| stdout | 1 | terminal |
| stderr | 2 | terminal |

```bash
command > out.txt        # redirect stdout to a file (overwrite)
command >> out.txt       # append stdout
command 2> err.txt       # redirect stderr
command > all.txt 2>&1   # both stdout and stderr to one file
command 2>/dev/null      # discard errors
cmd1 | cmd2              # pipe stdout of cmd1 into stdin of cmd2
```

### The text-processing toolkit

You'll use these constantly. Each does **one thing well** — you compose them with pipes.

| Tool | One-line purpose |
|---|---|
| `echo` | Print text / variables |
| `cat` | Dump a whole file (or concatenate several) |
| `head` / `tail` | First / last N lines (`tail -f` follows live) |
| `less` | Page through big files without loading it all |
| `wc` | Count lines, words, bytes |
| `grep` | Find lines matching a pattern (regex) |
| `cut` | Slice out columns/fields by delimiter |
| `tr` | Translate or delete characters |
| `sort` | Sort lines |
| `uniq` | Collapse/count adjacent duplicate lines |
| `sed` | Stream editor — find/replace, delete, edit lines |
| `awk` | Field-aware mini-language — columns, math, reports |
| `tee` | Write to a file **and** pass output onward |

### grep — find lines

```bash
grep "error" app.log            # lines containing "error"
grep -i "error" app.log         # case-insensitive
grep -n "error" app.log         # show line numbers
grep -r "TODO" ./src            # recursive through a directory
grep -c "404" access.log        # count matching lines
grep -v "debug" app.log         # INVERT: lines NOT matching
grep -E "warn|error" app.log    # extended regex (OR)
```

### cut & tr — columns and characters

```bash
cut -d: -f1 /etc/passwd         # field 1, delimiter ":" → usernames
cut -d: -f1,7 /etc/passwd       # fields 1 and 7
echo "hello" | tr 'a-z' 'A-Z'   # → HELLO
echo "a,b,c" | tr ',' '\n'      # commas to newlines
```

### sort & uniq — order and counting

```bash
sort names.txt
sort -u names.txt               # sorted, duplicates removed
sort access.log | uniq -c       # count duplicate lines (must sort first!)
sort -rn -k2 data.txt           # numeric, reverse, by 2nd column
```

### sed — stream editing

`sed` edits a stream line by line. Its most common job is find-and-replace:

```bash
sed 's/foo/bar/'  file          # replace FIRST "foo" per line
sed 's/foo/bar/g' file          # replace ALL (global)
sed -n '10,20p'   file          # print only lines 10–20
sed '/^#/d'       file          # delete comment lines
sed -i 's/DEBUG/INFO/g' cfg     # edit the file IN PLACE (-i)
```

### awk — field-aware processing

`awk` splits each line into fields (`$1`, `$2`, …) and is great for columns, filtering, and quick math:

```bash
awk '{print $1}' access.log             # first field of every line
awk -F: '{print $1, $7}' /etc/passwd    # custom delimiter with -F
awk '$3 > 1000' data.txt                # rows where field 3 > 1000
awk '{sum += $1} END {print sum}' n.txt # sum a column
df -h | awk 'NR>1 {print $5, $6}'       # skip header (NR>1), print two cols
```

!!! tip "grep finds, sed edits, awk computes"
    A rough rule of thumb: **grep** to *find* lines, **sed** to *change* lines, **awk** when you care about *fields/columns or arithmetic*. Most real one-liners chain two or three of these with pipes.

---

## Lab · ~50 min

Work **inside your Vagrant VM** (`vagrant ssh`).

### Step 1 — See "everything is a file"

```bash
cat /proc/cpuinfo | head -20        # CPU info, as a file
cat /proc/meminfo | head -5         # memory, as a file
cat /etc/os-release                 # config, as a file
echo "gone" > /dev/null             # the black hole discards input
```

### Step 2 — Redirection and streams

```bash
cd ~ && mkdir -p textlab && cd textlab

echo "line one" > notes.txt         # overwrite
echo "line two" >> notes.txt        # append
cat notes.txt

ls /nope 2>errors.txt               # capture stderr
cat errors.txt

ls /etc /nope > combined.txt 2>&1   # both streams together
cat combined.txt
```

### Step 3 — Explore /etc/passwd with the toolkit

```bash
wc -l /etc/passwd                   # how many accounts?
cut -d: -f1 /etc/passwd             # just usernames
cut -d: -f1,7 /etc/passwd | head    # username + login shell
grep -v "nologin\|false" /etc/passwd | cut -d: -f1   # real login users

# Count how many accounts use each shell
cut -d: -f7 /etc/passwd | sort | uniq -c | sort -rn
```

### Step 4 — Build and mine a sample log

```bash
cat > access.log << 'EOF'
10.0.0.1 GET /home 200
10.0.0.2 GET /login 200
10.0.0.1 POST /login 401
10.0.0.3 GET /home 200
10.0.0.2 GET /admin 403
10.0.0.1 GET /missing 404
10.0.0.3 GET /home 500
EOF

grep " 200 " access.log                       # successful requests
grep -c " 200 " access.log                    # how many succeeded
awk '{print $1}' access.log | sort | uniq -c  # requests per IP
awk '$4 >= 400 {print $2, $3, $4}' access.log # only errors (status >= 400)
awk '{print $4}' access.log | sort | uniq -c | sort -rn  # status breakdown
```

### Step 5 — sed transformations

```bash
sed 's/GET/FETCH/g' access.log        # replace in the stream (not the file)
sed -n '2,4p' access.log              # print lines 2–4 only
sed '/404/d' access.log               # drop lines containing 404

cp access.log editable.log
sed -i 's/10\.0\.0\./192.168.1./g' editable.log   # in-place edit
head editable.log
```

### Step 6 — tr and tee

```bash
echo "DevOps Month" | tr 'a-z' 'A-Z'
echo "one two three" | tr ' ' '\n'

# tee: see output AND save it at the same time
awk '{print $1}' access.log | sort | uniq -c | tee ip-counts.txt
cat ip-counts.txt
```

### Step 7 — Put it together (a real one-liner)

```bash
# Top 3 IPs by number of error responses (status >= 400)
awk '$4 >= 400 {print $1}' access.log | sort | uniq -c | sort -rn | head -3
```

Read that pipeline left to right: *filter errors → keep the IP → sort → count duplicates → sort by count → top 3.* That composition is the whole point of the Unix philosophy.

---

## Assignment

Apply the toolkit to **new inputs** (not the lab's `access.log`). In `my-progress/day-03.md`:

1. **Process report:** Run `ps aux` and write a **single pipeline** that prints the top 3 users by number of running processes, most first. Explain each stage of the pipeline.
2. **Group membership:** From `/etc/group`, use `awk -F:` to print every group that has at least one member, showing the group name and its members. (Hint: field 4 is the member list; keep only lines where it's non-empty.)

```bash
git add my-progress/day-03.md
git commit -m "day-03: everything is a file, text processing"
git push origin main
```

---

## Further Reading

- `man grep`, `man sed`, `man awk` — and [the awk one-true book (GAWK manual)](https://www.gnu.org/software/gawk/manual/gawk.html)
- [sed one-liners](https://catonmat.net/sed-one-liners-explained)
- [The Unix philosophy](https://en.wikipedia.org/wiki/Unix_philosophy)
- [regexr.com](https://regexr.com/) — build and test regular expressions interactively
