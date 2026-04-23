# mediawiki-page-html-feature-counts-change-enrichment

A pyflink based streaming application that consumes the `mediawiki.page_html_content_change.v1` stream, computes SimpleEditTypes using mwedittypes library, enriches the event with that content, and then emits to the `mediawiki.page_html_feature_counts_change.v1` stream.