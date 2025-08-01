{{- define "thumbor_server.config" }}

# 20-debian.conf
FILE_STORAGE_ROOT_PATH = '/var/cache/thumbor/storage'
# 30-community-core.conf - overridden later in this file
#APP_CLASS='tc_core.app.App'

# 40-wikimedia.conf
EXIFTOOL_PATH = '/usr/bin/exiftool'
SUBPROCESS_TIMEOUT_PATH = '/usr/bin/timeout'
RSVG_CONVERT_PATH = '/usr/bin/rsvg-convert'
FFPROBE_PATH = '/usr/bin/ffprobe'
DDJVU_PATH = '/usr/bin/ddjvu'
GHOSTSCRIPT_PATH = '/usr/bin/gs'
VIPS_PATH = '/usr/bin/vips'
CONVERT_PATH = '/usr/bin/convert'
XVFB_RUN_PATH = '/usr/bin/xvfb-run'
CWEBP_PATH = '/usr/bin/cwebp'
JPEGTRAN_PATH = '/usr/bin/jpegtran'
FFMPEG_PATH = '/usr/bin/ffmpeg'


## Host to send statsd instrumentation to
## Defaults to: None
STATSD_HOST = '{{ .Values.statsd.host }}'

## Port to send statsd instrumentation to
## Defaults to: None
STATSD_PORT = {{ .Values.statsd.port }}

## Prefix for statsd
## Defaults to: None
STATSD_PREFIX = '{{ .Values.statsd.name }}'

## Quality index used for generated JPEG images
## Defaults to: 80
QUALITY = 87

## Exports JPEG images with the `progressive` flag set.
## Defaults to: True
PROGRESSIVE_JPEG = False

## Max AGE sent as a header for the image served by thumbor in seconds
## Defaults to: 86400
MAX_AGE = None

## Indicates whether thumbor should rotate images that have an Orientation EXIF
## header
## Defaults to: False
RESPECT_ORIENTATION = True

## Preserves exif information in generated images. Increases image size in
## kbytes, use with caution.
## Defaults to: False
PRESERVE_EXIF_INFO = True

## The metrics backend thumbor should use to measure internal actions. This must
## be the full name of a python module (python must be able to import it)
## Defaults to: thumbor.metrics.logger_metrics
METRICS = 'thumbor.metrics.statsd_metrics'

## The loader thumbor should use to load the original image. This must be the
## full name of a python module (python must be able to import it)
## Defaults to: thumbor.loaders.http_loader
LOADER = 'wikimedia_thumbor.loader.proxy'

## The file storage thumbor should use to store original images. This must be the
## full name of a python module (python must be able to import it)
## Defaults to: thumbor.storages.file_storage
STORAGE = 'thumbor.storages.no_storage'

## The imaging engine thumbor should use to perform image operations. This must
## be the full name of a python module (python must be able to import it)
## Defaults to: thumbor.engines.pil
ENGINE = 'wikimedia_thumbor.engine.proxy'

## Indicates if the /unsafe URL should be available
## Defaults to: True
ALLOW_UNSAFE_URL = False

## The filename of CA certificates in PEM format
## Defaults to: None
HTTP_LOADER_CA_CERTS = '/etc/ssl/certs/wmf-ca-certificates.crt'

## The maximum number of seconds libcurl can take to download an image
## Defaults to: 20
HTTP_LOADER_REQUEST_TIMEOUT = 300

## Max size in Kb for images uploaded to thumbor
## Aliases: MAX_SIZE
## Defaults to: 0
UPLOAD_MAX_SIZE = 1048576 # 1GB

