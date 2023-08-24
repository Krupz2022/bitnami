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
. /opt/bitnami/scripts/libos.sh
. /opt/bitnami/scripts/libfs.sh
. /opt/bitnami/scripts/libredis.sh

# Ensure Redis environment variables settings are valid
redis_validate
# Ensure Redis daemon user exists when running as root
am_i_root && ensure_user_exists "$REDIS_DAEMON_USER" --group "$REDIS_DAEMON_GROUP"
# Ensure Redis is initialized
redis_initialize

if [[ "$BITNAMI_SERVICE_MANAGER" = "systemd" ]]; then
    if is_boolean_yes "$REDIS_DISABLE_SERVICE"; then
        # Disable the Redis service if desired
        info "Disabling Redis service"
        systemctl disable bitnami.redis.service
    else
        # If not, start the Redis service
        info "Starting Redis service"
        systemctl start bitnami.redis.service
    fi
fi
