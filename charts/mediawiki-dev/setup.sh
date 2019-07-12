#!/bin/sh
set -eu

# Shamelessly repurposed from Adshore's mediawiki-docker-dev: https://github.com/addshore/mediawiki-docker-dev/
# Hide the current LocalSettings.php if it exists
if [ -f /var/www/html/LocalSettings.php ]
then
    mv /var/www/html/LocalSettings.php /var/www/html/LocalSettings.php.docker.tmp
fi

# Install the base Mediawiki tables on the db server & remove the generated LocalSettings.php
if [ "$DB_SERVER" = "" ]
then
       echo 'DB_SERVER not set, exiting.'
       exit 1
fi

if [ "$DB_PASS" = "" ]
then
       echo 'DB_PASS not set, exiting.'
       exit 1
fi

if [ "$DB_NAME" = "" ]
then
       echo 'DB_NAME not set, exiting.'
       exit 1
fi

php /var/www/html/maintenance/install.php --dbuser "root" --dbpass "$DB_PASS" --dbname "$DB_NAME" --dbserver "$DB_SERVER" --lang "en" --pass "$WIKI_ADMIN_PASS" "$WIKI_NAME" "$WIKI_ADMIN";
rm /var/www/html/LocalSettings.php

# Move back the old LocalSettings if we had moved one!
if [ -f /var/www/html/LocalSettings.php.docker.tmp ]
then
    mv /var/www/html/LocalSettings.php.docker.tmp /var/www/html/LocalSettings.php
fi

# Run update.php too
php /var/www/html/maintenance/update.php --wiki "$DB_NAME" --quick