## List of filters that thumbor will allow to be used in generated images. All of
## them must be full names of python modules (python must be able to import
## it)
## Defaults to: ['thumbor.filters.brightness', 'thumbor.filters.colorize', 'thumbor.filters.contrast', 'thumbor.filters.rgb', 'thumbor.filters.round_corner', 'thumbor.filters.quality', 'thumbor.filters.noise', 'thumbor.filters.watermark', 'thumbor.filters.equalize', 'thumbor.filters.fill', 'thumbor.filters.sharpen', 'thumbor.filters.strip_icc', 'thumbor.filters.frame', 'thumbor.filters.grayscale', 'thumbor.filters.rotate', 'thumbor.filters.format', 'thumbor.filters.max_bytes', 'thumbor.filters.convolution', 'thumbor.filters.blur', 'thumbor.filters.extract_focal', 'thumbor.filters.no_upscale', 'thumbor.filters.saturation', 'thumbor.filters.max_age', 'thumbor.filters.curve']
FILTERS = [
    'wikimedia_thumbor.filter.conditional_sharpen',
    'wikimedia_thumbor.filter.lang',
    'wikimedia_thumbor.filter.page',
    'thumbor.filters.format',
    'thumbor.filters.quality'
]


################################### Wikimedia ##################################

EXIF_FIELDS_TO_KEEP = [ 'Artist', 'Copyright', 'ImageDescription' ]
EXIF_TINYRGB_PATH = '/srv/service/tinyrgb.icc'
EXIF_TINYRGB_ICC_REPLACE = 'sRGB IEC61966-2.1'

PROXY_ENGINE_ENGINES = [
    ('wikimedia_thumbor.engine.svg', ['svg']),
{{- if .Values.main_app.stl_support }}
    ('wikimedia_thumbor.engine.stl', ['stl']),
{{- end }}
    ('wikimedia_thumbor.engine.djvu', ['djvu']),
    ('wikimedia_thumbor.engine.vips', ['tiff', 'png']),
    ('wikimedia_thumbor.engine.tiff', ['tiff']),
    ('wikimedia_thumbor.engine.ghostscript', ['pdf']),
    ('wikimedia_thumbor.engine.gif', ['gif']),
    ('wikimedia_thumbor.engine.imagemagick', ['jpg', 'png', 'webp', 'xcf']),
]

HTTP_LOADER_MAX_BODY_SIZE = 4*1024*1024*1024  # 4GB

PROXY_LOADER_LOADERS = [
    'wikimedia_thumbor.loader.video',
    'wikimedia_thumbor.loader.swift'
]

COMMUNITY_EXTENSIONS = [
    'wikimedia_thumbor.handler.images',
    'wikimedia_thumbor.handler.core',
    'wikimedia_thumbor.handler.healthcheck'
]

SLOW_PROCESSING_LIMIT = 30000

SUBPROCESS_USE_TIMEOUT = {{ .Values.main_app.subprocess_timeout.enabled }}
# The Varnish slow log currently uses 60s as its threshold. This helps
# avoiding hitting the slow log for expected subprocess timeout situations.
SUBPROCESS_TIMEOUT = {{ .Values.main_app.subprocess_timeout.timeout }}
# Send a SIGKILL if the command is running after SIGTERM has been sent.
# 0 disables this
SUBPROCESS_TIMEOUT_KILL_AFTER = {{ .Values.main_app.subprocess_timeout.kill_after }}

VIPS_ENGINE_MIN_PIXELS = 10000000

CHROMA_SUBSAMPLING = '4:2:0'
QUALITY_LOW = 40
DEFAULT_FILTERS_JPEG = 'conditional_sharpen(0.0,0.8,1.0,0.0,0.85)'

LOADER_EXCERPT_LENGTH = 4096

# 2 minutes, for situations where an engine failed to clean up after itself
HTTP_LOADER_TEMP_FILE_TIMEOUT = 120

MANHOLE_DEBUGGING = True

# Overrides the community core class in order to install manhole
APP_CLASS = 'wikimedia_thumbor.app.App'

# PoolCounter configuration

