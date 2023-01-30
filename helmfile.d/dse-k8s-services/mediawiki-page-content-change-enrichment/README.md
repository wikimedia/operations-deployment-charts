# mediawiki-page-content-change-enrichment

A pyflink based streaming application that consumes
the `mediawiki.page_change` stream, requests
raw wiki page content (i.e. not parsed) from the
MediaWiki api, enriches the event with that content,
and then emits to the `mediawiki.page_content_change` stream.

See: [Design and Implement realtime enrichment pipeline for MW page change with content
](https://phabricator.wikimedia.org/T307959)


NOTE: This is deployed in dse-k8s for now, as we experiment with
the new flink-kubernetes-operator and flink-app chart, and learn
about state management, HA, and streaming service restarts.
The intention is to eventually deploy this service to wikikube k8s.
