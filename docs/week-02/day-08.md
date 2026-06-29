# Day 08 · Networking I — IP, Ports, TCP/UDP

## Learning Objectives

- Understand IP addresses, subnets, and how packets travel
- Know the difference between TCP and UDP
- Use ports and identify what's listening on your machine

---

## Theory · ~20 min

### IP Addresses

Every device on a network has an IP address — a unique identifier for routing packets to the right destination.

**IPv4**: 4 octets, e.g. `192.168.1.100` — 32 bits, ~4 billion addresses  
**IPv6**: 8 groups of 4 hex digits, e.g. `2001:db8::1` — 128 bits, essentially unlimited

**Private IP ranges** (not routable on the public internet):

| Range | Common Use |
|---|---|
| `10.0.0.0/8` | Corporate networks, AWS VPCs |
| `172.16.0.0/12` | Docker default networks |
| `192.168.0.0/16` | Home routers, local networks |

**`127.0.0.1`** (localhost) — always refers to your own machine.

### Subnets and CIDR

A **subnet** is a range of IP addresses. CIDR notation (`/24`, `/16`) defines how many bits are the "network" part:

- `192.168.1.0/24` → 256 addresses: `192.168.1.0` – `192.168.1.255`
- `10.0.0.0/8` → 16 million addresses

The `/` prefix length = how many bits are fixed. Higher prefix = smaller network.

### TCP vs UDP

| | TCP | UDP |
|---|---|---|
| Connection | Yes (3-way handshake) | No |
| Reliability | Guaranteed delivery, ordered | Best-effort, no guarantee |
| Speed | Slower | Faster |
| Use cases | HTTP, SSH, databases | DNS, video streaming, games |

**TCP 3-way handshake**:
```
Client → SYN →    Server
Client ← SYN-ACK ← Server
Client → ACK →    Server
[Connection established]
```

### Ports

Ports are logical endpoints that allow multiple services to share one IP address.

| Port | Protocol |
|---|---|
| 22 | SSH |
| 80 | HTTP |
| 443 | HTTPS |
| 3306 | MySQL |
| 5432 | PostgreSQL |
| 6379 | Redis |
| 8080 | Common app dev port |

Ports 1–1023 are **well-known** and require root to bind. Ports 1024–65535 are user-space.

---

## Lab · ~50 min

### Step 1 — Your network configuration

```bash
# Show all network interfaces and IPs
ip addr show
ip addr show eth0    # or ens33, enp0s3, etc.

# Default route (where packets go by default)
ip route show

# On older systems
ifconfig
```

What is your:
- Private IP address?
- Network interface name?
- Default gateway?

### Step 2 — Test connectivity

```bash
# ICMP ping (tests if host is reachable)
ping -c 4 8.8.8.8           # Google DNS
ping -c 4 google.com        # tests DNS resolution + reachability

# Trace the path packets take
traceroute 8.8.8.8          # install: sudo apt install traceroute
# or
mtr 8.8.8.8                 # interactive (q to quit)
```

### Step 3 — Ports and what's listening

```bash
# Install net-tools if not already done
sudo apt install -y net-tools

# Show all listening ports
ss -tlnp              # recommended
netstat -tlnp         # older tool, same result

# ss flags:
# -t = TCP, -u = UDP
# -l = listening only
# -n = numeric ports (don't resolve names)
# -p = show process name/PID
```

What's listening on your machine right now?

### Step 4 — Make a connection and inspect it

```bash
# Start a simple listener on port 9000
nc -l 9000 &
PID=$!

# Connect to it from another terminal (or same terminal)
nc localhost 9000 &
sleep 1

# See the active connection
ss -tnp | grep 9000

# Clean up
kill $PID
```

### Step 5 — curl for HTTP inspection

```bash
# Make an HTTP request
curl http://example.com

# Show headers only
curl -I http://example.com

# Show full request/response headers
curl -v http://example.com 2>&1 | head -40

# Specify a port
curl http://localhost:80

# Time the request
curl -w "\nTotal time: %{time_total}s\n" -o /dev/null -s http://google.com
```

---

## Assignment

In `my-progress/day-08.md`:

1. What is your machine's private IP and what network interface carries it?
2. Run `traceroute 8.8.8.8`. How many hops does it take? What is the first hop (your gateway)?
3. List all ports currently listening on your machine. Which process is listening on port 22? On port 80?
4. What is the difference between a port and an IP address? Explain it in one paragraph as if speaking to a non-technical person.

```bash
git add my-progress/day-08.md
git commit -m "day-08: networking basics I"
git push origin main
```

---

## Further Reading

- [Subnet calculator](https://www.subnet-calculator.com/)
- [Cloudflare: What is TCP/IP?](https://www.cloudflare.com/learning/ddos/glossary/tcp-ip/)
- `man ss`, `man ip`
