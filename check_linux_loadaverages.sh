#!/bin/bash

# Nagios return codes
OK=0
WARNING=1
CRITICAL=2
UNKNOWN=3

# Function to print usage
usage() {
    echo "Usage: $0 [-w warning] [-c critical]"
    echo "  -w: Warning thresholds in percentage for load1, load5, load15 (example: 90,80,70)"
    echo "  -c: Critical thresholds in percentage for load1, load5, load15 (example: 100,95,85)"
    echo "Example: $0 -w 90,80,70 -c 100,95,85"
    exit $UNKNOWN
}

# Parse command line options
while getopts ":w:c:" opt; do
    case $opt in
        w)
            IFS=',' read -r WARNING_THRESHOLD_LOAD1 WARNING_THRESHOLD_LOAD5 WARNING_THRESHOLD_LOAD15 <<< "$OPTARG"
            ;;
        c)
            IFS=',' read -r CRITICAL_THRESHOLD_LOAD1 CRITICAL_THRESHOLD_LOAD5 CRITICAL_THRESHOLD_LOAD15 <<< "$OPTARG"
            ;;
        \?) usage ;;
    esac
done

# Validate thresholds
validate_thresholds() {
    local threshold="$1"
    if ! [[ "$threshold" =~ ^[0-9]+$ ]] || (( threshold < 0 || threshold > 100 )); then
        echo "Invalid threshold value: $threshold. Please provide integer values between 0 and 100."
        usage
    fi
}

validate_thresholds "$WARNING_THRESHOLD_LOAD1"
validate_thresholds "$WARNING_THRESHOLD_LOAD5"
validate_thresholds "$WARNING_THRESHOLD_LOAD15"
validate_thresholds "$CRITICAL_THRESHOLD_LOAD1"
validate_thresholds "$CRITICAL_THRESHOLD_LOAD5"
validate_thresholds "$CRITICAL_THRESHOLD_LOAD15"

# Get number of CPUs
CPU_COUNT=$(nproc)
if [[ -z "$CPU_COUNT" || "$CPU_COUNT" -eq 0 ]]; then
    echo "UNKNOWN - Unable to determine number of CPUs"
    exit $UNKNOWN
fi

# Get load averages and process info
if ! read -r load1 load5 load15 running_processes total_processes < <(awk '{print $1, $2, $3, $4}' /proc/loadavg); then
    echo "UNKNOWN - Unable to read /proc/loadavg"
    exit $UNKNOWN
fi

# Extract running processes and total processes
IFS='/' read -r running_processes total_processes <<< "$running_processes"

# Calculate load percentages
load1_percent=$(awk -v load1_val="$load1" -v cpus="$CPU_COUNT" 'BEGIN {printf "%.2f", (load1_val/cpus)*100}')
load5_percent=$(awk -v load5_val="$load5" -v cpus="$CPU_COUNT" 'BEGIN {printf "%.2f", (load5_val/cpus)*100}')
load15_percent=$(awk -v load15_val="$load15" -v cpus="$CPU_COUNT" 'BEGIN {printf "%.2f", (load15_val/cpus)*100}')

# Prepare performance data
perfdata="load1=$load1;$WARNING_THRESHOLD_LOAD1;$CRITICAL_THRESHOLD_LOAD1;0;100 load5=$load5;$WARNING_THRESHOLD_LOAD5;$CRITICAL_THRESHOLD_LOAD5;0;100 load15=$load15;$WARNING_THRESHOLD_LOAD15;$CRITICAL_THRESHOLD_LOAD15;0;100 running_processes=$running_processes total_processes=$total_processes"

# Check thresholds and set status text
if (( $(echo "$load1_percent >= $CRITICAL_THRESHOLD_LOAD1" | bc -l) )) || (( $(echo "$load5_percent >= $CRITICAL_THRESHOLD_LOAD5" | bc -l) )) || (( $(echo "$load15_percent >= $CRITICAL_THRESHOLD_LOAD15" | bc -l) )); then
    STATUS_TEXT="CRITICAL - Load average: $load1, $load5, $load15 [$running_processes/$total_processes]"
    STATUS=$CRITICAL
elif (( $(echo "$load1_percent >= $WARNING_THRESHOLD_LOAD1" | bc -l) )) || (( $(echo "$load5_percent >= $WARNING_THRESHOLD_LOAD5" | bc -l) )) || (( $(echo "$load15_percent >= $WARNING_THRESHOLD_LOAD15" | bc -l) )); then
    STATUS_TEXT="WARNING - Load average: $load1, $load5, $load15 [$running_processes/$total_processes]"
    STATUS=$WARNING
else
    STATUS_TEXT="OK - Load average: $load1, $load5, $load15 [$running_processes/$total_processes]"
    STATUS=$OK
fi

# Output status and performance data
echo "$STATUS_TEXT | $perfdata"
exit $STATUS
