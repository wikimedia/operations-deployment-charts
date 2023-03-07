# mediawiki-page-content-change-enrichment

A pyflink based streaming application that consumes
the `mediawiki.page_change` stream, requests
raw wiki page content (i.e. not parsed) from the
MediaWiki api, enriches the event with that content,
and then emits to the `mediawiki.page_content_change` stream.

See:
- [mediawiki-event-enrichment](https://gitlab.wikimedia.org/repos/data-engineering/mediawiki-event-enrichment)
- [Design and Implement realtime enrichment pipeline for MW page change with content
](https://phabricator.wikimedia.org/T307959)

