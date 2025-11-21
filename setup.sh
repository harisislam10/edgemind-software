#!/bin/bash

##############################################################################
# EdgeMind Yocto Ubuntu Setup Script
# This script automates the installation of Docker, Hailo drivers, and 
# required packages for Yocto-based Ubuntu systems
##############################################################################

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HAILO_RT_VERSION="4.23.0"
KERNEL_VERSION=$(uname -r)
TARGET_KERNEL_SOURCE="/usr/src/${KERNEL_VERSION}"
KERNEL_BUILD_SYMLINK="/lib/modules/${KERNEL_VERSION}/build"

##############################################################################
# Helper Functions
##############################################################################

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root or with sudo"
        log_error "Usage: sudo ./setup.sh"
        exit 1
    fi
}

##############################################################################
# Docker Installation
##############################################################################

install_docker() {
    log_step "STEP 1/8: Installing Docker and Docker Compose"
    
    # Check if Docker is already installed
    if command -v docker &> /dev/null; then
        log_info "Docker is already installed"
        docker --version
        
        # Check if Docker daemon is running
        if systemctl is-active --quiet docker; then
            log_info "Docker daemon is running"
        else
            log_info "Starting Docker daemon..."
            systemctl start docker
            systemctl enable docker
        fi
        
        # Check Docker Compose plugin
        if docker compose version &> /dev/null; then
            log_info "Docker Compose plugin is installed"
            docker compose version
            return 0
        fi
    fi
    
    log_info "Installing Docker..."
    
    # Update package list
    apt update
    
    # Install prerequisites
    log_info "Installing prerequisites..."
    apt install -y ca-certificates curl gnupg lsb-release
    
    # Add Docker's official GPG key
    log_info "Adding Docker GPG key..."
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc

    # Add the repository to Apt sources
    log_info "Adding Docker repository..."
    cat > /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

    # Install Docker
    log_info "Installing Docker packages..."
    apt update
    apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Start and enable Docker
    systemctl start docker
    systemctl enable docker
    
    # Test Docker installation
    log_info "Testing Docker installation..."
    docker run --rm hello-world
    
    log_info "✓ Docker installed successfully!"
    docker --version
    docker compose version
}

##############################################################################
# Custom Packages Installation
##############################################################################

install_custom_packages() {
    log_step "STEP 2/8: Installing System Packages"
    
    log_info "Updating package lists..."
    apt update
    
    # Essential build tools
    log_info "Installing build tools..."
    apt install -y build-essential bc bison flex libssl-dev libelf-dev dwarves
    
    # Common utilities
    log_info "Installing utilities..."
    apt install -y git wget curl vim nano net-tools htop iotop rsync
    
    # Python (if needed)
    log_info "Installing Python..."
    apt install -y python3 python3-pip
    
    # Development tools
    apt install -y pkg-config autoconf automake libtool
    
    # ===== ADD YOUR CUSTOM PACKAGES BELOW =====
    
    # Example:
    # apt install -y your-package-here
    
    
    
    # ===== END CUSTOM PACKAGES =====
    
    log_info "✓ System packages installed successfully!"
}

##############################################################################
# Kernel Source Setup
##############################################################################

