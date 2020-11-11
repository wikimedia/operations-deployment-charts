{{- define "updater-job-properties" -}}
##
# hostname for which the updater should capture the events for (filtering events based on meta.domain)
hostname: www.wikidata.org
##
# path to the generated checkpoints
checkpoint_dir: {{ .Values.main_app.config.checkpoint_dir }}
##
# path to store "spurious" events, events that are inconsistent with the state of the application
spurious_events_dir: {{ .Values.main_app.config.spurious_events_dir }}
##
# path to events considered "late" with the event reordering operation
late_events_dir: {{ .Values.main_app.config.late_events_dir }}
##
# path to events we were unable to fetch the data for
failed_ops_dir: {{ .Values.main_app.config.failed_ops_dir }}
##
# kafka brokers used to consume and produce messages
brokers: {{ .Values.main_app.config.brokers }}
##
# prefixes to append to all the input topic names, to support the WMF multi-DC layout of the kafka topics
topic_prefixes: eqiad.,codfw.
##
# input topics
rev_create_topic: mediawiki.revision-create
page_delete_topic: mediawiki.page-delete
suppressed_delete_topic: mediawiki.page-suppress
page_undelete_topic: mediawiki.page-undelete
##
# kafka consumer group, used to fetch the initial set of offset then only used for monitoring
consumer_group: {{ .Values.main_app.config.consumer_group }}
##
# parallelism for the sources
consumer_parallelism: {{ .Values.main_app.config.consumer_parallelism }}
##
# window length (ms) for the reordering operation
# reordering_window_length: 60000
##
# enforce parallelism of the reordering operation (defaults to job parallelism)
reordering_parallelism: {{ .Values.main_app.config.reordering_parallelism }}
##
# enforce parallelism of the decide mutation operation (large state) (defaults to job parallelism)
decide_mut_op_parallelism: {{ .Values.main_app.config.decide_mut_op_parallelism }}
##
# enforce parallelism of the diff generation (async IO)
generate_diff_parallelism: {{ .Values.main_app.config.generate_diff_parallelism }}
##
# timeout for the generate diff async IO (defaults to 5minute) -1 to disable
generate_diff_timeout: -1
##
# thread pool size for the generate diff async IO (defaults to 30)
wikibase_repo_thread_pool_size: 30
##
# output topic
output_topic: {{ .Values.main_app.config.output_topic }}
##
# output topic partition
output_topic_partition: 0
##
# idleness (ms) of input sources, default to 1minute
#
# - a value that is too low (< 1s) may incorrectly detect the stream as idle
# and might jump to higher watermarks issued from low rate streams and will end
# up marking as late events most events of this stream
#
# - a value that is too high (>?) may cause backfills to fail because too many
# events may be buffered in the window operation while idleness is reached.
# Later these events will likely be triggered at the same time causing too much
# backpressure and will cause the checkpoint to fail.
# (bug? some thread being blocked on
#  org.apache.flink.runtime.io.network.buffer.LocalBufferPool.requestMemorySegmentBlocking)
input_idleness: {{ .Values.main_app.config.input_idleness }}
##
# max lateness (ms): allowed out-of-orderness
# max_lateness: 60000
##
# checkpoint_interval (ms)
checkpoint_interval: {{ .Values.main_app.config.checkpoint_interval }}
##
# checkpoint timeouts
checkpoint_timeout: {{ .Values.main_app.config.checkpoint_timeout }}
##
# min pause (ms) between checkpoints, defaults to 2seconds
# min_pause_between_checkpoints: 2000
##
# watermark intervals (ms), defaults to 200millis
# auto_wm_interval: 200
##
# enable/disable exactly_once, defaults to true
# exactly_once: true
##
# enable flink latency tracking (defaults disabled), in millisec
# latency_tracking_interval: 1000
##
# tune network buffer timeout (ms)
# network_buffer_timeout: 100
{{- end -}}
