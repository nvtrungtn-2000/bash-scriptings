#!/bin/bash

URL="https://github.com/prometheus/prometheus/releases/download/v2.45.5/prometheus-2.45.5.linux-amd64.tar.gz"
DOWNLOAD_DIR="/tmp"
FILE_NAME=$(basename "$URL")
EXTRACT_DIR="/opt/prometheus"
BIN_DIR="/usr/local/bin"
USER="prometheus"
GROUP="prometheus"
SERVICE_FILE="/etc/systemd/system/prometheus.service"
DATA_DIR="/var/lib/prometheus"
CONFIG_DIR="/etc/prometheus"
PORT=9090

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

configure_prometheus() {
    local extract_dir=$1
    local bin_dir=$2
    
    cp "${extract_dir}/prometheus" "${bin_dir}/prometheus" || {
        printf "Error: Failed to copy prometheus binary to %s.\n" "$bin_dir" >&2
        return 1
    }
    
    cp "${extract_dir}/promtool" "${bin_dir}/promtool" || {
        printf "Error: Failed to copy promtool binary to %s.\n" "$bin_dir" >&2
        return 1
    }
    
    printf "Prometheus and promtool binaries have been configured in %s.\n" "$bin_dir"
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

setup_directories() {
    local data_dir=$1
    local config_dir=$2
    local user=$3
    local group=$4
    
    mkdir -p "$data_dir" "$config_dir" || {
        printf "Error: Failed to create directories %s and %s.\n" "$data_dir" "$config_dir" >&2
        return 1
    }
    
    chown -R "$user":"$group" "$data_dir" "$config_dir" || {
        printf "Error: Failed to set ownership of %s and %s.\n" "$data_dir" "$config_dir" >&2
        return 1
    }
    
    printf "Setup directories and permissions for %s and %s.\n" "$data_dir" "$config_dir"
    return 0
}

create_systemd_service() {
    local service_file=$1
    local user=$2
    local data_dir=$3
    local config_dir=$4
    local port=$5

    cat <<EOF > "$service_file"
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=$user
Group=$user
Type=simple
ExecStart=/usr/local/bin/prometheus \\
    --config.file $config_dir/prometheus.yml \\
    --storage.tsdb.path $data_dir \\
    --web.console.templates=$config_dir/consoles \\
    --web.console.libraries=$config_dir/console_libraries \\
    --web.listen-address=0.0.0.0:$port
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload || {
        printf "Error: Failed to reload systemd daemon.\n" >&2
        return 1
    }
    
    systemctl enable prometheus || {
        printf "Error: Failed to enable Prometheus service.\n" >&2
        return 1
    }
    
    printf "Created and enabled systemd service for Prometheus.\n"
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
    configure_prometheus "$EXTRACT_DIR" "$BIN_DIR" || return 1
    create_user_and_group || return 1
    setup_directories "$DATA_DIR" "$CONFIG_DIR" "$USER" "$GROUP" || return 1
    create_systemd_service "$SERVICE_FILE" "$USER" "$DATA_DIR" "$CONFIG_DIR" "$PORT" || return 1
    open_firewall_port "$PORT" || return 1
    
    systemctl start prometheus || {
        printf "Error: Failed to start Prometheus service.\n" >&2
        return 1
    }
    
    printf "Prometheus installation and configuration complete.\n"
    return 0
}

main "$@"
