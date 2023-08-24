#!/bin/bash
# Copyright VMware, Inc.
# SPDX-License-Identifier: APACHE-2.0
#
# Environment configuration for erpnext

# The values for all environment variables will be set in the below order of precedence
# 1. Custom environment variables defined below after Bitnami defaults
# 2. Constants defined in this file (environment variables with no default), i.e. BITNAMI_ROOT_DIR
# 3. Environment variables overridden via external files using *_FILE variables (see below)
# 4. Environment variables set externally (i.e. current Bash context/Dockerfile/userdata)

# Load logging library
# shellcheck disable=SC1090,SC1091
. /opt/bitnami/scripts/liblog.sh

export BITNAMI_ROOT_DIR="/opt/bitnami"
export BITNAMI_VOLUME_DIR="/bitnami"

# Logging configuration
export MODULE="${MODULE:-erpnext}"
export BITNAMI_DEBUG="${BITNAMI_DEBUG:-false}"

# By setting an environment variable matching *_FILE to a file path, the prefixed environment
# variable will be overridden with the value specified in that file
erpnext_env_vars=(
    ERPNEXT_USERNAME
    ERPNEXT_PASSWORD
    ERPNEXT_EMAIL
    ERPNEXT_FIRST_NAME
    ERPNEXT_LAST_NAME
    ERPNEXT_SMTP_HOST
    ERPNEXT_SMTP_PORT_NUMBER
    ERPNEXT_SMTP_USER
    ERPNEXT_SMTP_PASSWORD
    ERPNEXT_SMTP_PROTOCOL
    ERPNEXT_DATABASE_HOST
    ERPNEXT_DATABASE_PORT_NUMBER
    ERPNEXT_DATABASE_NAME
    ERPNEXT_DATABASE_ADMIN_USER
    ERPNEXT_DATABASE_ADMIN_PASSWORD
    ERPNEXT_NODE_SOCKETIO_PORT_NUMBER
    ERPNEXT_REDIS_CACHE_HOST
    ERPNEXT_REDIS_CACHE_PORT_NUMBER
    ERPNEXT_REDIS_SOCKETIO_HOST
    ERPNEXT_REDIS_SOCKETIO_PORT_NUMBER
    ERPNEXT_REDIS_QUEUE_HOST
    ERPNEXT_REDIS_QUEUE_PORT_NUMBER
    SMTP_HOST
    SMTP_PORT
    ERPNEXT_SMTP_PORT
    SMTP_USER
    SMTP_PASSWORD
    SMTP_PROTOCOL
    MARIADB_HOST
    MARIADB_PORT_NUMBER
    MARIADB_DATABASE_NAME
    MARIADB_ROOT_USER
    MARIADB_ROOT_PASSWORD
)
for env_var in "${erpnext_env_vars[@]}"; do
    file_env_var="${env_var}_FILE"
    if [[ -n "${!file_env_var:-}" ]]; then
        if [[ -r "${!file_env_var:-}" ]]; then
            export "${env_var}=$(< "${!file_env_var}")"
            unset "${file_env_var}"
        else
            warn "Skipping export of '${env_var}'. '${!file_env_var:-}' is not readable."
        fi
    fi
done
unset erpnext_env_vars

# Load Bitnami installation configuration and user-data
[[ ! -f "${BITNAMI_ROOT_DIR}/scripts/bitnami-env.sh" ]] || . "${BITNAMI_ROOT_DIR}/scripts/bitnami-env.sh"

# Paths
export ERPNEXT_BASE_DIR="${BITNAMI_ROOT_DIR}/erpnext"
export ERPNEXT_BIN_DIR="${ERPNEXT_BASE_DIR}/bin"
export PATH="${ERPNEXT_BIN_DIR}:${BITNAMI_ROOT_DIR}/common/bin:${BITNAMI_ROOT_DIR}/redis/bin:${BITNAMI_ROOT_DIR}/node/bin:${BITNAMI_ROOT_DIR}/git/bin:${PATH}"

# System users (when running with a privileged user)
export ERPNEXT_DAEMON_USER="daemon"
export ERPNEXT_DAEMON_GROUP="daemon"

# ERPNext configuration

# ERPNext credentials
export ERPNEXT_USERNAME="${ERPNEXT_USERNAME:-user}" # only used during the first initialization
export ERPNEXT_PASSWORD="${ERPNEXT_PASSWORD:-bitnami}" # only used during the first initialization
export ERPNEXT_EMAIL="${ERPNEXT_EMAIL:-user@example.com}" # only used during the first initialization
export ERPNEXT_FIRST_NAME="${ERPNEXT_FIRST_NAME:-UserName}" # only used during the first initialization
export ERPNEXT_LAST_NAME="${ERPNEXT_LAST_NAME:-LastName}" # only used during the first initialization

# ERPNext SMTP credentials
ERPNEXT_SMTP_HOST="${ERPNEXT_SMTP_HOST:-"${SMTP_HOST:-}"}"
export ERPNEXT_SMTP_HOST="${ERPNEXT_SMTP_HOST:-}" # only used during the first initialization
ERPNEXT_SMTP_PORT_NUMBER="${ERPNEXT_SMTP_PORT_NUMBER:-"${SMTP_PORT:-}"}"
ERPNEXT_SMTP_PORT_NUMBER="${ERPNEXT_SMTP_PORT_NUMBER:-"${ERPNEXT_SMTP_PORT:-}"}"
export ERPNEXT_SMTP_PORT_NUMBER="${ERPNEXT_SMTP_PORT_NUMBER:-}" # only used during the first initialization
ERPNEXT_SMTP_USER="${ERPNEXT_SMTP_USER:-"${SMTP_USER:-}"}"
export ERPNEXT_SMTP_USER="${ERPNEXT_SMTP_USER:-}" # only used during the first initialization
ERPNEXT_SMTP_PASSWORD="${ERPNEXT_SMTP_PASSWORD:-"${SMTP_PASSWORD:-}"}"
export ERPNEXT_SMTP_PASSWORD="${ERPNEXT_SMTP_PASSWORD:-}" # only used during the first initialization
ERPNEXT_SMTP_PROTOCOL="${ERPNEXT_SMTP_PROTOCOL:-"${SMTP_PROTOCOL:-}"}"
export ERPNEXT_SMTP_PROTOCOL="${ERPNEXT_SMTP_PROTOCOL:-}" # only used during the first initialization

