# EdgeMind Installation Guide - For Trainees

Simple installation guide for setting up EdgeMind software on your board.

---

## 📋 Prerequisites

- Board with Ubuntu (ARM architecture)
- Internet connection
- Sudo access

---

## 🚀 Installation Steps

### Step 1: Update System and Install Git

```bash
sudo apt update
sudo apt install git
```

### Step 2: Install Git LFS (Large File Storage)

Git LFS is needed to download large kernel files from the repository.

```bash
sudo apt install git-lfs
git lfs install
```

### Step 3: Clone the Repository

```bash
git clone https://github.com/harisislam10/edgemind_installation.git
cd edgemind_installation
```

### Step 4: Download Large Files

The kernel TAR files are stored with Git LFS. Pull them:

```bash
git lfs pull
```

**Wait for download to complete.** This downloads kernel-build.tar.gz and kernel-source.tar.gz files.

### Step 5: Make Setup Script Executable

```bash
chmod +x setup.sh
```

### Step 6: Run the Setup

```bash
sudo ./setup.sh
```

**This will take 10-15 minutes.** The script will:
- Install Docker and Docker Compose
- Extract and configure kernel files
- Install Hailo drivers
- Start EdgeMind services

**⚠️ Important:** Let the script complete fully. Do not interrupt!

---

## ✅ Verify Installation

After setup completes, check if everything is working:

```bash
# Check Docker
docker ps

# Check Hailo driver
lsmod | grep hailo

# Check EdgeMind services
docker compose ps
```

All checks should pass without errors.

---

## 🌐 Accessing EdgeMind Web Interface

### Option 1: On the Board (Falcon-1)

Open Chrome browser and go to:
```
http://localhost
```

### Option 2: From Remote Computer (SSH Tunnel)

If you're accessing the board remotely over network:

```bash
# On your computer, run this SSH command:
ssh -L 8080:localhost:80 -L 5000:localhost:5000 -L 8000:localhost:8000 -L 8787:localhost:8787 user@<board-ip-address>

# Replace <board-ip-address> with actual IP
# Example: ssh -L 8080:localhost:80 -L 5000:localhost:5000 -L 8000:localhost:8000 -L 8787:localhost:8787 user@192.168.1.100
```

Then open Chrome on your computer and go to:
```
http://localhost:8080
```

**Available ports:**
- `http://localhost:8080` - Main web interface
- `http://localhost:5000` - API service
- `http://localhost:8000` - Additional service
- `http://localhost:8787` - Additional service

---

## 🆘 If Something Goes Wrong

### Script Stops with Error

**DO NOT panic!** 

1. **Take a screenshot** of the error message
2. **Note down** which step failed (Docker installation, Hailo driver, etc.)
3. **Copy the error text** if possible
4. **Contact Us** with:
   - Screenshot of error
   - Step number where it failed
   - Any error messages shown

### Common Issues

**"Permission denied" error:**
```bash
# Make sure you're using sudo
sudo ./setup.sh
```

**"git lfs not found" error:**
```bash
# Install git-lfs
sudo apt install git-lfs
git lfs install
```

**"Cannot connect to Docker daemon" error:**
```bash
# Restart Docker service
sudo systemctl restart docker
# Then run setup again
sudo ./setup.sh
```

**Large files not downloaded:**
```bash
# Pull Git LFS files manually
cd edgemind_installation
git lfs pull
```

---

## 📝 Installation Checklist

Before reporting completion, verify:

- [ ] `sudo ./setup.sh` completed without errors
- [ ] `docker ps` shows running containers
- [ ] `lsmod | grep hailo` shows hailo_pci module
- [ ] Web interface accessible at `localhost` or via SSH tunnel
- [ ] No error messages in terminal

---

## 🔄 Starting/Stopping Services

### Stop Services
```bash
cd edgemind_installation
docker compose down
```

### Start Services
```bash
cd edgemind_installation
docker compose up -d
```

### Restart Services
```bash
cd edgemind_installation
docker compose restart
```

### View Logs
```bash
cd edgemind_installation
docker compose logs
```

---

## 📊 System Information

After installation, you can check:

```bash
# Docker version
docker --version

# Hailo driver info
hailortcli fw-control identify

# Running services
docker compose ps

# System resources
htop
```

---

## 🎯 Quick Commands Reference

```bash
# Check if services are running
docker ps

# Check Hailo device
lspci | grep -i hailo

# Check logs
docker compose logs -f

# Restart everything
docker compose restart

# Stop everything
docker compose down

# Start everything
docker compose up -d
```

---

## 📞 Getting Help

If you encounter any issues:

1. **Take screenshots** of errors
2. **Note the exact step** where it failed
3. **Copy error messages**
4. **Contact Us** with all the above information

**Email:** [haris.islam@elliancesystem.com]  


---

## ⚡ Quick Summary

```bash
# Complete installation in 6 commands:
sudo apt update && sudo apt install git git-lfs
git lfs install
git clone https://github.com/harisislam10/edgemind_installation.git
cd edgemind_installation
git lfs pull
chmod +x setup.sh
sudo ./setup.sh
```

**That's it!** Wait 10-15 minutes for completion.

---

## 🔐 Important Notes

- ✅ Always use `sudo` when running setup.sh
- ✅ Make sure Git LFS is installed before cloning
- ✅ Don't interrupt the setup script
- ✅ Take screenshots if errors occur and email us.


---

**Installation complete? Great! Now you can start testing EdgeMind software.** 🎉