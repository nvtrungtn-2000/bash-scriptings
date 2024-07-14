#!/bin/bash

# Bước 1: Tạo script cập nhật thông tin hệ thống
cat << 'EOF' > /usr/local/bin/update_issue.sh
#!/bin/bash

# Lấy thông tin từ lệnh hostnamectl
OS=$(hostnamectl | grep "Operating System" | awk -F: '{print $2}' | xargs)
Kernel=$(hostnamectl | grep "Kernel" | awk -F: '{print $2}' | xargs)
Hostname=$(hostnamectl | grep "Static hostname" | awk -F: '{print $2}' | xargs)
OS_Version=$(hostnamectl | grep "Operating System" | awk -F' ' '{print $6,$7,$8}' | xargs)

# Lấy địa chỉ IP
IP=$(ip addr show | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | cut -d/ -f1 | xargs)

# Tạo thông điệp để ghi vào /etc/issue
ISSUE_MESSAGE="
**************************************************
*   Welcome to the Red Hat Enterprise Linux $OS_Version!   *
*   Unauthorized access is prohibited.           *
*   Contact IT support if you need assistance.   *
**************************************************

Operating System: $OS
Kernel: $Kernel
Static hostname: $Hostname
IP Address: $IP
"

# Ghi thông điệp vào /etc/issue
echo "$ISSUE_MESSAGE" | sudo tee /etc/issue > /dev/null

# Hiển thị thông điệp đã ghi để xác nhận
echo "The following information has been written to /etc/issue:"
echo "$ISSUE_MESSAGE"
EOF

# Đảm bảo script có thể chạy được
chmod +x /usr/local/bin/update_issue.sh

# Bước 2: Thêm cron job để chạy script mỗi khi hệ thống khởi động lại
(crontab -l ; echo "@reboot /usr/local/bin/update_issue.sh") | crontab -

echo "Setup complete. The update_issue script will run at startup."
