#!/bin/bash
# Copyright VMware, Inc.
# SPDX-License-Identifier: APACHE-2.0

# shellcheck disable=SC1090,SC1091

set -o errexit
set -o nounset
set -o pipefail
# set -o xtrace # Uncomment this line for debugging purposes

# Load ERPNext environment
. /opt/bitnami/scripts/erpnext-env.sh

# Load MySQL Client environment for 'mysql_remote_execute' (after 'erpnext-env.sh' so that MODULE is not set to a wrong value)
if [[ -f /opt/bitnami/scripts/mysql-client-env.sh ]]; then
    . /opt/bitnami/scripts/mysql-client-env.sh
elif [[ -f /opt/bitnami/scripts/mysql-env.sh ]]; then
    . /opt/bitnami/scripts/mysql-env.sh
elif [[ -f /opt/bitnami/scripts/mariadb-env.sh ]]; then
    . /opt/bitnami/scripts/mariadb-env.sh
fi

# Load libraries
. /opt/bitnami/scripts/liberpnext.sh

# Ensure ERPNext environment variables are valid
erpnext_validate

# Load additional libraries
# shellcheck disable=SC1090,SC1091
. /opt/bitnami/scripts/libwebserver.sh

# Load web server environment for web_server_* functions
. "/opt/bitnami/scripts/$(web_server_type)-env.sh"

# Enable extra service management configuration
info "Starting Redis services"

# Remove default Redis service management configuration (ERPNext will use multiple instances of Redis with custom configuration)
# When using systemd, there is no need to remove the default Redis service as it is already disabled by using REDIS_DISABLE_SERVICE
if [[ "$BITNAMI_SERVICE_MANAGER" = "monit" ]]; then
    remove_monit_conf "redis"
    remove_logrotate_conf "redis"
fi

# Pre-start redis instances since they are required for the setup wizard to succeed
for redis_instance in cache socketio queue; do
    if [[ "$BITNAMI_SERVICE_MANAGER" = "monit" ]]; then
        /opt/bitnami/scripts/"erpnext-redis-${redis_instance}"/start.sh
    elif [[ "$BITNAMI_SERVICE_MANAGER" = "systemd" ]]; then
        systemctl start "bitnami.erpnext-redis-${redis_instance}.service"
    else
        error "Unsupported service manager ${BITNAMI_SERVICE_MANAGER}"
        exit 1
    fi
done

# Ensure ERPNext is initialized
erpnext_initialize

# Grant ownership to the default "bitnami" SSH user to be able to edit files (some files are created during installation)
info "Granting ERPNext files ownership to the 'bitnami' user"
configure_permissions_ownership "${ERPNEXT_BASE_DIR}/frappe-bench/sites" -d "g+rwx" -f "g+rw" -u "bitnami" -g "$ERPNEXT_DAEMON_GROUP"
# Must belong to 'daemon' for log rotation to work
# But 'bench.log' must also be writable by the 'bitnami' user so it can run the Bench CLI
touch "${ERPNEXT_BASE_DIR}/frappe-bench/logs/bench.log"
configure_permissions_ownership "${ERPNEXT_BASE_DIR}/frappe-bench/logs" -u "$ERPNEXT_DAEMON_USER" -g "$ERPNEXT_DAEMON_GROUP"
chmod 666 "${ERPNEXT_BASE_DIR}/frappe-bench/logs/bench.log"
# Procfile and patches.txt need group write permissions for bench update to work
chmod g+w "${ERPNEXT_BASE_DIR}/frappe-bench/Procfile" "${ERPNEXT_BASE_DIR}/frappe-bench/patches.txt"

# Update web server configuration with runtime environment
web_server_update_app_configuration "erpnext"
