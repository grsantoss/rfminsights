#!/bin/bash
# RFM Insights - Linux Installation Script
# This script handles the complete installation process for Linux environments

set -e

# Set colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Set project root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
MODULES_DIR="$SCRIPT_DIR/modules"
LOG_FILE="$PROJECT_ROOT/install_linux.log"

# Create log file
touch "$LOG_FILE"
echo "[$(date +'%Y-%m-%d %H:%M:%S')] Linux installation started" > "$LOG_FILE"

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

# Function to check if a module exists
check_module() {
    local module_name=$1
    local module_path="$MODULES_DIR/$module_name.sh"
    
    if [ -f "$module_path" ]; then
        return 0
    else
        return 1
    fi
}

# Function to execute a module
execute_module() {
    local module_name=$1
    local module_path="$MODULES_DIR/$module_name.sh"
    
    if [ -f "$module_path" ]; then
        log "Executing module: $module_name"
        chmod +x "$module_path"
        
        # Export variables for the module
        export PROJECT_ROOT
        export LOG_FILE
        
        # Source the module to inherit functions
        source "$module_path"
        
        if [ $? -eq 0 ]; then
            success "Module $module_name completed successfully"
            return 0
        else
            error "Module $module_name failed with exit code $?"
            return 1
        fi
    else
        error "Module $module_name not found"
        return 1
    fi
}

# Banner
echo ""
echo -e "${CYAN}===================================================${NC}"
echo -e "${CYAN}          RFM INSIGHTS - LINUX INSTALLATION     ${NC}"
echo -e "${CYAN}===================================================${NC}"
echo ""

log "Starting RFM Insights installation on Linux"
log "Project directory: $PROJECT_ROOT"

# Check if modules directory exists
if [ ! -d "$MODULES_DIR" ]; then
    log "Creating modules directory..."
    mkdir -p "$MODULES_DIR"
    success "Modules directory created"
fi

# List of modules to execute in order
MODULES=(
    "01-environment-check"
    "02-dependencies"
    "03-docker-setup"
    "04-database-setup"
    "05-ssl-setup"
    "06-final-setup"
)

# Execute each module in sequence
for module in "${MODULES[@]}"; do
    log "Starting module: $module"
    
    if check_module "$module"; then
        execute_module "$module"
        
        if [ $? -ne 0 ]; then
            error "Module $module failed. Installation cannot continue."
            exit 1
        fi
    else
        warning "Module $module not found. Skipping..."
        read -p "Continue without this module? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "Installation aborted by user"
            exit 0
        fi
    fi
done

# Installation complete
success "RFM Insights installation completed successfully"
log "You can now access the application at:"
log "  - Frontend: https://localhost"
log "  - API: https://localhost:8000"
log "For more details, check the log file at: $LOG_FILE"

echo ""
echo -e "${CYAN}===================================================${NC}"
echo -e "${CYAN}          INSTALLATION COMPLETE                ${NC}"
echo -e "${CYAN}===================================================${NC}"
echo ""

exit 0