eventstreams-internal is an instance of eventstreams consuming all streams (as apposed to the
limited set of public streams that eventstreams exposes) declared in
EventStreamConfig ($wgEventStreams in mediawiki-config) from Kafka jumbo-eqiad.

It allows consumption of streams from Kafka over HTTP, including via a nice browser based UI.

This instance should never be publicly available.  It exists for internal usage only.
