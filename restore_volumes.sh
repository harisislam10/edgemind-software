#!/bin/bash

##############################################################################
# Docker Volumes Restore Script
# Restores Docker volumes from backup for EdgeMind installation
##############################################################################

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VOLUMES_BACKUP="hailo_volumes.tar.gz"
DOCKER_VOLUMES_DIR="/var/lib/docker/volumes"

##############################################################################
# Check Prerequisites
##############################################################################

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root or with sudo"
        log_error "Usage: sudo ./restore-volumes.sh"
        exit 1
    fi
}

check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed!"
        log_error "Please run setup.sh first to install Docker"
        exit 1
    fi
    
    if ! systemctl is-active --quiet docker; then
        log_warn "Docker is not running. Starting Docker..."
        systemctl start docker
        sleep 2
    fi
    
    log_info "✓ Docker is installed and running"
}

##############################################################################
# Download Backup if Not Present
##############################################################################

download_backup() {
    log_step "STEP 1: Getting Docker Volumes Backup"
    
    # Check if backup exists locally
    if [ -f "${SCRIPT_DIR}/${VOLUMES_BACKUP}" ]; then
        log_info "Backup file found locally: ${VOLUMES_BACKUP}"
        BACKUP_SIZE=$(du -h "${SCRIPT_DIR}/${VOLUMES_BACKUP}" | cut -f1)
        log_info "Size: ${BACKUP_SIZE}"
        return 0
    fi
    
    # Check if backup exists in parent directory (user's home)
    if [ -f "${HOME}/${VOLUMES_BACKUP}" ]; then
        log_info "Backup file found in home directory"
        cp "${HOME}/${VOLUMES_BACKUP}" "${SCRIPT_DIR}/"
        log_info "✓ Copied to script directory"
        return 0
    fi
    
    # Try Git LFS pull if in git repository
    if [ -d "${SCRIPT_DIR}/.git" ]; then
        log_info "Attempting to download via Git LFS..."
        cd "${SCRIPT_DIR}"
        
        if command -v git-lfs &> /dev/null; then
            git lfs pull --include="${VOLUMES_BACKUP}" 2>/dev/null || true
            
            if [ -f "${SCRIPT_DIR}/${VOLUMES_BACKUP}" ]; then
                log_info "✓ Downloaded via Git LFS"
                return 0
            fi
        fi
    fi
    
    # If still not found, error
    log_error "Backup file not found: ${VOLUMES_BACKUP}"
    log_error ""
    log_error "Please ensure the backup file is available:"
    log_error "  1. Place it in: ${SCRIPT_DIR}/"
    log_error "  2. Or run: git lfs pull"
    log_error "  3. Or copy from: ~/hailosbc_volumes_backup.tar.gz"
    exit 1
}

##############################################################################
# Stop Docker Services
##############################################################################

stop_docker_services() {
    log_step "STEP 2: Stopping Docker Services"
    
    # Check if docker-compose.yml exists
    if [ -f "${SCRIPT_DIR}/docker-compose.yml" ]; then
        log_info "Stopping EdgeMind services..."
        cd "${SCRIPT_DIR}"
        docker compose down 2>/dev/null || true
        log_info "✓ Services stopped"
    else
        log_warn "docker-compose.yml not found, skipping service stop"
    fi
    
    # Give Docker time to release volumes
    sleep 2
}

##############################################################################
# Backup Existing Volumes
##############################################################################

backup_existing_volumes() {
    log_step "STEP 3: Backing Up Existing Volumes"
    
    BACKUP_TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    EXISTING_BACKUP="${SCRIPT_DIR}/volumes_backup_${BACKUP_TIMESTAMP}.tar.gz"
    
    if [ -d "${DOCKER_VOLUMES_DIR}" ] && [ -n "$(ls -A ${DOCKER_VOLUMES_DIR} 2>/dev/null)" ]; then
        log_info "Creating backup of existing volumes..."
        log_info "This may take a few minutes..."
        
        tar czf "${EXISTING_BACKUP}" -C "${DOCKER_VOLUMES_DIR}" . 2>/dev/null || true
        
        if [ -f "${EXISTING_BACKUP}" ]; then
            BACKUP_SIZE=$(du -h "${EXISTING_BACKUP}" | cut -f1)
            log_info "✓ Existing volumes backed up: ${EXISTING_BACKUP}"
            log_info "  Size: ${BACKUP_SIZE}"
            log_info ""
            log_warn "If restore fails, you can recover using:"
            log_warn "  sudo tar xzf ${EXISTING_BACKUP} -C ${DOCKER_VOLUMES_DIR}"
        fi
    else
        log_info "No existing volumes to backup"
    fi
}

##############################################################################
# Extract and Restore Volumes
##############################################################################

