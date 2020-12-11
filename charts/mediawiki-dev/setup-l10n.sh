#!/bin/bash
set -eu

if [ "${L10N_CACHE:-}" ]; then
    # Use the top level directory as the lockfile.  This means that if
    # multiple pods start at the same time on a given node, only one
    # of them will do the expensive work.  The others will wait for
    # the first one to finish, then they'll run and find that there is
    # no work to do.
    # FIXME: Improve this by locking on the MW-version subdir instead of the top level. 
    flock $L10N_CACHE \
          php /var/www/html/maintenance/rebuildLocalisationCache.php \
          --wiki "$DB_NAME" \
          --threads $(getconf _NPROCESSORS_ONLN) \
          --no-clear-message-blob-store
fi
