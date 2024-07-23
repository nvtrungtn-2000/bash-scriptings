#!/bin/bash

# Function to fetch system information
fetch_system_info() {
    local info os kernel hostname ip os_version arch uptime
    info=$(hostnamectl)
    os=$(echo "$info" | grep -i "Operating System" | awk -F: '{print $2}' | xargs)
    kernel=$(echo "$info" | grep -i "Kernel" | awk -F: '{print $2}' | xargs)
    hostname=$(echo "$info" | grep -i "Static hostname" | awk -F: '{print $2}' | xargs)
    ip=$(hostname -I | awk '{print $1}')  # Chỉ lấy địa chỉ IP đầu tiên
    os_version=$(echo "$info" | grep -i "Operating System" | awk -F: '{print $2}' | xargs)
    arch=$(uname -m)
    uptime=$(uptime -p)
    
    printf "%s\n%s\n%s\n%s\n%s\n%s\n%s\n" "$os" "$kernel" "$hostname" "$ip" "$os_version" "$arch" "$uptime"
}

# Check if script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Fetch and sanitize system information
system_info=$(fetch_system_info)
os=$(echo "$system_info" | sed -n '1p')
kernel=$(echo "$system_info" | sed -n '2p')
hostname=$(echo "$system_info" | sed -n '3p')
ip=$(echo "$system_info" | sed -n '4p')
os_version=$(echo "$system_info" | sed -n '5p')
arch=$(echo "$system_info" | sed -n '6p')
uptime=$(echo "$system_info" | sed -n '7p')

# Formatted message for /etc/issue
issue_message=$(cat << EOM
Welcome to $os!
Operating System: $os ($os_version)
Kernel          : $kernel
Hostname        : $hostname
IP Address      : $ip
Architecture    : $arch
Uptime          : $uptime
Feedbacker - nvtrung16122000@gmail.com
EOM
)

# Write message to /etc/issue
if echo "$issue_message" > /etc/issue; then
    # Log the written message for confirmation
    {
        printf "The following information has been written to /etc/issue:\n"
        printf "%s\n" "$issue_message"
    } >> /var/log/update_issue.log
else
    echo "Failed to write to /etc/issue" >> /var/log/update_issue.log
fi
