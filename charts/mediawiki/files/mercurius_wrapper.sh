#!/bin/bash
# SPDX-License-Identifier: Apache-2.0

# Extract the database value from an EventBus event and pass it to
# MWScript as the --wiki parameter, while re-passing the same stdin to
# the MWScript script

# Exit on a missing key or JSON that jq otherwise couldn't read

# This script will only work on a *single* line JSON input - pretty
# printed JSON will be rejected, and anything that messes with the
# field separator or messes up the filename will be rejected also.

# Read raw input, don't interpret any escaping
read -r INPUT
DATABASE=$(echo "${INPUT}" | jq -e -r .database)

if [ $? -ne 0 ] || [ -z "$DATABASE" ]; then
    echo "Couldn't extract database key from input JSON!"
    exit 1
fi

echo "${INPUT}" | /usr/bin/php /srv/mediawiki/multiversion/MWScript.php extensions/EventBus/maintenance/runSingleJobStdin.php --wiki="${DATABASE}"
