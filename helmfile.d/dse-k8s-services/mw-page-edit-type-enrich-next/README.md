# mediawiki-page-edit-type-simple-change-enrichment

A pyflink based streaming application that consumes
the `mediawiki.page_html_content_change.dev4:4.0.0` stream, computes SimpleEditTypes using mwedittypes library,
enriches the event with that content,
and then emits to the `mediawiki.page_edit_type_simple.dev0:2.0.0` stream.

This is a `staging` release.