setup_kernel_source() {
    log_step "STEP 3/8: Setting up Kernel Source"
    
    log_info "Detected kernel version: ${KERNEL_VERSION}"
    log_info "Target directory: ${TARGET_KERNEL_SOURCE}"
    
    # Check if we need to extract kernel-build from TAR
    if [ ! -d "${SCRIPT_DIR}/kernel-build" ] || [ -z "$(ls -A ${SCRIPT_DIR}/kernel-build 2>/dev/null)" ]; then
        if [ -f "${SCRIPT_DIR}/tars/kernel-build.tar.gz" ]; then
            log_info "Extracting kernel-build.tar.gz..."
            log_info "This will take 1-2 minutes..."
            
            # Verify TAR is valid before extracting
            if ! tar tzf "${SCRIPT_DIR}/tars/kernel-build.tar.gz" >/dev/null 2>&1; then
                log_error "kernel-build.tar.gz is corrupted or invalid!"
                log_error "Please re-run copy-kernel-files.sh on build host"
                exit 1
            fi
            
            # Extract to a temp location first
            TEMP_DIR=$(mktemp -d)
            tar xzf "${SCRIPT_DIR}/tars/kernel-build.tar.gz" -C "${TEMP_DIR}"
            
            # Find the extracted directory (could be 'build' or other name)
            EXTRACTED_DIR=$(find "${TEMP_DIR}" -mindepth 1 -maxdepth 1 -type d | head -n 1)
            
            if [ -z "${EXTRACTED_DIR}" ]; then
                log_error "No directory found in kernel-build.tar.gz"
                rm -rf "${TEMP_DIR}"
                exit 1
            fi
            
            # Move to final location
            mv "${EXTRACTED_DIR}" "${SCRIPT_DIR}/kernel-build"
            rm -rf "${TEMP_DIR}"
            
            if [ -f "${SCRIPT_DIR}/kernel-build/Module.symvers" ]; then
                log_info "✓ kernel-build extracted successfully"
                MODULE_SIZE=$(du -h "${SCRIPT_DIR}/kernel-build/Module.symvers" | cut -f1)
                log_info "  Module.symvers: ${MODULE_SIZE}"
            else
                log_error "✗ Failed to extract kernel-build properly"
                log_error "Module.symvers not found after extraction"
                exit 1
            fi
        else
            log_error "kernel-build TAR file not found!"
            log_error "Expected: ${SCRIPT_DIR}/tars/kernel-build.tar.gz"
            log_error ""
            log_error "Please run copy-kernel-files.sh on build host first"
            exit 1
        fi
    else
        log_info "kernel-build directory already exists, skipping extraction"
    fi
    
    # Check if we need to extract kernel-source from TAR
    if [ ! -d "${SCRIPT_DIR}/kernel-source" ] || [ -z "$(ls -A ${SCRIPT_DIR}/kernel-source 2>/dev/null)" ]; then
        if [ -f "${SCRIPT_DIR}/tars/kernel-source.tar.gz" ]; then
            log_info "Extracting kernel-source.tar.gz..."
            log_info "This may take 3-5 minutes..."
            
            # Verify TAR is valid
            if ! tar tzf "${SCRIPT_DIR}/tars/kernel-source.tar.gz" >/dev/null 2>&1; then
                log_warn "kernel-source.tar.gz is corrupted, skipping"
            else
                # Extract to temp location
                TEMP_DIR=$(mktemp -d)
                tar xzf "${SCRIPT_DIR}/tars/kernel-source.tar.gz" -C "${TEMP_DIR}"
                
                # Find the extracted directory
                EXTRACTED_DIR=$(find "${TEMP_DIR}" -mindepth 1 -maxdepth 1 -type d | head -n 1)
                
                if [ -n "${EXTRACTED_DIR}" ]; then
                    mv "${EXTRACTED_DIR}" "${SCRIPT_DIR}/kernel-source"
                    rm -rf "${TEMP_DIR}"
                    
                    if [ -f "${SCRIPT_DIR}/kernel-source/Makefile" ]; then
                        log_info "✓ kernel-source extracted successfully"
                    else
                        log_warn "⚠ kernel-source extraction may be incomplete"
                    fi
                else
                    log_warn "⚠ No directory found in kernel-source.tar.gz"
                    rm -rf "${TEMP_DIR}"
                fi
            fi
        else
            log_info "No kernel-source TAR found (optional, continuing...)"
        fi
    else
        log_info "kernel-source directory already exists, skipping extraction"
    fi
    
    # Verify critical files exist
    if [ ! -f "${SCRIPT_DIR}/kernel-build/Module.symvers" ]; then
        log_error "Module.symvers not found in kernel-build!"
        log_error "This file is CRITICAL for driver compilation"
        log_error "Expected: ${SCRIPT_DIR}/kernel-build/Module.symvers"
        exit 1
    fi
    
    if [ ! -f "${SCRIPT_DIR}/kernel-build/Makefile" ]; then
        log_error "Makefile not found in kernel-build!"
        log_error "Expected: ${SCRIPT_DIR}/kernel-build/Makefile"
        exit 1
    fi
    
    # Remove broken 'source' symlink if it exists
    if [ -L "${SCRIPT_DIR}/kernel-build/source" ]; then
        log_info "Removing broken 'source' symlink..."
        rm "${SCRIPT_DIR}/kernel-build/source"
    fi
    
    # Create proper 'source' symlink if kernel-source exists
    if [ -d "${SCRIPT_DIR}/kernel-source" ] && [ -f "${SCRIPT_DIR}/kernel-source/Makefile" ]; then
        log_info "Creating 'source' symlink to kernel-source..."
        cd "${SCRIPT_DIR}/kernel-build"
        ln -s "../kernel-source" "source"
    fi
    
    # Show file info
    MODULE_SIZE=$(du -h "${SCRIPT_DIR}/kernel-build/Module.symvers" | cut -f1)
    log_info "Module.symvers size: ${MODULE_SIZE} (should be ~1.1MB)"
    
    # Backup existing kernel source if it exists
    if [ -d "${TARGET_KERNEL_SOURCE}" ]; then
        BACKUP_DIR="${TARGET_KERNEL_SOURCE}.backup.$(date +%Y%m%d_%H%M%S)"
        log_warn "Existing kernel source found"
        log_info "Creating backup: ${BACKUP_DIR}"
        mv "${TARGET_KERNEL_SOURCE}" "${BACKUP_DIR}"
    fi
    
    # Create target directory
    log_info "Creating kernel source directory..."
    mkdir -p "${TARGET_KERNEL_SOURCE}"
    
    # Copy kernel build artifacts
    log_info "Copying kernel build artifacts..."
    log_info "This may take a few moments..."
    cp -r "${SCRIPT_DIR}/kernel-build/"* "${TARGET_KERNEL_SOURCE}/"
    
    # Copy kernel source if available
    if [ -d "${SCRIPT_DIR}/kernel-source" ] && [ -n "$(ls -A ${SCRIPT_DIR}/kernel-source 2>/dev/null)" ]; then
        log_info "Kernel source detected, copying..."
        
        # Remove broken 'source' symlink if exists
        if [ -L "${TARGET_KERNEL_SOURCE}/source" ]; then
            rm "${TARGET_KERNEL_SOURCE}/source"
        fi
        
        # Create separate source directory and symlink
        SOURCE_DIR="/usr/src/kernel-source-${KERNEL_VERSION}"
        mkdir -p "${SOURCE_DIR}"
        cp -r "${SCRIPT_DIR}/kernel-source/"* "${SOURCE_DIR}/"
        ln -s "${SOURCE_DIR}" "${TARGET_KERNEL_SOURCE}/source"
        
        log_info "Kernel source copied to: ${SOURCE_DIR}"
    else
        log_warn "kernel-source directory not found or empty"
        log_warn "This is OK - driver installation should still work"
    fi
    
    # Verify copy was successful
    if [ -f "${TARGET_KERNEL_SOURCE}/Module.symvers" ]; then
        log_info "✓ Kernel source setup completed!"
    else
        log_error "✗ Failed to copy kernel files!"
        exit 1
    fi
}

