#!/bin/bash

services=("mariadb" "ndo2db" "ramdisk" "httpd")

restart_and_check() {
    local service=$1
    echo "Restarting $service..."
    systemctl restart $service
    if [[ $? -ne 0 ]]; then 
        echo "Failed to restart $service"
        exit 1 
    fi

    echo "Checking status of $service..."
    systemctl is-active --quiet $service
    if [[ $? -ne 0 ]]; then 
        echo "$service is not running"
        exit 1  # Thoát script với mã lỗi 1
    fi

    echo "$service restarted and is running successfully"
}

for service in "${services[@]}"; do
    restart_and_check $service
done

echo "All services restarted and running successfully"
