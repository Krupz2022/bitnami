#!/bin/bash
# Copyright VMware, Inc.
# SPDX-License-Identifier: APACHE-2.0

# shellcheck disable=SC1091

set -o errexit
set -o nounset
set -o pipefail
# set -o xtrace # Uncomment this line for debugging purposes

# Load ERPNext environment
. /opt/bitnami/scripts/erpnext-env.sh

# Load libraries
. /opt/bitnami/scripts/liberpnext.sh

# This is going to regenerate Redis configuration files, with a new value for 'maxmemory'
info "Regenerating Redis configuration"
# By default, the 'bench setup redis' command does not produce any output
# By setting BITNAMI_DEBUG="yes" we avoid hiding errors
BITNAMI_DEBUG="yes" erpnext_execute setup redis

# Restart services for the memory configuration changes to take effect
if [[ "$BITNAMI_SERVICE_MANAGER" = "monit" ]]; then
    /opt/bitnami/scripts/erpnext-redis-cache/restart.sh
    /opt/bitnami/scripts/erpnext-redis-socketio/restart.sh
    /opt/bitnami/scripts/erpnext-redis-queue/restart.sh
elif [[ "$BITNAMI_SERVICE_MANAGER" = "systemd" ]]; then
    systemctl restart bitnami.erpnext-redis-cache.service
    systemctl restart bitnami.erpnext-redis-socketio.service
    systemctl restart bitnami.erpnext-redis-queue.service
else
    error "Unsupported service manager ${BITNAMI_SERVICE_MANAGER}"
    exit 1
fi