##############################################################################
# Update Kernel Build Symlink
##############################################################################

update_kernel_build_symlink() {
    log_step "STEP 4/8: Updating Kernel Build Symlink"
    
    log_info "Symlink path: ${KERNEL_BUILD_SYMLINK}"
    log_info "Target: ${TARGET_KERNEL_SOURCE}"
    
    # Check if /lib/modules/<kernel-version> exists
    if [ ! -d "/lib/modules/${KERNEL_VERSION}" ]; then
        log_error "Kernel modules directory not found!"
        log_error "Expected: /lib/modules/${KERNEL_VERSION}"
        log_error "Your kernel may not be installed correctly"
        exit 1
    fi
    
    # Fix Makefile paths in target kernel source BEFORE creating symlink
    if [ -f "${TARGET_KERNEL_SOURCE}/Makefile" ]; then
        log_info "Fixing Makefile include paths..."
        
        # Check if kernel-source directory exists
        KERNEL_SOURCE_DIR="/usr/src/kernel-source-${KERNEL_VERSION}"
        
        if [ -d "${KERNEL_SOURCE_DIR}" ]; then
            # Replace hardcoded path with the actual kernel-source path
            log_info "  Pointing to: ${KERNEL_SOURCE_DIR}"
            sed -i "s|include .*/kernel-source/Makefile|include ${KERNEL_SOURCE_DIR}/Makefile|g" "${TARGET_KERNEL_SOURCE}/Makefile"
            sed -i "s|include /home/.*/Makefile|include ${KERNEL_SOURCE_DIR}/Makefile|g" "${TARGET_KERNEL_SOURCE}/Makefile"
            
            # Fix srctree to point to kernel-source
            sed -i "s|^srctree := .*|srctree := ${KERNEL_SOURCE_DIR}|g" "${TARGET_KERNEL_SOURCE}/Makefile"
        elif [ -d "${TARGET_KERNEL_SOURCE}/source" ]; then
            # If source subdirectory exists, use it
            log_info "  Pointing to: ${TARGET_KERNEL_SOURCE}/source"
            sed -i "s|include .*/kernel-source/Makefile|include \$(srctree)/Makefile|g" "${TARGET_KERNEL_SOURCE}/Makefile"
            sed -i "s|include /home/.*/Makefile|include \$(srctree)/Makefile|g" "${TARGET_KERNEL_SOURCE}/Makefile"
            sed -i "s|^srctree := .*|srctree := \$(CURDIR)/source|g" "${TARGET_KERNEL_SOURCE}/Makefile"
        else
            # Fallback: use current directory
            log_info "  Pointing to: current directory"
            sed -i "s|include .*/kernel-source/Makefile|include \$(srctree)/Makefile|g" "${TARGET_KERNEL_SOURCE}/Makefile"
            sed -i "s|include /home/.*/Makefile|include \$(srctree)/Makefile|g" "${TARGET_KERNEL_SOURCE}/Makefile"
            sed -i "s|^srctree := .*|srctree := .|g" "${TARGET_KERNEL_SOURCE}/Makefile"
        fi
        
        # Also fix objtree
        sed -i "s|^objtree := .*|objtree := .|g" "${TARGET_KERNEL_SOURCE}/Makefile"
        
        log_info "✓ Makefile paths fixed"
    fi
    
    # Remove old symlink/directory if exists
    if [ -L "${KERNEL_BUILD_SYMLINK}" ] || [ -d "${KERNEL_BUILD_SYMLINK}" ]; then
        log_info "Removing old build symlink/directory..."
        rm -rf "${KERNEL_BUILD_SYMLINK}"
    fi
    
    # Create new symlink
    log_info "Creating symlink..."
    ln -s "${TARGET_KERNEL_SOURCE}" "${KERNEL_BUILD_SYMLINK}"
    
    # Verify symlink
    if [ -L "${KERNEL_BUILD_SYMLINK}" ]; then
        log_info "✓ Symlink created successfully!"
        ls -l "${KERNEL_BUILD_SYMLINK}"
    else
        log_error "✗ Failed to create symlink!"
        exit 1
    fi
}


