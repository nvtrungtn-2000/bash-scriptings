#!/bin/bash

PYTHON_VERSION="3.8.10"
PYTHON_SRC_URL="https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz"
TMP_DIR="/tmp"
PYTHON_DIR="${TMP_DIR}/Python-${PYTHON_VERSION}"

install_dependencies() {
    if ! yum install gcc openssl-devel bzip2-devel libffi-devel -y; then
        printf "Error installing dependencies\n" >&2
        return 1
    fi
}

download_python_source() {
    local url=$1
    local dest_dir=$2
    if ! wget -P "$dest_dir" "$url"; then
        printf "Error downloading Python source\n" >&2
        return 1
    fi
}

extract_python_source() {
    local src_file=$1
    local dest_dir=$2
    if ! tar xzf "$src_file" -C "$dest_dir"; then
        printf "Error extracting Python source\n" >&2
        return 1
    fi
}

compile_and_install_python() {
    local src_dir=$1
    cd "$src_dir" || return 1
    if ! ./configure --enable-optimizations; then
        printf "Error configuring Python build\n" >&2
        return 1
    fi
    if ! make altinstall; then
        printf "Error installing Python\n" >&2
        return 1
    fi
}

update_bashrc() {
    if ! printf "\nalias python='python3.8'\n" >> ~/.bashrc; then
        printf "Error updating .bashrc\n" >&2
        return 1
    fi
    if ! source ~/.bashrc; then
        printf "Error sourcing .bashrc\n" >&2
        return 1
    fi
}

verify_python_installation() {
    if ! python --version | grep -q "Python 3.8"; then
        printf "Python installation verification failed\n" >&2
        return 1
    fi
}

upgrade_pip() {
    if ! python -m pip install --upgrade pip; then
        printf "Error upgrading pip\n" >&2
        return 1
    fi
}

install_paramiko() {
    if ! pip install --root-user-action=ignore paramiko; then
        printf "Error installing paramiko\n" >&2
        return 1
    fi
}

main() {
    if ! install_dependencies; then
        return 1
    fi

    if ! download_python_source "$PYTHON_SRC_URL" "$TMP_DIR"; then
        return 1
    fi

    if ! extract_python_source "${TMP_DIR}/Python-${PYTHON_VERSION}.tgz" "$TMP_DIR"; then
        return 1
    fi

    if ! compile_and_install_python "$PYTHON_DIR"; then
        return 1
    fi

    if ! update_bashrc; then
        return 1
    fi

    if ! verify_python_installation; then
        return 1
    fi

    if ! upgrade_pip; then
        return 1
    fi

    if ! install_paramiko; then
        return 1
    fi
}

main