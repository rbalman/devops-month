# Day 15 · Vagrant — Local VM Provisioning

## Learning Objectives

- Spin up and destroy virtual machines with a single command
- Write a Vagrantfile to define and provision a VM
- Use Vagrant as a local test environment for server configurations

---

## Theory · ~20 min

### Why Vagrant?

Before you configure a real cloud server, you need a safe place to experiment. Vagrant gives you **reproducible, disposable VMs** on your local machine — defined entirely in code (a `Vagrantfile`).

You can:
- Spin up a fresh Ubuntu VM in ~60 seconds
- Wreck it and recreate it instantly
- Share the `Vagrantfile` so teammates get the exact same environment

Vagrant sits on top of a **provider** (VirtualBox, VMware, Hyper-V) and abstracts the VM management into simple CLI commands.

### The Vagrantfile

A `Vagrantfile` is Ruby syntax, but you only need to know a small subset:

```ruby
Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"     # base OS image
  config.vm.network "private_network", ip: "192.168.56.10"
  config.vm.provider "virtualbox" do |vb|
    vb.memory = "1024"
    vb.cpus = 2
  end

  config.vm.provision "shell", inline: <<-SHELL
    apt-get update
    apt-get install -y nginx
  SHELL
end
```

### Key Commands

| Command | What it does |
|---|---|
| `vagrant up` | Start (and create) the VM |
| `vagrant ssh` | SSH into the VM |
| `vagrant halt` | Shut down the VM |
| `vagrant destroy` | Delete the VM entirely |
| `vagrant reload` | Restart the VM (picks up Vagrantfile changes) |
| `vagrant provision` | Re-run provisioners without restarting |
| `vagrant status` | Show VM state |
| `vagrant box list` | List downloaded base images |

---

## Lab · ~50 min

### Step 1 — Install Vagrant

```bash
# Install VirtualBox (if not done on Day 01)
sudo apt install -y virtualbox

# Install Vagrant
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

sudo apt update && sudo apt install -y vagrant

vagrant --version
```

### Step 2 — Your first VM

```bash
mkdir -p ~/vagrant-labs/basic
cd ~/vagrant-labs/basic

# Initialize with Ubuntu 22.04
vagrant init ubuntu/jammy64

# Look at the generated Vagrantfile
cat Vagrantfile

# Start the VM (first run downloads the box ~500MB)
vagrant up

# SSH in
vagrant ssh

# You're now inside the VM
uname -a
cat /etc/os-release
ip addr
exit

# Back on your host
vagrant status
```

### Step 3 — Customize the Vagrantfile

```bash
cat > Vagrantfile << 'EOF'
Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/jammy64"
  config.vm.hostname = "devops-lab"

  # Private network with static IP
  config.vm.network "private_network", ip: "192.168.56.10"

  # Forward host port 8080 to VM port 80
  config.vm.network "forwarded_port", guest: 80, host: 8080

  config.vm.provider "virtualbox" do |vb|
    vb.name   = "devops-lab"
    vb.memory = "1024"
    vb.cpus   = 1
  end

  # Shell provisioner — runs once on first 'vagrant up'
  config.vm.provision "shell", inline: <<-SHELL
    apt-get update -q
    apt-get install -y nginx curl git
    systemctl enable nginx
    systemctl start nginx
    echo "<h1>Provisioned by Vagrant</h1>" > /var/www/html/index.html
    echo "Provisioning complete!"
  SHELL
end
EOF

# Reload picks up config changes (VM already running)
vagrant reload

# Re-run provisioners
vagrant provision

# Test: access nginx in the VM from your host
curl http://192.168.56.10
curl http://localhost:8080
```

### Step 4 — Multi-machine setup

```bash
mkdir -p ~/vagrant-labs/multi
cd ~/vagrant-labs/multi

cat > Vagrantfile << 'EOF'
Vagrant.configure("2") do |config|

  config.vm.define "webserver" do |web|
    web.vm.box      = "ubuntu/jammy64"
    web.vm.hostname = "webserver"
    web.vm.network  "private_network", ip: "192.168.56.11"
    web.vm.provider "virtualbox" do |vb|
      vb.memory = "512"
    end
    web.vm.provision "shell", inline: "apt-get update -q && apt-get install -y nginx"
  end

  config.vm.define "db" do |db|
    db.vm.box      = "ubuntu/jammy64"
    db.vm.hostname = "db"
    db.vm.network  "private_network", ip: "192.168.56.12"
    db.vm.provider "virtualbox" do |vb|
      vb.memory = "512"
    end
    db.vm.provision "shell", inline: "apt-get update -q && apt-get install -y postgresql"
  end

end
EOF

vagrant up
vagrant status

# SSH into specific machines
vagrant ssh webserver
vagrant ssh db

# From webserver, ping db
vagrant ssh webserver -c "ping -c 3 192.168.56.12"

# Clean up
vagrant destroy -f
```

### Step 5 — Sync files between host and VM

```bash
cd ~/vagrant-labs/basic

# Vagrant mounts your project directory at /vagrant in the VM
vagrant ssh -c "ls /vagrant"    # you should see your Vagrantfile

# Create a file on the host
echo "hello from host" > hello.txt

# Read it from the VM
vagrant ssh -c "cat /vagrant/hello.txt"

# Create a file in the VM
vagrant ssh -c "echo 'hello from vm' > /vagrant/from-vm.txt"

# It appears on your host
cat from-vm.txt
```

---

## Assignment

In `my-progress/day-15.md`:

1. Write a `Vagrantfile` that provisions a VM with:
   - 1 GB RAM, 2 CPUs
   - Static IP `192.168.56.20`
   - Nginx installed and serving a custom `index.html` with your name
   - Port 80 forwarded to host port 9090
2. What is the difference between `vagrant halt` and `vagrant destroy`?
3. What does the `/vagrant` shared folder do? Why is it useful for DevOps workflows?
4. When would you choose Vagrant over Docker for a lab environment?

```bash
cp -r ~/vagrant-labs/basic my-progress/vagrant-basic
git add my-progress/
git commit -m "day-15: vagrant vm provisioning"
git push origin main
```

---

## Further Reading

- [Vagrant documentation](https://developer.hashicorp.com/vagrant/docs)
- [Vagrant boxes on Vagrant Cloud](https://app.vagrantup.com/boxes/search)
- [Comparing Vagrant and Docker](https://developer.hashicorp.com/vagrant/intro/vs/docker)
