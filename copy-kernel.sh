#!/bin/bash

##############################################################################
# Copy Kernel Files from Yocto Build - Create TAR Files Only
# Run this on your BUILD HOST to create kernel TAR files
# Creates: tars/kernel-build.tar.gz and tars/kernel-source.tar.gz
##############################################################################

set -e

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

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
YOCTO_BASE="${HOME}/BSPs/nxp/imxdesktop/build-desktop"

# You can override with command line argument
if [ -n "$1" ]; then
    YOCTO_BASE="$1"
fi

echo -e "${BLUE}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════════════╗
║                                                                   ║
║           Kernel TAR Files Creator                                ║
║           Creates compressed TAR files for GitHub upload          ║
║                                                                   ║
╚═══════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

log_info "Script directory: ${SCRIPT_DIR}"
log_info "Yocto build base: ${YOCTO_BASE}"
echo ""

# Check if Yocto build directory exists
if [ ! -d "${YOCTO_BASE}" ]; then
    log_error "Yocto build directory not found: ${YOCTO_BASE}"
    echo ""
    log_error "Please update the path in this script or pass it as argument:"
    echo "  ./copy-kernel-files.sh /path/to/your/yocto/build"
    exit 1
fi

##############################################################################
# Find Kernel Build Directory
##############################################################################

log_info "Searching for kernel build directory..."

# Find Module.symvers (most reliable)
MODULE_SYMVERS=$(find "${YOCTO_BASE}/tmp/work" -name "Module.symvers" -path "*/linux-imx/*/build/Module.symvers" 2>/dev/null | head -n 1)

if [ -z "${MODULE_SYMVERS}" ]; then
    MODULE_SYMVERS=$(find "${YOCTO_BASE}/tmp/work" -name "Module.symvers" -path "*/linux*/*/build/Module.symvers" 2>/dev/null | head -n 1)
fi

if [ -z "${MODULE_SYMVERS}" ]; then
    log_error "Could not find Module.symvers!"
    log_error "Please check if Yocto kernel build is complete"
    exit 1
fi

KERNEL_BUILD_DIR=$(dirname "${MODULE_SYMVERS}")

log_info "✓ Found kernel build directory:"
log_info "  ${KERNEL_BUILD_DIR}"
echo ""

# Verify critical files
MODULE_SYMVERS_SIZE=$(du -h "${KERNEL_BUILD_DIR}/Module.symvers" | cut -f1)
log_info "Verifying kernel build files:"
log_info "  ✓ Module.symvers: ${MODULE_SYMVERS_SIZE}"

if [ -f "${KERNEL_BUILD_DIR}/Makefile" ]; then
    log_info "  ✓ Makefile: OK"
fi

if [ -d "${KERNEL_BUILD_DIR}/scripts" ]; then
    log_info "  ✓ scripts/: OK"
fi

##############################################################################
# Find Kernel Source Directory
##############################################################################

echo ""
log_info "Searching for kernel source directory..."

# Try work-shared first
KERNEL_SOURCE_DIR=$(find "${YOCTO_BASE}/tmp/work-shared" -name "kernel-source" -type d 2>/dev/null | head -n 1)

if [ -z "${KERNEL_SOURCE_DIR}" ]; then
    # Try git directory
    KERNEL_SOURCE_DIR=$(find "${YOCTO_BASE}/tmp/work" -path "*/linux-imx/*/git" -type d 2>/dev/null | head -n 1)
    
    if [ -z "${KERNEL_SOURCE_DIR}" ]; then
        KERNEL_SOURCE_DIR=$(find "${YOCTO_BASE}/tmp/work" -path "*/linux*/*/git" -type d 2>/dev/null | head -n 1)
    fi
fi

if [ -z "${KERNEL_SOURCE_DIR}" ]; then
    log_warn "Kernel source not found"
    log_warn "Only kernel-build.tar.gz will be created"
else
    log_info "✓ Found kernel source:"
    log_info "  ${KERNEL_SOURCE_DIR}"
fi

##############################################################################
# Create TAR Files
##############################################################################

echo ""
log_info "═══════════════════════════════════════════════════════════════"
log_info "Creating TAR archives in tars/ directory..."
log_info "═══════════════════════════════════════════════════════════════"
echo ""

# Create/clean tars directory
rm -rf "${SCRIPT_DIR}/tars"
mkdir -p "${SCRIPT_DIR}/tars"

# Create kernel-build tar
log_info "Creating kernel-build.tar.gz..."
log_info "Source: ${KERNEL_BUILD_DIR}"
log_info "This may take 2-3 minutes..."
echo ""

cd "$(dirname ${KERNEL_BUILD_DIR})"
tar czf "${SCRIPT_DIR}/tars/kernel-build.tar.gz" "$(basename ${KERNEL_BUILD_DIR})"

if [ -f "${SCRIPT_DIR}/tars/kernel-build.tar.gz" ]; then
    BUILD_TAR_SIZE=$(du -h "${SCRIPT_DIR}/tars/kernel-build.tar.gz" | cut -f1)
    log_info "✓ kernel-build.tar.gz created: ${BUILD_TAR_SIZE}"