##############################################################################
# Prepare Kernel Modules (CRITICAL STEP)
##############################################################################

prepare_kernel_modules() {
    log_step "STEP 5/8: Preparing Kernel Modules (CRITICAL)"
    
    log_info "This step rebuilds kernel scripts from x86_64 to ARM64"
    log_info "This fixes the 'Exec format error' issue"
    log_info ""
    
    cd "${TARGET_KERNEL_SOURCE}"
    
    # Check current architecture of fixdep
    if [ -f "scripts/basic/fixdep" ]; then
        log_info "Current fixdep architecture:"
        file scripts/basic/fixdep || true
        echo ""
    fi
    
    # Clean any previous builds
    log_info "Cleaning previous build artifacts..."
    make clean 2>/dev/null || log_warn "Clean failed (may be OK if first run)"
    
    # Rebuild scripts for ARM64
    log_info "Rebuilding kernel scripts for ARM64..."
    log_info "This will take 2-3 minutes..."
    

    if ! make modules_prepare; then
        log_error "Failed to rebuild scripts!"
        log_error "Check if build tools are installed"
        exit 1
    fi
    
    
    # Verify fixdep is now ARM64
    log_info ""
    if [ -f "scripts/basic/fixdep" ]; then
        log_info "Verifying fixdep is now ARM64:"
        file scripts/basic/fixdep
        
        if file scripts/basic/fixdep | grep -q "ARM aarch64"; then
            log_info "✓ Scripts successfully rebuilt for ARM64!"
        else
            log_error "✗ Scripts are still not ARM64!"
            log_error "Module compilation will likely fail"
            exit 1
        fi
    else
        log_error "fixdep not found after rebuild!"
        exit 1
    fi
    
    log_info ""
    log_info "✓ Kernel modules prepared successfully!"
}

