# cirrus-streaming-updater

A flink based streaming application in two parts that updates the
elasticsearch clusters used by cirrussearch. The first part, the
producer, consumes various event streams from mediawiki and generates
events indicating which pages need to be updated in the CirrusSearch.
The second part, the consumer, consumes updates from the the first
part and applies them to a single cirrussearch cluster (which is made
up of 3 elasticsearch clusters).

See:
- https://gitlab.wikimedia.org/repos/search-platform/cirrus-streaming-updater
- TODO
