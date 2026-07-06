# Day 06 · Shell Scripting I — Programming Basics

> Days 6 and 7 are your gentle introduction to **programming with the shell** — no prior coding needed. **Today** covers the absolute basics: storing values, printing, reading input, and doing simple math. **Tomorrow** adds decisions, loops, and functions. One small step at a time.

## Learning Objectives

- Write and run your very first shell scripts
- Store and reuse values with **variables**
- Print output and read **input** from the user
- Do arithmetic and comparisons with **operators**
- Capture a command's output with **command substitution**

---

## Theory · ~15 min

### What is a script?

A script is just a plain text file with commands in it, run from top to bottom. Instead of typing commands one at a time, you save them in a file and run them together — repeatably.

The first line is the **shebang**, which says *which program runs this file*:

```bash
#!/bin/bash
echo "This is my first script"
```

Make it executable, then run it:

```bash
chmod +x myscript.sh     # allow it to run (Day 4 permissions!)
./myscript.sh            # run it
```

### Printing output — `echo` and `printf`

```bash
echo "Hello, world"
echo "Multiple" "words" "become spaced"
printf "Name: %s  Score: %d\n" "Sam" 42   # %s = string, %d = number, \n = newline
```

`echo` is the everyday tool; `printf` gives you precise formatting when you need it.

### Variables — storing a value

A **variable** holds a value you can reuse. The rules are simple but strict:

```bash
name="Sam"          # NO spaces around the =
count=5
greeting="Hello there"
```

!!! warning "No spaces around `=`"
    `name = "Sam"` is an error — bash thinks `name` is a command. It must be `name="Sam"`.

### Variable substitution — using a value

Put a `$` in front of the name to insert its value. Use `${...}` braces when the name touches other text:

```bash
name="Sam"
echo "Hello, $name"        # Hello, Sam
file="report"
echo "${file}.txt"         # report.txt   (braces keep it separate from .txt)
```

!!! tip "Always quote your variables"
    Write `"$name"`, not `$name`. Quoting prevents surprises when a value contains spaces. This one habit prevents most beginner scripting bugs.

### Reading input from the user

```bash
read -rp "What is your name? " name
echo "Nice to meet you, $name"
```

`-p` shows a prompt; `-r` is a safety flag you should always include.

### Operators — doing math and comparisons

Arithmetic goes inside `$(( ... ))`:

```bash
a=6
b=4
echo $(( a + b ))     # 10
echo $(( a - b ))     # 2
echo $(( a * b ))     # 24
echo $(( a / b ))     # 1  (integer division)
```

Comparison operators produce true/false and become important tomorrow with conditionals:

| Numbers | Meaning | Strings | Meaning |
|---|---|---|---|
| `-eq` | equal | `==` | equal |
| `-ne` | not equal | `!=` | not equal |
| `-lt` `-gt` | less / greater | `-z "$s"` | is empty |
| `-le` `-ge` | ≤ / ≥ | `-n "$s"` | is non-empty |

### Command substitution — capturing output

`$( ... )` runs a command and hands you its output as a value:

```bash
today=$(date +%F)
echo "Today is $today"

files=$(ls | wc -l)
echo "There are $files items in this folder"

me=$(whoami)
echo "Logged in as $me"
```

This is how scripts pull real data from the system.

---

## Lab · ~50 min

Work **inside your Vagrant VM**. Keep your scripts in `~/scripts`.

```bash
mkdir -p ~/scripts && cd ~/scripts
```

### Step 1 — Your first script

```bash
cat > first.sh << 'EOF'
#!/bin/bash
echo "Hello from my first script!"
echo "The time is now."
EOF

chmod +x first.sh
./first.sh
```

### Step 2 — Variables

```bash
cat > vars.sh << 'EOF'
#!/bin/bash
name="DevOps Student"
week=1
echo "Hello, $name"
echo "You are in week $week"
EOF

chmod +x vars.sh
./vars.sh
```

### Step 3 — Variable substitution with braces

```bash
cat > filename.sh << 'EOF'
#!/bin/bash
base="backup"
ext="tar.gz"
echo "Full name: ${base}.${ext}"
EOF

chmod +x filename.sh
./filename.sh
```

### Step 4 — Read input

```bash
cat > ask.sh << 'EOF'
#!/bin/bash
read -rp "What's your name?      " name
read -rp "Favorite Linux tool?   " tool
echo "$name likes $tool — good choice!"
EOF

chmod +x ask.sh
./ask.sh
```

### Step 5 — Arithmetic

```bash
cat > math.sh << 'EOF'
#!/bin/bash
read -rp "First number:  " a
read -rp "Second number: " b
echo "Sum:     $(( a + b ))"
echo "Product: $(( a * b ))"
EOF

chmod +x math.sh
./math.sh
```

### Step 6 — Command substitution (put it together)

```bash
cat > hello-system.sh << 'EOF'
#!/bin/bash
user=$(whoami)
host=$(hostname)
today=$(date +%F)
echo "Hi $user! You are on '$host' and today is $today."
EOF

chmod +x hello-system.sh
./hello-system.sh
```

Notice how each script adds exactly one new idea on top of the last. That's the whole game — small, composable steps.

---

## Assignment

Create these in `my-progress/day-06/` and commit the scripts.

1. **`profile.sh`** — ask the user for their name and their favorite DevOps tool (`read`), store each in a variable, then print a friendly two-line summary using variable substitution.
2. **`calc.sh`** — ask for two numbers and print their **sum, difference, and product** using arithmetic operators. *(Bonus: also print today's date using command substitution.)*

```bash
git add my-progress/day-06/
git commit -m "day-06: shell scripting basics"
git push origin main
```

---

## Further Reading

- [Bash for Beginners (video series, Microsoft)](https://learn.microsoft.com/en-us/shows/bash-for-beginners/)
- [ShellCheck](https://www.shellcheck.net/) — paste a script and it flags mistakes (`sudo apt install shellcheck`)
- `help read`, `help echo` — bash built-in help
- [explainshell.com](https://explainshell.com) — paste any command to see each part explained
