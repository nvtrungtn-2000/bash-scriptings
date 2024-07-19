#!/usr/bin/bash

# Bước 1: Tạo script cập nhật thông tin hệ thống
cat << 'EOF' > /usr/local/bin/update_issue.sh
#!/bin/bash

# Function to fetch system information
fetch_system_info() {
    local info os kernel hostname ip os_version arch uptime
    info=$(hostnamectl)

    os=$(echo "$info" | grep -i "Operating System" | awk -F: '{print $2}' | xargs)
    kernel=$(echo "$info" | grep -i "Kernel" | awk -F: '{print $2}' | xargs)
    hostname=$(echo "$info" | grep -i "Static hostname" | awk -F: '{print $2}' | xargs)
    ip=$(hostname -I | xargs)
    arch=$(uname -m)
    uptime=$(uptime -p)
    os_version=$(echo "$os" | awk '{print $NF}')

    printf "%s\n%s\n%s\n%s\n%s\n%s\n%s\n" "$os" "$kernel" "$hostname" "$ip" "$os_version" "$arch" "$uptime"
}

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
******************************************************
*        Welcome to $os $os_version!                 *
******************************************************
*  Operating System:   $os                           *
*  Kernel:             $kernel                       *
*  Static hostname:    $hostname                     *
*  IP Address:         $ip                           *
*  Architecture:       $arch                         *
*  Uptime:             $uptime                       *
******************************************************
*  Contact: Nguyễn Văn Trung - trungnv6@vnpay.vn     *
*  Position: System Administrator                    *
******************************************************
*  System Status                                      *
*  -------------                                      *
*  CPU Usage:                                         *
*  Memory Usage:                                      *
*  Disk Usage:                                        *
******************************************************
EOM
)

# Write message to /etc/issue
if echo "$issue_message" | sudo tee /etc/issue > /dev/null; then
    # Log the written message for confirmation
    {
        printf "The following information has been written to /etc/issue:\n"
        printf "%s\n" "$issue_message"
    } >> /var/log/update_issue.log
else
    echo "Failed to write to /etc/issue" >> /var/log/update_issue.log
fi
EOF

# Đảm bảo script có thể chạy được
chmod +x /usr/local/bin/update_issue.sh

# Bước 2: Tạo service trong systemd
cat << 'EOF' > /etc/systemd/system/update_issue.service
[Unit]
Description=Update /etc/issue with system information
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/update_issue.sh
User=nobody
Group=nogroup

[Install]
WantedBy=multi-user.target
EOF

# Tải lại systemd để nhận diện service mới
systemctl daemon-reload

# Kích hoạt service để chạy mỗi khi hệ thống khởi động
systemctl enable update_issue.service

# Khởi động service để kiểm tra
systemctl start update_issue.service

echo "Setup complete. The update_issue script will run at startup."