{{ if .Values.main_app.poolcounter.enabled }}
POOLCOUNTER_SERVER = '{{ .Values.main_app.poolcounter.server }}'
POOLCOUNTER_PORT = 7531
POOLCOUNTER_RELEASE_TIMEOUT = {{ .Values.main_app.poolcounter.release_timeout | default 120 }}
{{ end }}

# Up to "workers" thumbnails can be generated at once for a given IP
# address, with up to "maxqueue" thumbnails queued per IP
POOLCOUNTER_CONFIG_PER_IP = {
    'workers': 4,
    'maxqueue': 50,
    'timeout': 4
}

# Up to "workers" thumbnails can be generated at once for the same original
# with up to a "maxqueue" other thumbnail requests for that original queued
# T203135 Concurrency should be at least the same as the MediaWiki ThumbnailRenderJob
POOLCOUNTER_CONFIG_PER_ORIGINAL = {
    'workers': 6,
    'maxqueue': 100,
    'timeout': 8
}

{{ if .Values.main_app.poolcounter.config.expensive }}
# An absolute maximum of "workers" expensive thumbnails can be processed at the same time,
# queueing up to "maxqueue" other expensive thumbnails
POOLCOUNTER_CONFIG_EXPENSIVE = {
    'workers': {{ .Values.main_app.poolcounter.config.expensive.workers }},
    'maxqueue': {{ .Values.main_app.poolcounter.config.expensive.maxqueue }},
    'timeout': {{ .Values.main_app.poolcounter.config.expensive.timeout }},
    'extensions': ['xcf', 'djvu', 'pdf', 'tiff', 'stl']
}
{{ end }}

# Thumbnails that fail for a given xkey more than 4 times per hour aren't
# worth re-attempting that often
FAILURE_THROTTLING_MEMCACHE = ['{{ .Values.main_app.failure_throttling_memcache }}']
FAILURE_THROTTLING_MAX = 4
FAILURE_THROTTLING_DURATION = 3600
FAILURE_THROTTLING_PREFIX = 'thumbor-failure-'

{{ if .Values.main_app.stl_support -}}
THREED2PNG_PATH = '/opt/lib/venv/bin/3d2png'
{{- end -}}

# Animated GIFs greater than 100MP render as the first frame only
MAX_ANIMATED_GIF_AREA = 100000000


################################### Logging ##################################

## This configuration indicates whether thumbor should use a custom error
## handler.
## Defaults to: False
USE_CUSTOM_ERROR_HANDLING = True

## Error reporting module. Needs to contain a class called ErrorHandler with a
## handle_error(context, handler, exception) method.
## Defaults to: thumbor.error_handlers.sentry
ERROR_HANDLER_MODULE = 'wikimedia_thumbor.error_handlers.logstash'

from wikimedia_thumbor.logging.filter.context import ContextFilter
from wikimedia_thumbor.logging.filter.http404 import Http404Filter
from wikimedia_thumbor.logging.filter.error import ErrorFilter

THUMBOR_LOG_CONFIG = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'default': {
            'format': '%(asctime)s %(port)s %(name)s:%(levelname)s %(message)s'
        }
    },
    'filters': {
        'context': {
            '()': ContextFilter,
            'flag': 'log'
        },
        '404only': {
            '()': Http404Filter,
            'flag': 'only'
        },
        '404exclude': {
            '()': Http404Filter,
            'flag': 'exclude'
        },
        'error': {
            '()': ErrorFilter,
        }
    },
    'handlers': {
        'logstream': {
            'level': '{{ .Values.main_app.log_level | upper }}',
            'class': 'logging.StreamHandler',
            'formatter': 'default',
            {{- if not .Values.main_app.log_404 }}
            'filters': ['context', '404exclude', 'error' ]
            {{- else }}
            'filters': ['context', 'error' ]
            {{- end }}
        }
    },
    'loggers': {
        '': {
            'level': 'DEBUG',
            'handlers': ['logstream']
        }
    }
}
{{ end }}