restore_volumes() {
    log_step "STEP 4: Restoring Docker Volumes"
    
    log_info "Extracting volumes backup..."
    log_info "Source: ${SCRIPT_DIR}/${VOLUMES_BACKUP}"
    log_info "Target: ${DOCKER_VOLUMES_DIR}"
    log_info ""
    
    # Verify backup file
    if ! tar tzf "${SCRIPT_DIR}/${VOLUMES_BACKUP}" &>/dev/null; then
        log_error "Backup file is corrupted or invalid!"
        exit 1
    fi
    
    # Show what's in the backup
    log_info "Backup contains:"
    tar tzf "${SCRIPT_DIR}/${VOLUMES_BACKUP}" | head -10
    echo "..."
    echo ""
    
    # Extract to Docker volumes directory
    log_info "Extracting... (this may take 5-10 minutes)"
    
    # Ensure target directory exists
    mkdir -p "${DOCKER_VOLUMES_DIR}"
    
    # Extract with progress indication
    tar xzf "${SCRIPT_DIR}/${VOLUMES_BACKUP}" -C "${DOCKER_VOLUMES_DIR}" 2>&1
    
    if [ $? -eq 0 ]; then
        log_info "✓ Volumes extracted successfully!"
    else
        log_error "✗ Failed to extract volumes!"
        exit 1
    fi
    
    # Show what was restored
    log_info ""
    log_info "Restored volumes:"
    ls -lh "${DOCKER_VOLUMES_DIR}" | head -15
    
    # Count volumes
    VOLUME_COUNT=$(ls -1 "${DOCKER_VOLUMES_DIR}" 2>/dev/null | wc -l)
    log_info ""
    log_info "Total volumes restored: ${VOLUME_COUNT}"
}

##############################################################################
# Fix Permissions
##############################################################################

fix_permissions() {
    log_step "STEP 5: Fixing Permissions"
    
    log_info "Setting correct ownership and permissions..."
    
    # Set ownership to root (Docker requirement)
    chown -R root:root "${DOCKER_VOLUMES_DIR}"
    
    # Set appropriate permissions
    find "${DOCKER_VOLUMES_DIR}" -type d -exec chmod 755 {} \;
    find "${DOCKER_VOLUMES_DIR}" -type f -exec chmod 644 {} \;
    
    log_info "✓ Permissions fixed"
}

##############################################################################
# Restart Docker Services
##############################################################################

restart_docker_services() {
    log_step "STEP 6: Starting Docker Services"
    
    # Restart Docker daemon to recognize new volumes
    log_info "Restarting Docker daemon..."
    systemctl restart docker
    sleep 3
    
    # Start EdgeMind services if docker-compose exists
    if [ -f "${SCRIPT_DIR}/docker-compose.yml" ]; then
        log_info "Starting EdgeMind services..."
        cd "${SCRIPT_DIR}"
        docker compose up -d
        
        sleep 5
        
        log_info ""
        log_info "Service status:"
        docker compose ps
    else
        log_warn "docker-compose.yml not found"
        log_info "Start your services manually with: docker compose up -d"
    fi
}

##############################################################################
# Verify Restoration
##############################################################################

verify_restoration() {
    log_step "STEP 7: Verifying Restoration"
    
    # List Docker volumes
    log_info "Docker volumes:"
    docker volume ls
    
    # Check if volumes are accessible
    log_info ""
    log_info "Checking volume accessibility..."
    
    VOLUMES=$(docker volume ls -q)
    ACCESSIBLE=0
    TOTAL=0
    
    for vol in $VOLUMES; do
        TOTAL=$((TOTAL + 1))
        if docker volume inspect "$vol" &>/dev/null; then
            ACCESSIBLE=$((ACCESSIBLE + 1))
        fi
    done
    
    log_info "Accessible volumes: ${ACCESSIBLE}/${TOTAL}"
    
    if [ $ACCESSIBLE -eq $TOTAL ]; then
        log_info "✓ All volumes are accessible!"
    else
        log_warn "⚠ Some volumes may not be accessible"
    fi
}

##############################################################################
# Main
##############################################################################

print_banner() {
    echo -e "${BLUE}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════════════════╗
║                                                                   ║
║           Docker Volumes Restore Script                           ║
║           Restore EdgeMind Docker volumes from backup             ║
║                                                                   ║
╚═══════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

print_summary() {
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}           Volume Restoration Completed!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${BLUE}Summary:${NC}"
    echo "  Volumes directory: ${DOCKER_VOLUMES_DIR}"
    echo "  Backup used: ${VOLUMES_BACKUP}"
    echo "  Docker volumes: $(docker volume ls -q | wc -l)"
    echo ""
    echo -e "${BLUE}Next Steps:${NC}"
    echo "  1. Verify services are running: docker compose ps"
    echo "  2. Check logs: docker compose logs"
    echo "  3. Access web interface: http://localhost"
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
}

main() {
    print_banner
    
    log_info "Starting volume restoration: $(date)"
    log_info "Script directory: ${SCRIPT_DIR}"
    echo ""
    
    # Run all steps
    check_root
    check_docker
    download_backup
    stop_docker_services
    backup_existing_volumes
    restore_volumes
    fix_permissions
    restart_docker_services
    verify_restoration
    
    print_summary
    
    log_info "Restoration completed: $(date)"
}

# Run main function
main "$@"