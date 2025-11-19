# Yocto Ubuntu Setup Scripts

Complete automation for setting up Yocto-based Ubuntu systems with Docker, Hailo drivers, and custom packages.

## 📋 Prerequisites

- Yocto-based Ubuntu system (ARM architecture)
- Root/sudo access
- Internet connection for package downloads

## 📦 What This Does

1. ✅ Installs Docker CE and Docker Compose
2. ✅ Sets up kernel source and build directories
3. ✅ Prepares kernel modules
4. ✅ Installs HailoRT 4.23.0
5. ✅ Installs Hailo PCIe driver
6. ✅ Installs custom packages
7. ✅ Starts Docker Compose services

## 🚀 Quick Start

### Step 1: Clone the Repository

```bash
git clone <your-repo-url>
cd <repo-directory>
```

### Step 2: Prepare Required Files

Create the following directory structure:

```
your-repo/
├── setup.sh                          # Main setup script
├── update-kernel-source.sh           # Kernel update script
├── docker-compose.yaml               # Your Docker Compose file
├── kernel-source/                    # (Initially empty - populated by update script)
├── kernel-build/                     # (Initially empty - populated by update script)
├── hailo-pcie-driver/               # Hailo PCIe driver source
└── hailort_4.23.0_arm64.deb         # HailoRT package
```

### Step 3: Add Your Files

#### 3.1 Docker Compose File
Place your `docker-compose.yaml` in the root directory.

#### 3.2 HailoRT Package
Download and place the HailoRT 4.23.0 package:
```bash
# Download from Hailo website or your source
cp hailort_4.23.0_arm64.deb ./
```

#### 3.3 Hailo PCIe Driver
Extract the Hailo PCIe driver source:
```bash
# Extract driver to hailo-pcie-driver directory
tar -xzf hailo-pcie-driver.tar.gz
# or
unzip hailo-pcie-driver.zip
```

#### 3.4 Kernel Source (First Time Setup)
Run the kernel update script from your Yocto build machine:
```bash
chmod +x update-kernel-source.sh
./update-kernel-source.sh --build-dir /path/to/your/yocto/build
```

This will copy kernel source and build directories to the correct locations.

### Step 4: Make Scripts Executable

```bash
chmod +x setup.sh
chmod +x update-kernel-source.sh
```

### Step 5: Run the Setup

```bash
sudo ./setup.sh
```

The script will:
- Install all dependencies
- Set up kernel environment
- Install Hailo drivers
- Start Docker services

## 🔧 Updating Kernel Source

When you create a new Yocto build, update the kernel source:

### Option 1: Automated Update

```bash
./update-kernel-source.sh --build-dir /path/to/yocto/build
```

### Option 2: Manual Update

If you know the exact paths:

```bash
# Copy kernel source
cp -r /path/to/yocto/build/tmp/work-shared/*/kernel-source/* ./kernel-source/

# Copy kernel build
cp -r /path/to/yocto/build/tmp/work/*/linux-*/build/* ./kernel-build/
```

Then run setup again:
```bash
sudo ./setup.sh
```

## 📝 Adding Custom Packages

Edit `setup.sh` and add your packages in the marked section:

```bash
# Find this section in setup.sh
install_custom_packages() {
    log_info "Installing custom packages..."
    
    apt update
    
    # ===== ADD YOUR CUSTOM PACKAGES BELOW =====
    apt install -y vim git wget curl
    apt install -y python3 python3-pip
    apt install -y build-essential
    # Add more packages as needed
    # ===== END CUSTOM PACKAGES =====
    
    log_info "Custom packages installed successfully!"
}
```

## 🎯 For Trainees

### Simple 3-Step Process

1. **Clone the repository:**
   ```bash
   git clone <repo-url>
   cd <repo-name>
   ```

2. **Make setup script executable:**
   ```bash
   chmod +x setup.sh
   ```

3. **Run the setup:**
   ```bash
   sudo ./setup.sh
   ```

That's it! Everything will be installed automatically.

## ✅ Verification

After setup completes, verify everything is working:

### Check Docker
```bash
docker --version
docker compose version
docker ps
```

### Check Hailo Driver
```bash
lsmod | grep hailo
hailortcli fw-control identify
```

### Check Docker Services
```bash
cd <repo-directory>
docker compose ps
```

### Check Web Server
If your docker-compose.yaml exposes a web server, access it via browser or:
```bash
curl http://localhost:<your-port>
```

## 🔍 Troubleshooting

### Docker not starting
```bash
sudo systemctl status docker
sudo systemctl restart docker
```

### Hailo driver not loading
```bash
# Check kernel logs
dmesg | grep hailo

# Try loading manually
sudo modprobe hailo_pci
```

### Kernel modules preparation failed
```bash
# Verify kernel source exists
ls -la /usr/src/kernel/

# Manually prepare modules
cd /usr/src/kernel/
sudo make modules_prepare
```

### Docker Compose services not starting
```bash
# Check logs
docker compose logs

# Restart services
docker compose down
docker compose up -d
```

## 📁 Directory Structure Explained

```
.
├── setup.sh                       # Main installation script
├── update-kernel-source.sh        # Kernel update automation
├── docker-compose.yaml            # Docker services configuration
├── kernel-source/                 # Kernel source files
│   ├── Makefile
│   ├── include/
│   └── ...
├── kernel-build/                  # Kernel build artifacts
│   └── ...
├── hailo-pcie-driver/            # Hailo PCIe driver source
│   ├── Makefile
│   └── ...
└── hailort_4.23.0_arm64.deb      # HailoRT package
```

## 🔄 Automated Updates in CI/CD

To automatically update kernel source in your build pipeline:

```bash
# In your Yocto build script, after build completes:
./update-kernel-source.sh --build-dir $BUILD_DIR
git add kernel-source/ kernel-build/
git commit -m "Update kernel source from build $(date)"
git push
```

## 🆘 Support

If you encounter issues:

1. Check the script output for error messages
2. Verify all required files are in place
3. Ensure you have root/sudo access
4. Check system logs: `sudo journalctl -xe`

## 📌 Important Notes

- **Always run with sudo**: The script needs root access for system modifications
- **Internet required**: Initial setup downloads packages from Docker repositories
- **Backup important data**: Before running on production systems
- **Kernel source update**: Required after each new Yocto build
- **Docker Compose version**: Uses Docker Compose v2 (plugin version)

## 🎓 Training Checklist

For trainees, ensure they can:

- [ ] Clone the repository
- [ ] Verify required files are present
- [ ] Run the setup script
- [ ] Verify Docker installation
- [ ] Check Hailo driver status
- [ ] Access the web server
- [ ] Run basic Docker commands
- [ ] Update kernel source when needed

## 📝 Change Log

When updating kernel source or packages, document changes:

```bash
# Create a changelog entry
echo "$(date): Updated kernel source from build XYZ" >> CHANGELOG.md
```

## 🔐 Security Notes

- Scripts require root access - review before running
- Docker socket has elevated privileges
- Keep HailoRT packages up to date
- Regularly update system packages: `sudo apt update && sudo apt upgrade`

---

**Questions or Issues?** Contact your team lead or system administrator.


