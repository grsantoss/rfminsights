#!/bin/bash
# RFM Insights - Environment Check Module
# This module verifies system requirements for RFM Insights installation

set -e

# Logging functions are inherited from the parent script

# Banner
echo ""
echo "==================================================="
echo "          ENVIRONMENT CHECK                      "
echo "==================================================="
echo ""

# Start module log
log "Starting environment check"

# Check for root/sudo privileges
log "Checking for root privileges..."
if [ "$(id -u)" -ne 0 ]; then
    warning "This script is not running with root privileges"
    warning "Some operations may require sudo access"
    
    # Ask if user wants to continue
    read -p "Continue without root privileges? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        error "Installation aborted. Please run with sudo"
    fi
else
    success "Running with root privileges"
fi

# Check for internet connectivity
log "Checking internet connectivity..."
if ping -c 1 google.com &> /dev/null; then
    success "Internet connectivity confirmed"
else
    warning "No internet connectivity detected"
    read -p "Continue without internet connectivity? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        error "Installation aborted. Please check your internet connection"
    fi
fi

# Check disk space
log "Checking available disk space..."
DISK_SPACE=$(df -h . | awk 'NR==2 {print $4}')
DISK_SPACE_BYTES=$(df . | awk 'NR==2 {print $4}')

if [ $DISK_SPACE_BYTES -lt 1073741824 ]; then  # 1GB in bytes
    warning "Low disk space: $DISK_SPACE available"
    warning "RFM Insights requires at least 1GB of free space"
    read -p "Continue with limited disk space? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        error "Installation aborted. Please free up some disk space"
    fi
else
    success "Sufficient disk space available: $DISK_SPACE"
fi

# Check CPU and memory
log "Checking system resources..."

# Get CPU cores
if [ "$(uname)" == "Darwin" ]; then
    CPU_CORES=$(sysctl -n hw.ncpu)
else
    CPU_CORES=$(nproc)
fi

# Get memory
if [ "$(uname)" == "Darwin" ]; then
    TOTAL_MEM=$(sysctl -n hw.memsize)
    TOTAL_MEM_GB=$((TOTAL_MEM / 1024 / 1024 / 1024))
else
    TOTAL_MEM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    TOTAL_MEM_GB=$((TOTAL_MEM_KB / 1024 / 1024))
fi

log "CPU Cores: $CPU_CORES"
log "Memory: ${TOTAL_MEM_GB}GB"

if [ $CPU_CORES -lt 2 ]; then
    warning "Low CPU resources: $CPU_CORES cores detected"
    warning "RFM Insights performs better with at least 2 CPU cores"
fi

if [ $TOTAL_MEM_GB -lt 2 ]; then
    warning "Low memory: ${TOTAL_MEM_GB}GB detected"
    warning "RFM Insights performs better with at least 2GB of RAM"
    read -p "Continue with limited memory? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        error "Installation aborted due to insufficient memory"
    fi
fi

success "Environment check completed"
exit 0