##############################################################################
# Install HailoRT
##############################################################################

install_hailo_rt() {
    log_step "STEP 6/8: Installing HailoRT ${HAILO_RT_VERSION}"
    
    HAILO_DEB="${SCRIPT_DIR}/hailort-driver/hailort_${HAILO_RT_VERSION}_arm64.deb"
    
    if [ ! -f "${HAILO_DEB}" ]; then
        log_error "HailoRT package not found!"
        log_error "Expected: ${HAILO_DEB}"
        log_error ""
        log_error "Please ensure the file exists in:"
        log_error "  ${SCRIPT_DIR}/hailort-driver/"
        exit 1
    fi
    
    log_info "Found HailoRT package: $(basename ${HAILO_DEB})"
    
    # Remove old version if exists
    if dpkg -l | grep -q hailort; then
        log_info "Removing old HailoRT version..."
        dpkg --purge hailort 2>/dev/null || true
    fi
    
    # Install
    log_info "Installing HailoRT..."
    if ! dpkg -i "${HAILO_DEB}"; then
        log_warn "dpkg reported errors, attempting to fix dependencies..."
        apt install -f -y
    fi
    
    # Verify installation
    if command -v hailortcli &> /dev/null; then
        log_info "✓ HailoRT installed successfully!"
        hailortcli --version || true
    else
        log_error "✗ HailoRT installation failed!"
        log_error "hailortcli command not found"
        exit 1
    fi
}

##############################################################################
# Install Hailo PCIe Driver
##############################################################################

install_hailo_pcie_driver() {
    log_step "STEP 7/8: Installing Hailo PCIe Driver"
    
    HAILO_PCIE_DEB="${SCRIPT_DIR}/hailo-pcie-driver/hailort-pcie-driver_${HAILO_RT_VERSION}_all.deb"
    
    if [ ! -f "${HAILO_PCIE_DEB}" ]; then
        log_error "Hailo PCIe driver package not found!"
        log_error "Expected: ${HAILO_PCIE_DEB}"
        log_error ""
        log_error "Please ensure the file exists in:"
        log_error "  ${SCRIPT_DIR}/hailo-pcie-driver/"
        exit 1
    fi
    
    log_info "Found Hailo PCIe driver: $(basename ${HAILO_PCIE_DEB})"
    
    # Remove old version if exists
    if dpkg -l | grep -q hailort-pcie-driver; then
        log_info "Removing old Hailo PCIe driver..."
        dpkg --purge hailort-pcie-driver 2>/dev/null || true
    fi
    
    # Install with DKMS
    log_info "Installing Hailo PCIe driver with DKMS..."
    log_info "DKMS will compile the driver for your kernel"
    log_info "This will take 2-3 minutes..."
    
    # Use noninteractive mode to auto-answer "Yes" to DKMS
    if ! DEBIAN_FRONTEND=noninteractive dpkg -i "${HAILO_PCIE_DEB}"; then
        log_warn "dpkg reported errors, attempting to fix dependencies..."
        apt install -f -y
    fi
    
    # Check DKMS status
    log_info "Checking DKMS build status..."
    dkms status | grep hailo || log_warn "DKMS status not showing hailo module"
    
    # Try to load the module
    log_info "Loading Hailo PCIe driver..."
    if modprobe hailo_pci 2>/dev/null; then
        log_info "✓ Hailo PCIe driver loaded successfully!"
    else
        log_warn "⚠ Failed to load driver automatically"
        log_warn "Check dmesg for errors: dmesg | grep -i hailo"
        log_warn "Check DKMS log: /var/lib/dkms/hailort-pcie-driver/*/build/make.log"
    fi
    
    # Verify driver is loaded
    if lsmod | grep -q hailo_pci; then
        log_info "✓ Hailo PCIe driver is loaded!"
        echo ""
        lsmod | grep hailo
        echo ""
        
        # Check for Hailo device
        if lspci | grep -i hailo &> /dev/null; then
            log_info "✓ Hailo PCIe device detected!"
            lspci | grep -i hailo
        else
            log_warn "⚠ No Hailo PCIe device found"
            log_warn "Make sure Hailo card is properly installed"
        fi
    else
        log_warn "⚠ Hailo driver not loaded"
        log_warn "You may need to reboot or check dmesg for errors"
    fi
}

