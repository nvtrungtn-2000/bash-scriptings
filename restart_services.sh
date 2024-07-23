#!/bin/bash

# Kiểm tra quyền root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

services=("mariadb" "ndo2db" "ramdisk" "httpd")

restart_and_check() {
    local service=$1
    echo "Restarting $service..."
    if ! systemctl restart $service; then 
        echo "Failed to restart $service" >&2
        return 1 
    fi
    echo "Checking status of $service..."
    if ! systemctl is-active --quiet $service; then 
        echo "$service is not running" >&2
        return 1
    fi
    echo "$service restarted and is running successfully"
    return 0
}

failed_services=()

for service in "${services[@]}"; do
    if ! restart_and_check $service; then
        failed_services+=("$service")
    fi
done

if [ ${#failed_services[@]} -eq 0 ]; then
    echo "All services restarted and running successfully"
else
    echo "The following services failed to restart or are not running:" >&2
    printf '%s\n' "${failed_services[@]}" >&2
    exit 1
fi
