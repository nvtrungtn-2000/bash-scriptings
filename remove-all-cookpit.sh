#!/bin/bash

echo "Stopping and disabling Cockpit services..."
systemctl stop cockpit.socket
systemctl disable cockpit.socket
systemctl stop cockpit
systemctl disable cockpit

echo "Removing Cockpit packages..."
dnf remove cockpit cockpit-* -y

echo "Finding and removing Cockpit related files and directories..."

find / -name '*cockpit*' -print | while read file; do
    echo "Removing $file"
    rm -rf "$file"
done

echo "Checking the status of Cockpit services..."
systemctl status cockpit.socket
systemctl status cockpit

echo "Cockpit has been removed from the system."

exit 0
