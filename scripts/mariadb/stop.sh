#!/bin/bash
# Copyright VMware, Inc.
# SPDX-License-Identifier: APACHE-2.0

# shellcheck disable=SC1091

set -o errexit
set -o nounset
set -o pipefail
# set -o xtrace # Uncomment this line for debugging purposes

# Load libraries
. /opt/bitnami/scripts/libos.sh
. /opt/bitnami/scripts/libmariadb.sh

# Load MariaDB environment variables
. /opt/bitnami/scripts/mariadb-env.sh

error_code=0

if is_mysql_running; then
    BITNAMI_QUIET=1 mysql_stop
    if ! retry_while "is_mysql_not_running"; then
        error "mariadb could not be stopped"
        error_code=1
    else
        info "mariadb stopped"
    fi
else
    info "mariadb is not running"
fi

exit "$error_code"