##############################################################################
# Setup Docker Compose
##############################################################################

setup_docker_compose() {
    log_step "STEP 8/8: Setting up Docker Compose Services"
    
    DOCKER_COMPOSE_FILE="${SCRIPT_DIR}/docker-compose.yml"
    
    if [ ! -f "${DOCKER_COMPOSE_FILE}" ]; then
        log_warn "docker-compose.yml not found"
        log_warn "Location: ${DOCKER_COMPOSE_FILE}"
        log_warn "Skipping Docker Compose setup"
        return 0
    fi
    
    log_info "Found docker-compose.yml"
    
    cd "${SCRIPT_DIR}"
    
    # Stop any existing services
    if docker compose ps -q 2>/dev/null | grep -q .; then
        log_info "Stopping existing services..."
        docker compose down
    fi
    
    # Start services
    log_info "Starting Docker Compose services..."
    if docker compose up -d; then
        log_info "✓ Docker Compose services started!"
        echo ""
        docker compose ps
    else
        log_error "✗ Failed to start Docker Compose services"
        log_error "Check: docker compose logs"
        exit 1
    fi
}

##############################################################################
# Main Installation Flow
##############################################################################

print_banner() {
    echo -e "${BLUE}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════════════════╗
║                                                                   ║
║           EdgeMind Yocto Ubuntu Setup Script                      ║
║                                                                   ║
║  Automated installation of:                                       ║
║    • Docker & Docker Compose                                      ║
║    • Kernel modules preparation                                   ║
║    • HailoRT 4.23.0                                               ║
║    • Hailo PCIe driver                                            ║
║    • Docker services                                              ║
║                                                                   ║
║                                                                   ║            
║                   Prepared by: Haris                              ║                    
╚═══════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

print_summary() {
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}           SETUP COMPLETED SUCCESSFULLY!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${BLUE}System Information:${NC}"
    echo "  Kernel Version: ${KERNEL_VERSION}"
    echo "  Kernel Source: ${TARGET_KERNEL_SOURCE}"
    echo "  Docker Version: $(docker --version)"
    echo "  HailoRT: $(hailortcli --version 2>&1 | head -n1 || echo 'Installed')"
    echo ""
    echo -e "${BLUE}Verification Commands:${NC}"
    echo "  Check Docker:        docker ps"
    echo "  Check Hailo driver:  lsmod | grep hailo"
    echo "  Check Hailo device:  lspci | grep -i hailo"
    echo "  Test HailoRT:        hailortcli fw-control identify"
    echo "  Check services:      docker compose ps"
    echo "  View service logs:   docker compose logs"
    echo ""
    echo -e "${BLUE}Run Complete Validation:${NC}"
    echo "  sudo ./validate.sh"
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
}

main() {
    # Print banner
    print_banner
    
    # Check root
    check_root
    
    log_info "Installation started: $(date)"
    log_info "Kernel version: ${KERNEL_VERSION}"
    log_info "Script directory: ${SCRIPT_DIR}"
    echo ""
    
    # Run all installation steps
    install_docker
    install_custom_packages
    setup_kernel_source
    update_kernel_build_symlink
    prepare_kernel_modules
    install_hailo_rt
    install_hailo_pcie_driver
    setup_docker_compose
    
    # Print summary
    print_summary
    
    log_info "Installation completed: $(date)"
}

# Run main function
main "$@"