# Database configuration
export ERPNEXT_DEFAULT_DATABASE_HOST="127.0.0.1" # only used at build time
ERPNEXT_DATABASE_HOST="${ERPNEXT_DATABASE_HOST:-"${MARIADB_HOST:-}"}"
export ERPNEXT_DATABASE_HOST="${ERPNEXT_DATABASE_HOST:-$ERPNEXT_DEFAULT_DATABASE_HOST}" # only used during the first initialization
ERPNEXT_DATABASE_PORT_NUMBER="${ERPNEXT_DATABASE_PORT_NUMBER:-"${MARIADB_PORT_NUMBER:-}"}"
export ERPNEXT_DATABASE_PORT_NUMBER="${ERPNEXT_DATABASE_PORT_NUMBER:-3306}" # only used during the first initialization
ERPNEXT_DATABASE_NAME="${ERPNEXT_DATABASE_NAME:-"${MARIADB_DATABASE_NAME:-}"}"
export ERPNEXT_DATABASE_NAME="${ERPNEXT_DATABASE_NAME:-bitnami_erpnext}" # only used during the first initialization
ERPNEXT_DATABASE_ADMIN_USER="${ERPNEXT_DATABASE_ADMIN_USER:-"${MARIADB_ROOT_USER:-}"}"
export ERPNEXT_DATABASE_ADMIN_USER="${ERPNEXT_DATABASE_ADMIN_USER:-root}" # only used during the first initialization
ERPNEXT_DATABASE_ADMIN_PASSWORD="${ERPNEXT_DATABASE_ADMIN_PASSWORD:-"${MARIADB_ROOT_PASSWORD:-}"}"
export ERPNEXT_DATABASE_ADMIN_PASSWORD="${ERPNEXT_DATABASE_ADMIN_PASSWORD:-}" # only used during the first initialization

# erpnext-node-socketio configuration
export ERPNEXT_NODE_SOCKETIO_PID_FILE="${ERPNEXT_BASE_DIR}/frappe-bench/config/pids/node_socketio.pid"
export ERPNEXT_NODE_SOCKETIO_LOG_FILE="${ERPNEXT_BASE_DIR}/frappe-bench/logs/node-socketio.log"
export ERPNEXT_NODE_SOCKETIO_PORT_NUMBER="${ERPNEXT_NODE_SOCKETIO_PORT_NUMBER:-9000}"

# erpnext-frappe-schedule configuration
export ERPNEXT_FRAPPE_SCHEDULE_PID_FILE="${ERPNEXT_BASE_DIR}/frappe-bench/config/pids/frappe_schedule.pid"
export ERPNEXT_FRAPPE_SCHEDULE_LOG_FILE="${ERPNEXT_BASE_DIR}/frappe-bench/logs/schedule.log"

# Frappe workers configurations
export ERPNEXT_FRAPPE_WORKER_LOG_FILE="${ERPNEXT_BASE_DIR}/frappe-bench/logs/worker.log"
export ERPNEXT_FRAPPE_DEFAULT_WORKER_PID_FILE="${ERPNEXT_BASE_DIR}/frappe-bench/config/pids/frappe_default_worker.pid"
export ERPNEXT_FRAPPE_SHORT_WORKER_PID_FILE="${ERPNEXT_BASE_DIR}/frappe-bench/config/pids/frappe_short_worker.pid"
export ERPNEXT_FRAPPE_LONG_WORKER_PID_FILE="${ERPNEXT_BASE_DIR}/frappe-bench/config/pids/frappe_long_worker.pid"

# erpnext-redis-cache configuration
export ERPNEXT_REDIS_CACHE_HOST="${ERPNEXT_REDIS_CACHE_HOST:-localhost}"
export ERPNEXT_REDIS_CACHE_PORT_NUMBER="${ERPNEXT_REDIS_CACHE_PORT_NUMBER:-13000}"
export ERPNEXT_REDIS_CACHE_LOG_FILE="${ERPNEXT_BASE_DIR}/frappe-bench/logs/redis-cache.log"

# erpnext-redis-socketio configuration
export ERPNEXT_REDIS_SOCKETIO_HOST="${ERPNEXT_REDIS_SOCKETIO_HOST:-localhost}"
export ERPNEXT_REDIS_SOCKETIO_PORT_NUMBER="${ERPNEXT_REDIS_SOCKETIO_PORT_NUMBER:-12000}"
export ERPNEXT_REDIS_SOCKETIO_LOG_FILE="${ERPNEXT_BASE_DIR}/frappe-bench/logs/redis-socketio.log"

# erpnext-redis-queue configuration
export ERPNEXT_REDIS_QUEUE_HOST="${ERPNEXT_REDIS_QUEUE_HOST:-localhost}"
export ERPNEXT_REDIS_QUEUE_PORT_NUMBER="${ERPNEXT_REDIS_QUEUE_PORT_NUMBER:-11000}"
export ERPNEXT_REDIS_QUEUE_LOG_FILE="${ERPNEXT_BASE_DIR}/frappe-bench/logs/redis-queue.log"

# Custom environment variables may be defined below
