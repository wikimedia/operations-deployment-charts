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

To catch up a specific range of kafka record offsets (as quickly as possible), invoke a backfill release
for the appropriate consumer. These will use additional values from values-backfill.yaml

For a more complete orchestration of reindex and backfill see https://gitlab.wikimedia.org/repos/search-platform/cirrus-reindex-orchestrator/

```sh
    helmfile
        --environment eqiad
        --selector name=consumer-cloudelastic-backfill
        apply
        --context 5 \
        --set "backfill=true" \
        --set "app.config_files.app\.config\.yaml.kafka-source-start-time=2024-02-01T01:23:45Z" \
        --set "app.config_files.app\.config\.yaml.kafka-source-end-time=2024-02-01T02:34:56Z"
