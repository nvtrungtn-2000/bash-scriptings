#!/bin/bash

PYTHON_VERSION="3.8.10"
PYTHON_SRC_URL="https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz"
TMP_DIR="/tmp"
PYTHON_DIR="${TMP_DIR}/Python-${PYTHON_VERSION}"
LOG_FILE="/tmp/python_install_$(date +%Y%m%d_%H%M%S).log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log "This script must be run as root" >&2
        exit 1
    fi
}

install_dependencies() {
    log "Installing dependencies..."
    if ! yum install gcc openssl-devel bzip2-devel libffi-devel -y >> "$LOG_FILE" 2>&1; then
        log "Error installing dependencies" >&2
        return 1
    fi
}

download_python_source() {
    local url=$1
    local dest_dir=$2
    log "Downloading Python source..."
    if ! wget -P "$dest_dir" "$url" >> "$LOG_FILE" 2>&1; then
        log "Error downloading Python source" >&2
        return 1
    fi
}

extract_python_source() {
    local src_file=$1
    local dest_dir=$2
    log "Extracting Python source..."
    if ! tar xzf "$src_file" -C "$dest_dir" >> "$LOG_FILE" 2>&1; then
        log "Error extracting Python source" >&2
        return 1
    fi
}

compile_and_install_python() {
    local src_dir=$1
    log "Compiling and installing Python..."
    cd "$src_dir" || return 1
    if ! ./configure --enable-optimizations >> "$LOG_FILE" 2>&1; then
        log "Error configuring Python build" >&2
        return 1
    fi
    if ! make altinstall >> "$LOG_FILE" 2>&1; then
        log "Error installing Python" >&2
        return 1
    fi
}

update_bashrc() {
    log "Updating .bashrc..."
    if ! echo -e "\nalias python='python3.8'" >> ~/.bashrc; then
        log "Error updating .bashrc" >&2
        return 1
    fi
    if ! source ~/.bashrc >> "$LOG_FILE" 2>&1; then
        log "Error sourcing .bashrc" >&2
        return 1
    fi
}

verify_python_installation() {
    log "Verifying Python installation..."
    if ! python3.8 --version | grep -q "Python 3.8"; then
        log "Python installation verification failed" >&2
        return 1
    fi
}

upgrade_pip() {
    log "Upgrading pip..."
    if ! python3.8 -m pip install --upgrade pip >> "$LOG_FILE" 2>&1; then
        log "Error upgrading pip" >&2
        return 1
    fi
}

install_paramiko() {
    log "Installing paramiko..."
    if ! pip3.8 install --root-user-action=ignore paramiko >> "$LOG_FILE" 2>&1; then
        log "Error installing paramiko" >&2
        return 1
    fi
}

cleanup() {
    log "Cleaning up temporary files..."
    rm -rf "$PYTHON_DIR" "${TMP_DIR}/Python-${PYTHON_VERSION}.tgz"
}

main() {
    check_root
    install_dependencies || exit 1
    download_python_source "$PYTHON_SRC_URL" "$TMP_DIR" || exit 1
    extract_python_source "${TMP_DIR}/Python-${PYTHON_VERSION}.tgz" "$TMP_DIR" || exit 1
    compile_and_install_python "$PYTHON_DIR" || exit 1
    update_bashrc || exit 1
    verify_python_installation || exit 1
    upgrade_pip || exit 1
    install_paramiko || exit 1
    cleanup
    log "Python $PYTHON_VERSION installation completed successfully!"
}

main
