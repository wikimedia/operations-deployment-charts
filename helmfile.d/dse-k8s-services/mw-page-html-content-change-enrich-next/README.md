# mediawiki-page-html-content-change-enrichment

A pyflink based streaming application that consumes
the `mediawiki.page_change.v1` stream, requests
HTML page content from the MediaWiki REST api,
enriches the event with that content,
and then emits to the `mediawiki.page_html_content_change.v1` stream.

This is a `staging` release.
