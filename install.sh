#!/bin/bash
# RFM Insights - Universal Installation Script
# This script serves as the main entry point for installing RFM Insights on any platform

set -e

# Set colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Set project root directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$PROJECT_ROOT/install.log"
MODULES_DIR="$PROJECT_ROOT/scripts/modules"

# Create log file
touch "$LOG_FILE"
echo "[$(date +'%Y-%m-%d %H:%M:%S')] Installation started" > "$LOG_FILE"

# Logging functions
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [SUCCESS] $1" >> "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [WARNING] $1" >> "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] $1" >> "$LOG_FILE"
    exit 1
}

# Function to check command status
check_status() {
    if [ $? -eq 0 ]; then
        success "$1"
        return 0
    else
        error "$1 failed"
        return 1
    fi
}

# Banner
echo ""
echo -e "${CYAN}===================================================${NC}"
echo -e "${CYAN}          RFM INSIGHTS - INSTALLATION           ${NC}"
echo -e "${CYAN}===================================================${NC}"
echo ""

log "Starting RFM Insights installation"
log "Project directory: $PROJECT_ROOT"

# Detect operating system
detect_os() {
    log "Detecting operating system..."
    
    if [ "$(uname)" == "Darwin" ]; then
        OS="macos"
        success "macOS detected"
    elif [ "$(uname)" == "Linux" ]; then
        OS="linux"
        success "Linux detected"
    elif [ "$(uname -s | cut -c 1-5)" == "MINGW" ] || [ "$(uname -s | cut -c 1-4)" == "MSYS" ] || [ "$(uname -s | cut -c 1-5)" == "CYGWI" ]; then
        OS="windows"
        success "Windows detected (Git Bash/MinGW/Cygwin)"
    else
        warning "Unknown operating system. Assuming Linux compatibility."
        OS="linux"
    fi
}

# Run platform-specific installer
run_platform_installer() {
    log "Running platform-specific installer..."
    
    case "$OS" in
        "macos")
            if [ -f "$PROJECT_ROOT/scripts/install_macos.sh" ]; then
                log "Running macOS installer..."
                bash "$PROJECT_ROOT/scripts/install_macos.sh"
                check_status "macOS installation"
            else
                error "macOS installer script not found"
            fi
            ;;
        "linux")
            if [ -f "$PROJECT_ROOT/scripts/install_linux.sh" ]; then
                log "Running Linux installer..."
                bash "$PROJECT_ROOT/scripts/install_linux.sh"
                check_status "Linux installation"
            else
                error "Linux installer script not found"
            fi
            ;;
        "windows")
            if [ -f "$PROJECT_ROOT/install.ps1" ]; then
                log "For Windows, please run the PowerShell script: install.ps1"
                log "Command: powershell -ExecutionPolicy Bypass -File .\install.ps1"
                exit 0
            else
                error "Windows installer script not found"
            fi
            ;;
    esac
}

# Main execution
detect_os
run_platform_installer

success "Installation completed successfully!"
log "For more details, check the log file at: $LOG_FILE"

echo ""
echo -e "${CYAN}===================================================${NC}"
echo -e "${CYAN}          INSTALLATION COMPLETE                ${NC}"
echo -e "${CYAN}===================================================${NC}"
echo ""

exit 0