else
    log_error "✗ Failed to create kernel-build.tar.gz"
    exit 1
fi

# Create kernel-source tar (if found)
if [ -n "${KERNEL_SOURCE_DIR}" ] && [ -d "${KERNEL_SOURCE_DIR}" ]; then
    echo ""
    log_info "Creating kernel-source.tar.gz..."
    log_info "Source: ${KERNEL_SOURCE_DIR}"
    log_info "This may take 5-10 minutes (large files)..."
    echo ""
    
    cd "$(dirname ${KERNEL_SOURCE_DIR})"
    tar czf "${SCRIPT_DIR}/tars/kernel-source.tar.gz" "$(basename ${KERNEL_SOURCE_DIR})" 2>&1 | \
        while read -r line; do echo -n "."; done
    echo ""
    
    if [ -f "${SCRIPT_DIR}/tars/kernel-source.tar.gz" ]; then
        SOURCE_TAR_SIZE=$(du -h "${SCRIPT_DIR}/tars/kernel-source.tar.gz" | cut -f1)
        log_info "✓ kernel-source.tar.gz created: ${SOURCE_TAR_SIZE}"
    else
        log_error "✗ Failed to create kernel-source.tar.gz"
    fi
fi

##############################################################################
# Clean Up Extracted Directories (Keep Only TARs)
##############################################################################

echo ""
log_info "Cleaning up extracted directories (keeping only TAR files)..."

# Remove kernel-build directory if it exists
if [ -d "${SCRIPT_DIR}/kernel-build" ]; then
    log_info "Removing kernel-build/ directory..."
    rm -rf "${SCRIPT_DIR}/kernel-build"
fi

# Remove kernel-source directory if it exists
if [ -d "${SCRIPT_DIR}/kernel-source" ]; then
    log_info "Removing kernel-source/ directory..."
    rm -rf "${SCRIPT_DIR}/kernel-source"
fi

log_info "✓ Cleanup complete - only TAR files remain"

##############################################################################
# Create Version Info
##############################################################################

echo ""
log_info "Creating version info..."

cat > "${SCRIPT_DIR}/VERSION_INFO.txt" <<EOF
Kernel TAR Files Information
============================

Export Date:       $(date)
Build Host:        $(hostname)
Yocto Build Path:  ${YOCTO_BASE}

Kernel Build Source:
  ${KERNEL_BUILD_DIR}

Kernel Source:
  ${KERNEL_SOURCE_DIR:-Not found}

TAR Files Created:
  tars/kernel-build.tar.gz (${BUILD_TAR_SIZE})
  ${SOURCE_TAR_SIZE:+tars/kernel-source.tar.gz ($SOURCE_TAR_SIZE)}

Module.symvers Size:
  ${MODULE_SYMVERS_SIZE}

Usage on Target Board:
  The setup.sh script will automatically extract these TAR files
  to kernel-build/ and kernel-source/ during installation.

  Trainees just need to:
    1. git clone <repository>
    2. sudo ./setup.sh
    3. sudo ./validate.sh
EOF

log_info "✓ Version info saved to VERSION_INFO.txt"

##############################################################################
# Summary
##############################################################################

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}           TAR Files Created Successfully!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo ""

log_info "TAR Files Summary:"
echo ""

ls -lh "${SCRIPT_DIR}/tars/"

echo ""
log_info "Total tars/ directory size:"
TARS_SIZE=$(du -sh "${SCRIPT_DIR}/tars" 2>/dev/null | cut -f1)
echo "  ${TARS_SIZE}"

echo ""
log_info "Directory Structure:"
echo ""
echo "edgemind_installation/"
echo "├── tars/                    ← Ready for GitHub"
echo "│   ├── kernel-build.tar.gz"
echo "│   └── kernel-source.tar.gz"
echo "├── VERSION_INFO.txt"
echo "├── setup.sh"
echo "├── copy-kernel-files.sh"
echo "├── validate.sh"
echo "└── ..."
echo ""
echo "Note: kernel-build/ and kernel-source/ directories"
echo "      are NOT created - only TAR files for upload!"

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Next Steps:${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo "1. Verify TAR files:"
echo "   ls -lh ${SCRIPT_DIR}/tars/"
echo ""
echo "2. Test extraction (optional):"
echo "   mkdir /tmp/test"
echo "   tar xzf tars/kernel-build.tar.gz -C /tmp/test"
echo "   ls /tmp/test/build/Module.symvers"
echo ""
echo "3. Add to Git:"
echo "   git add tars/"
echo "   git add VERSION_INFO.txt"
echo "   git commit -m 'Add kernel TAR files'"
echo "   git push"
echo ""
echo "4. On target board, setup.sh will auto-extract these TARs"
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Show what to add to .gitignore
echo -e "${YELLOW}Recommended .gitignore:${NC}"
echo ""
cat <<'GITIGNORE'
# Exclude extracted directories (not needed in Git)
kernel-build/
kernel-source/

# Keep TAR files
!tars/
!tars/*.tar.gz

# General
*.swp
*~
.DS_Store
GITIGNORE

echo ""
log_info "TAR files ready for GitHub upload!"
log_info "Repository size will be: ~${TARS_SIZE} (compressed)"