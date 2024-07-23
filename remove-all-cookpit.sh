#!/bin/bash

# Kiểm tra quyền root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" >&2
   exit 1
fi

execute_command() {
    if ! "$@"; then
        echo "Error executing: $*" >&2
        exit 1
    fi
}

echo "Stopping and disabling Cockpit services..."
execute_command systemctl stop cockpit.socket
execute_command systemctl disable cockpit.socket
execute_command systemctl stop cockpit
execute_command systemctl disable cockpit

echo "Removing Cockpit packages..."
execute_command dnf remove cockpit cockpit-* -y

echo "Finding and removing Cockpit related files and directories..."
while IFS= read -r -d '' file; do
    echo "Removing $file"
    execute_command rm -rf "$file"
done < <(find / -name '*cockpit*' -print0 2>/dev/null)

echo "Checking the status of Cockpit services..."
systemctl status cockpit.socket || true
systemctl status cockpit || true

echo "Cockpit has been removed from the system."
exit 0
