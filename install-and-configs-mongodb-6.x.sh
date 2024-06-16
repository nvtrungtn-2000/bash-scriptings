#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset

MONGO_PORT=27017
MONGO_CONF_FILE="/etc/mongod.conf"
MONGO_LOG_DIR="/var/log/mongodb"
MONGO_DATA_DIR="/var/lib/mongo"

if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root."
    exit 1
fi

detect_os() {
    if [[ -f /etc/centos-release ]]; then
        echo "centos"
    elif [[ -f /etc/lsb-release ]]; then
        echo "ubuntu"
    else
        echo "unsupported"
    fi
}

add_mongo_repo_centos() {
    cat <<EOF | sudo tee /etc/yum.repos.d/mongodb-org-6.0.repo > /dev/null
[mongodb-org-6.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/\$releasever/mongodb-org/6.0/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-6.0.asc
EOF
    sudo yum install -y epel-release
}

add_mongo_repo_ubuntu() {
    wget -qO - https://www.mongodb.org/static/pgp/server-6.0.asc | sudo apt-key add -
    echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu $(lsb_release -cs)/mongodb-org/6.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-6.0.list
    sudo apt-get update -y
}

install_mongo_centos() {
    sudo yum install -y mongodb-org
}

install_mongo_ubuntu() {
    sudo apt-get install -y mongodb-org
}

configure_mongo() {
    sudo tee "${MONGO_CONF_FILE}" > /dev/null <<EOF
# mongod.conf

# Where to store data.
storage:
  dbPath: ${MONGO_DATA_DIR}
  journal:
    enabled: true

# where to write logging data.
systemLog:
  destination: file
  logAppend: true
  path: ${MONGO_LOG_DIR}/mongod.log

# network interfaces
net:
  port: ${MONGO_PORT}
  bindIp: 0.0.0.0
EOF
    sudo mkdir -p "${MONGO_LOG_DIR}" "${MONGO_DATA_DIR}"
    sudo chown -R mongod:mongod "${MONGO_LOG_DIR}" "${MONGO_DATA_DIR}"
}

start_enable_mongo() {
    sudo systemctl start mongod
    sudo systemctl enable mongod
}

restart_check_mongo() {
    sudo systemctl restart mongod
    sudo systemctl status mongod --no-pager
}

configure_firewall() {
    if command -v firewall-cmd &> /dev/null; then
        sudo firewall-cmd --add-port=${MONGO_PORT}/tcp --zone=public --permanent
        sudo firewall-cmd --reload
    fi
}

check_mongo_port() {
    if netstat -tlnu | grep -q ":${MONGO_PORT}"; then
        printf "MongoDB is listening on port %d\n" "${MONGO_PORT}"
    else
        printf "MongoDB is not listening on port %d\n" "${MONGO_PORT}" >&2
        return 1
    fi
}

main() {
    local os
    os=$(detect_os)

    case "${os}" in
        centos)
            add_mongo_repo_centos
            install_mongo_centos
            ;;
        ubuntu)
            add_mongo_repo_ubuntu
            install_mongo_ubuntu
            ;;
        *)
            printf "Unsupported OS\n" >&2
            exit 1
            ;;
    esac

    configure_mongo
    start_enable_mongo
    restart_check_mongo
    configure_firewall
    check_mongo_port
    printf "Cài đặt MongoDB hoàn tất. Bạn có thể truy cập MongoDB tại mongodb://%s:%d\n" "$(hostname -I | awk '{print $1}')" "${MONGO_PORT}"
}

main "$@"
