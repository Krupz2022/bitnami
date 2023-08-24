#!/bin/bash
# Copyright VMware, Inc.
# SPDX-License-Identifier: APACHE-2.0

# shellcheck disable=SC1091

set -o errexit
set -o nounset
set -o pipefail
# set -o xtrace # Uncomment this line for debugging purposes

# Load Redis environment variables
. /opt/bitnami/scripts/redis-env.sh

# Load libraries
. /opt/bitnami/scripts/libredis.sh
. /opt/bitnami/scripts/libfs.sh

for dir in "$REDIS_VOLUME_DIR" "$REDIS_DATA_DIR" "$REDIS_BASE_DIR" "$REDIS_CONF_DIR"; do
    ensure_dir_exists "$dir"
done
chmod -R g+rwX /bitnami "$REDIS_VOLUME_DIR" "$REDIS_BASE_DIR"

cp "${REDIS_BASE_DIR}/etc/redis-default.conf" "$REDIS_CONF_FILE"
chmod g+rw "$REDIS_CONF_FILE"
# Default Redis config
info "Setting Redis config file..."
redis_conf_set port "$REDIS_DEFAULT_PORT_NUMBER"
redis_conf_set dir "$REDIS_DATA_DIR"
redis_conf_set pidfile "$REDIS_PID_FILE"
redis_conf_set daemonize yes

# Load additional required libraries
# shellcheck disable=SC1091
. /opt/bitnami/scripts/libos.sh
. /opt/bitnami/scripts/libservice.sh

# Log to a file
redis_conf_set logfile "$REDIS_LOG_FILE"

# Enable extra service management configuration
if [[ "$BITNAMI_SERVICE_MANAGER" = "monit" ]]; then
    generate_monit_conf "redis" "$REDIS_PID_FILE" /opt/bitnami/scripts/redis/start.sh /opt/bitnami/scripts/redis/stop.sh
elif [[ "$BITNAMI_SERVICE_MANAGER" = "systemd" ]]; then
    generate_systemd_conf "redis" \
        --name "Redis" \
        --user "$REDIS_DAEMON_USER" \
        --group "$REDIS_DAEMON_GROUP" \
        --exec-start "${REDIS_BIN_DIR}/redis-server ${REDIS_CONF_FILE}" \
        --pid-file "$REDIS_PID_FILE"
else
    error "Unsupported service manager ${BITNAMI_SERVICE_MANAGER}"
    exit 1
fi
# 'su' option used to avoid: "error: skipping (...) because parent directory has insecure permissions (It's world writable or writable by group which is not "root")"
generate_logrotate_conf "redis" "$REDIS_LOG_FILE" --extra "su ${REDIS_DAEMON_USER} ${REDIS_DAEMON_GROUP}"

info "Creating Redis daemon user"
ensure_user_exists "$REDIS_DAEMON_USER" --group "$REDIS_DAEMON_GROUP"

for dir in "$REDIS_TMP_DIR" "$REDIS_LOG_DIR" "$REDIS_DATA_DIR"; do
    ensure_dir_exists "$dir"
    chown "$REDIS_DAEMON_USER:$REDIS_DAEMON_GROUP" "$dir"
done

ensure_dir_exists "${REDIS_CONF_DIR}/bitnami"

# Create configuration files for setting Redis optimization parameters depending on the instance size
# Default to micro configuration until a resize is performed
ln -sf "bitnami/memory-micro.conf" "${REDIS_CONF_DIR}/memory.conf"
read -r -a supported_machine_sizes <<< "$(get_supported_machine_sizes)"

for machine_size in "${supported_machine_sizes[@]}"; do
    case "$machine_size" in
        micro)
            maxmemory="600mb"
            maxclients="100"
            ;;
        small)
            maxmemory="1200mb"
            maxclients="200"
            ;;
        medium)
            maxmemory="2400mb"
            maxclients="400"
            ;;
        large)
            maxmemory="4800mb"
            maxclients="800"
            ;;
        xlarge)
            maxmemory="9600mb"
            maxclients="1600"
            ;;
        2xlarge)
            maxmemory="19200mb"
            maxclients="3200"
            ;;
        *)
            error "Unknown machine size '${machine_size}'"
            exit 1
            ;;
        esac
    cat >"${REDIS_CONF_DIR}/bitnami/memory-${machine_size}.conf" <<EOF
# Memory settings
#
# Note: This will be modified on server size changes

maxclients ${maxclients}
maxmemory ${maxmemory}
EOF
done

# We cannot add the include at the end of the file, instead we should use the section in the file prepared for includes
replace_in_file "$REDIS_CONF_FILE" '(/path/to/other.conf)' "\1\n# Memory Settings\ninclude '${REDIS_CONF_DIR}/memory.conf'"
if ! grep -q memory.conf "$REDIS_CONF_FILE"; then
    error "Could not enable memory configuration"
    exit 1
fi

info "Setting kernel configurations"
cat >/etc/sysctl.d/99-redis.conf <<EOF
vm.overcommit_memory=1
net.core.somaxconn=65535
EOF
sysctl -p /etc/sysctl.d/99-redis.conf
echo -n never >/sys/kernel/mm/transparent_hugepage/enabled
