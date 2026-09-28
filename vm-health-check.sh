#!/bin/bash

################################################################################
# VM Health Monitor Script
# 
# This script analyzes the health of Ubuntu VMs based on:
# - CPU utilization
# - Memory utilization
# - Disk space utilization
#
# Health Status:
# - HEALTHY: All metrics are < 60% utilized
# - NOT HEALTHY: Any metric is >= 60% utilized
#
# Usage: ./vm-health-check.sh [explain]
#        ./vm-health-check.sh explain     (for detailed explanation)
################################################################################

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Thresholds
THRESHOLD=60

################################################################################
# Function to get CPU utilization percentage
################################################################################
get_cpu_utilization() {
    # Get average CPU utilization over the last 1 minute
    # top -bn1 shows one iteration, we get the CPU line and extract idle percentage
    local idle_percent=$(top -bn1 | grep "Cpu(s)" | awk '{print $8}' | cut -d'%' -f1)
    
    # Convert idle to utilization (100 - idle)
    local cpu_utilization=$(echo "100 - $idle_percent" | bc -l)
    
    # Round to nearest integer
    printf "%.0f" "$cpu_utilization"
}

################################################################################
# Function to get Memory utilization percentage
################################################################################
get_memory_utilization() {
    # Get memory info from /proc/meminfo
    local memtotal=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local memavailable=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    
    # Calculate memory used
    local memused=$((memtotal - memavailable))
    
    # Calculate percentage
    local memory_percent=$(echo "scale=2; ($memused / $memtotal) * 100" | bc -l)
    
    # Round to nearest integer
    printf "%.0f" "$memory_percent"
}

################################################################################
# Function to get Disk utilization percentage
################################################################################
get_disk_utilization() {
    # Get disk utilization for root filesystem (/)
    # df -h shows human-readable format, we extract the root partition
    local disk_percent=$(df -h / | tail -1 | awk '{print $5}' | cut -d'%' -f1)
    
    printf "%d" "$disk_percent"
}

################################################################################
# Function to determine health status
################################################################################
determine_health_status() {
    local cpu=$1
    local memory=$2
    local disk=$3
    
    if [[ $cpu -ge $THRESHOLD ]] || [[ $memory -ge $THRESHOLD ]] || [[ $disk -ge $THRESHOLD ]]; then
        echo "NOT HEALTHY"
        return 1
    else
        echo "HEALTHY"
        return 0
    fi
}

################################################################################
# Function to print health status
################################################################################
print_health_status() {
    local status=$1
    local cpu=$2
    local memory=$3
    local disk=$4
    
    if [[ "$status" == "HEALTHY" ]]; then
        echo -e "${GREEN}[✓] VM Health Status: $status${NC}"
    else
        echo -e "${RED}[✗] VM Health Status: $status${NC}"
    fi
    
    # Print metrics
    echo -e "\n${BLUE}Resource Utilization:${NC}"
    printf "  CPU:     %3d%%\n" "$cpu"
    printf "  Memory:  %3d%%\n" "$memory"
    printf "  Disk:    %3d%%\n" "$disk"
}

################################################################################
# Function to print detailed explanation
################################################################################
print_explanation() {
    local status=$1
    local cpu=$2
    local memory=$3
    local disk=$4
    
    echo -e "\n${BLUE}=== Health Status Explanation ===${NC}"
    echo "Threshold: Metrics < 60% are considered HEALTHY"
    echo ""
    
    # CPU Analysis
    echo -e "${BLUE}CPU Utilization: ${cpu}%${NC}"
    if [[ $cpu -ge $THRESHOLD ]]; then
        echo -e "  ${RED}[!] WARNING: CPU is heavily utilized (>= 60%)${NC}"
        echo "      - System may experience performance degradation"
        echo "      - Consider reducing workload or optimizing processes"
    else
        echo -e "  ${GREEN}[✓] CPU usage is within acceptable range (< 60%)${NC}"
    fi
    
    # Memory Analysis
    echo ""
    echo -e "${BLUE}Memory Utilization: ${memory}%${NC}"
    if [[ $memory -ge $THRESHOLD ]]; then
        echo -e "  ${RED}[!] WARNING: Memory is heavily utilized (>= 60%)${NC}"
        echo "      - System may experience slowdowns due to swap usage"
        echo "      - Consider increasing RAM or closing unnecessary applications"
    else
        echo -e "  ${GREEN}[✓] Memory usage is within acceptable range (< 60%)${NC}"
    fi
    
    # Disk Analysis
    echo ""
    echo -e "${BLUE}Disk Utilization: ${disk}%${NC}"
    if [[ $disk -ge $THRESHOLD ]]; then
        echo -e "  ${RED}[!] WARNING: Disk is heavily utilized (>= 60%)${NC}"
        echo "      - Running out of disk space can cause system failures"
        echo "      - Consider removing old logs, temporary files, or expanding storage"
    else
        echo -e "  ${GREEN}[✓] Disk usage is within acceptable range (< 60%)${NC}"
    fi
    
    # Overall Health
    echo ""
    echo -e "${BLUE}Overall Health Status: ${status}${NC}"
    if [[ "$status" == "HEALTHY" ]]; then
        echo -e "  ${GREEN}[✓] The VM is operating normally with good resource availability${NC}"
    else
        echo -e "  ${RED}[✗] The VM requires attention. One or more resources are heavily utilized${NC}"
    fi
}

################################################################################
# Main Script Execution
################################################################################
main() {
    echo -e "${YELLOW}=== VM Health Monitor ===${NC}\n"
    
    # Check if running on Ubuntu
    if ! grep -qi ubuntu /etc/os-release 2>/dev/null; then
        echo -e "${YELLOW}[!] Warning: This script is optimized for Ubuntu systems${NC}"
    fi
    
    # Collect metrics
    echo "Collecting system metrics..."
    cpu=$(get_cpu_utilization)
    memory=$(get_memory_utilization)
    disk=$(get_disk_utilization)
    
    # Determine health status
    status=$(determine_health_status "$cpu" "$memory" "$disk")
    
    # Print results
    print_health_status "$status" "$cpu" "$memory" "$disk"
    
    # Check if "explain" argument was passed
    if [[ $# -gt 0 && "$1" == "explain" ]]; then
        print_explanation "$status" "$cpu" "$memory" "$disk"
    fi
    
    echo ""
}

# Run main function
main "$@"
