# mediawiki-page-content-change-enrichment

A pyflink based streaming application that consumes
the `mediawiki.page_change.v1` stream, requests
raw wiki page content (i.e. not parsed) from the
MediaWiki api, enriches the event with that content,
and then emits to the `mediawiki.page_content_change.v1` stream.

See:
- [MediaWiki Event Enrichment](https://wikitech.wikimedia.org/wiki/MediaWiki_Event_Enrichment)
- [SLOs][https://wikitech.wikimedia.org/wiki/MediaWiki_Event_Enrichment/SLO/Mediawiki_Page_Content_Change_Enrichment]
- [mediawiki-event-enrichment](https://gitlab.wikimedia.org/repos/data-engineering/mediawiki-event-enrichment)
- [Design and Implement realtime enrichment pipeline for MW page change with content
](https://phabricator.wikimedia.org/T307959)

