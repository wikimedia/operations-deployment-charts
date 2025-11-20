# Redioscope

Redioscope is an auxiliary service that scans Redis databases and generates
statistics based on the numbers it finds. The statistics are then exposed to
Prometheus. See https://gitlab.wikimedia.org/repos/mediawiki/services/redioscope.

Redioscope should not be exposed to the internet, and it should not run on
the WikiKube cluster. 

See https://phabricator.wikimedia.org/T407999 for context.