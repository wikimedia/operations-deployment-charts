# mw-dump-rev-content-reconcile-enrich

A pyflink based streaming application that consumes
the `mediawiki.dump.revision_content_history.reconcile` stream,
requests raw wiki page content (i.e. not parsed) and redirect info
from the  MediaWiki api, enriches the event with that content,
and then emits to the `mediawiki.dump.revision_content_history.reconcile.enriched`
stream.

This application is used to enrich events emitted
by the Dumps 2.0 reconciliation service.

# Application

Application code is available in the [mediawiki-event-enrichment](https://gitlab.wikimedia.org/repos/data-engineering/mediawiki-event-enrichment)
repository.

# Maintainers

The application is operated by the Dumps 2.0 group
within Data Platform Engineering.

You can reach the team on Slack at `#datadumps-new-class`.

# References
- [MediaWiki Event Enrichment](https://wikitech.wikimedia.org/wiki/MediaWiki_Event_Enrichment)
- [mediawiki-event-enrichment](https://gitlab.wikimedia.org/repos/data-engineering/mediawiki-event-enrichment)
- [Flink job to enrich reconciliation events](https://phabricator.wikimedia.org/T368787)

