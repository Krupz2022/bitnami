#!/bin/bash
# Copyright VMware, Inc.
# SPDX-License-Identifier: APACHE-2.0

# shellcheck disable=SC1091

set -o errexit
set -o nounset
set -o pipefail
# set -o xtrace # Uncomment this line for debugging purposes

# Load libraries
. /opt/bitnami/scripts/libapache.sh

# Load Apache environment
. /opt/bitnami/scripts/apache-env.sh

# Enable mod_wsgi
apache_enable_module "wsgi_module" "modules/mod_wsgi.so"
