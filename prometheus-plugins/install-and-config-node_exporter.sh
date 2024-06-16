#!/bin/bash

URL="https://github.com/prometheus/node_exporter/releases/download/v1.8.1/node_exporter-1.8.1.linux-amd64.tar.gz"
DOWNLOAD_DIR="/tmp"
FILE_NAME=$(basename "$URL")
EXTRACT_DIR="/opt/node_exporter"
BIN_DIR="/usr/local/bin"
USER="node_exporter"
GROUP="node_exporter"
SERVICE_FILE="/etc/systemd/system/node_exporter.service"
PORT=9100

check_url() {
    local url=$1
    if ! curl -Is "$url" | head -n 1 | grep -q "200\|301\|302"; then
        printf "Error: URL does not exist or is not accessible.\n" >&2
        return 1
    fi
    return 0
}

download_file() {
    local url=$1
    local download_dir=$2
    local file_name=$3
    
    mkdir -p "$download_dir" || {
        printf "Error: Failed to create directory %s.\n" "$download_dir" >&2
        return 1
    }
    
    curl -L -o "${download_dir}/${file_name}" "$url" || {
        printf "Error: Failed to download file from %s.\n" "$url" >&2
        return 1
    }
    
    printf "Downloaded %s to %s.\n" "$file_name" "$download_dir"
    return 0
}

extract_file() {
    local file_path=$1
    local extract_dir=$2
    
    mkdir -p "$extract_dir" || {
        printf "Error: Failed to create directory %s.\n" "$extract_dir" >&2
        return 1
    }
    
    tar -xzf "$file_path" -C "$extract_dir" --strip-components=1 || {
        printf "Error: Failed to extract file %s.\n" "$file_path" >&2
        return 1
    }
    
    printf "Extracted %s to %s.\n" "$file_path" "$extract_dir"
    return 0
}

configure_node_exporter() {
    local extract_dir=$1
    local bin_dir=$2
    
    cp "${extract_dir}/node_exporter" "${bin_dir}/node_exporter" || {
        printf "Error: Failed to copy node_exporter binary to %s.\n" "$bin_dir" >&2
        return 1
    }
    
    printf "Node Exporter binary has been configured in %s.\n" "$bin_dir"
    return 0
}

create_user_and_group() {
    if ! id -u "$USER" >/dev/null 2>&1; then
        useradd --no-create-home --shell /bin/false "$USER" || {
            printf "Error: Failed to create user %s.\n" "$USER" >&2
            return 1
        }
    fi
    
    if ! getent group "$GROUP" >/dev/null 2>&1; then
        groupadd "$GROUP" || {
            printf "Error: Failed to create group %s.\n" "$GROUP" >&2
            return 1
        }
    fi
    
    printf "Created user and group %s.\n" "$USER"
    return 0
}

create_systemd_service() {
    local service_file=$1
    local user=$2
    local port=$3

    cat <<EOF > "$service_file"
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=$user
Group=$user
Type=simple
ExecStart=/usr/local/bin/node_exporter --web.listen-address=0.0.0.0:$port
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload || {
        printf "Error: Failed to reload systemd daemon.\n" >&2
        return 1
    }
    
    systemctl enable node_exporter || {
        printf "Error: Failed to enable Node Exporter service.\n" >&2
        return 1
    }
    
    printf "Created and enabled systemd service for Node Exporter.\n"
    return 0
}

open_firewall_port() {
    local port=$1
    
    firewall-cmd --zone=public --add-port=${port}/tcp --permanent || {
        printf "Error: Failed to open port %s.\n" "$port" >&2
        return 1
    }
    
    firewall-cmd --reload || {
        printf "Error: Failed to reload firewall rules.\n" >&2
        return 1
    }
    
    printf "Opened firewall port %s.\n" "$port"
    return 0
}

main() {
    check_url "$URL" || return 1
    download_file "$URL" "$DOWNLOAD_DIR" "$FILE_NAME" || return 1
    extract_file "${DOWNLOAD_DIR}/${FILE_NAME}" "$EXTRACT_DIR" || return 1
    configure_node_exporter "$EXTRACT_DIR" "$BIN_DIR" || return 1
    create_user_and_group || return 1
    create_systemd_service "$SERVICE_FILE" "$USER" "$PORT" || return 1
    open_firewall_port "$PORT" || return 1
    
    systemctl start node_exporter || {
        printf "Error: Failed to start Node Exporter service.\n" >&2
        return 1
    }
    
    printf "Node Exporter installation and configuration complete.\n"
    return 0
}

main "$@"
