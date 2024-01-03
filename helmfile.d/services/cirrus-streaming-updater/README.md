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

## Usage

### Override Values

Use `--set "FULLY.QUALIFIED.KEY=VALUE"` (with quotes) syntax to override properties present in the `values` files. 

To override app-specific config options, they must be merged in the `app.config.yaml` file that is created by the chart an passed a first (and sole) argument to either application:
Use `--set "app.config_files.app\.config\.yaml.CONFIG_KEY=VALUE"` (with quotes) to add/override config properties.
Keep in mind, that changing config properties inline is neither transparent nor persistent, so use it carefully.

### Backfill Batch

To catch up a specific range of kafka record offsets (as quickly as possible), deploy a release with the following overrides:

```properties
# UTC date/time to start from, will be mapped to offset, use kafka-source-start-offset alternatively
app.config_files.app\.config\.yaml.kafka-source-start-time=
# UTC date/time to stop at, will be mapped to offset, use kafka-source-end-offset alternatively
app.config_files.app\.config\.yaml.kafka-source-end-time=
# Force fresh start
app.job.upgradeMode=stateless
# Optional, only in case it already runs
app.restartNonce=2
# Set to the highest number of partitions of all topics consumed, to achieve optimal distribution
# However, keep in mind that may also increase the number of fetch and sink operators.
# This causes increased pressure on MW APIs and ElasticSearch, respectively.
# You may reduce that load by shrinking `fetch-retry-queue-capacity` at the same time.
app.taskManager.replicas=5
```
