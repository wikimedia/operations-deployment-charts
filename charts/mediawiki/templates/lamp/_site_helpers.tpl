{{/* Generate the file name for an httpd virtualhost.
     Puppet generates /etc/helmfile-defaults/mediawiki/httpd.yaml in
     deployment hosts, which is in term consumed by this template to
     generate apache vhost configuration files like 05-search-wikimedia.conf
*/}}
{{- define "mw-vhost-filename" -}}{{ printf "%02d-%s" (.priority | int) .name }}.conf{{- end -}}
{{- define "mw-vhost" }}  ## add a default if no priority
# VirtualHost for {{ .name }}
<VirtualHost *:{{ .port }}>
    ServerName {{ .name }}
    DocumentRoot {{ .docroot }}

    {{- if .server_aliases }}
    {{- range .server_aliases }}
    ServerAlias {{ . }}
    {{ end }}
    UseCanonicalName {{ .canonical_name }}
    {{ end }}

    AllowEncodedSlashes {{ .encoded_slashes }}

    RewriteEngine On
{{- if .https_only }}
    RewriteCond %{HTTP:X-Forwarded-Proto} !https
    RewriteRule ^/(.*)$ https://%{SERVER_NAME}/$1 [R=301,L,NE]
    RewriteRule . - [E=RW_PROTO:%{HTTP:X-Forwarded-Proto}]
{{- else }}
    RewriteRule . - [E=RW_PROTO:%{HTTP:X-Forwarded-Proto}]
    RewriteCond %{ENV:RW_PROTO} !=https
    RewriteRule . - [E=RW_PROTO:http]
{{- end -}}

{{- with .upload_rewrite }}
{{- if .domain_catchall }}
    # Uploads to the host-specific directory
    RewriteCond %{HTTP_HOST} ([a-z\-]+)\.{{ .domain_catchall | replace "." "\\." }}
    RewriteRule ^/upload/(.*)$ %{ENV:RW_PROTO}://upload.wikimedia.org/{{ .rewrite_prefix }}/%1/$1 [R=302]
{{- else }}
    # Uploads are offsite
    RewriteRule ^/upload/(.*)$ %{ENV:RW_PROTO}://upload.wikimedia.org/{{ .rewrite_prefix }}/$1 [R=302]
{{- end }}
{{- end }}
    # Custom rewrite rules (early)
    {{ .additional_rewrites.early | join "\n" }}

    ### Common rewrite rules for all wikis

    # Redirect /wiki, /w to the fcgi backend
    RewriteRule     ^/w/wiki.phtml$      /w/index.php [L,QSA,NE]

    # Primary wiki redirector:
    RewriteRule ^/wiki /w/index.php [L]
{{- if .public_rewrites }}
    # Make robots.txt editable via MediaWiki:robots.txt
    RewriteRule ^/robots\.txt$ /w/robots.php [L]
    # Primary wiki redirector:
    RewriteRule ^/$ /w/index.php
    # Configurable favicon
    RewriteRule ^/favicon\.ico$ /w/favicon.php [L]
    # Configurable apple-touch-icon.png
    RewriteRule ^/apple-touch-icon\.png$ /w/touch.php [L]
{{- end }}

    # Multiversion static files (T99096)
    RewriteRule ^/w/skins/.*$ /w/static.php [PT]
    RewriteRule ^/w/resources/.*$ /w/static.php [PT]
    RewriteRule ^/w/extensions/.*$ /w/static.php [PT]

    # Common API-related rewrites
    # API listing
    RewriteRule ^/api$ %{ENV:RW_PROTO}://%{SERVER_NAME}/api/ [R=301]
    RewriteRule ^/api/$ /w/extract2.php?template=API_listing_template [L]

    # Math compatibility mode
    RewriteCond %{ENV:RW_PROTO} !=""
    RewriteRule ^/math/(.*) %{ENV:RW_PROTO}://upload.wikimedia.{{ .domain_suffix }}/math/$1 [R=301]
    RewriteRule ^/math/(.*) https://upload.wikimedia.{{ .domain_suffix }}/math/$1 [R=301]

{{- if .short_urls }}
    # ShortUrl support, for wikis where it's enabled
    RewriteRule ^/s/.*$     /w/index.php
{{- end }}
{{- if .legacy_rewrites }}
    # UseMod compatibility URLs
    RewriteCond %{QUERY_STRING} ([^&;]+)
    RewriteRule ^/wiki\.cgi$ %{ENV:RW_PROTO}://%{SERVER_NAME}/w/index.php?title=%1 [R=301,L]
    RewriteRule ^/wiki\.cgi$ %{ENV:RW_PROTO}://%{SERVER_NAME}/w/index.php [R=301,L]
    # Early phase 2 compatibility URLs
    RewriteRule ^/wiki\.phtml$ %{ENV:RW_PROTO}://%{SERVER_NAME}/w/index.php [R=301,L]
{{- end }}
    # Custom rewrite rules (late)
    {{ .additional_rewrites.late | join "\n" }}

{{ range .variant_aliases }}
    RewriteRule ^/{{ . }} /w/index.php [L]
{{- end }}
    # Forbid accessing files under /w/extensions
    RewriteRule ^/w/extensions/.*\.php - [F,L]
    <FilesMatch "\.php$">
        SetHandler "proxy:{{ .fcgi_endpoint }}"
    </FilesMatch>

    RewriteRule ^/\.well-known/change-password$ /wiki/Special:ChangeCredentials/MediaWiki\\Auth\\PasswordAuthenticationRequest [R=302]
</VirtualHost>
{{ end }}{{/* end vhost */}}


{{/* All files that go in the $releasename-httpd-sites map */}}
{{ define "mw.web-sites" }}
{{- $port := .Values.php.httpd.port -}}
{{- $domain_suffix := .Values.mw.domain_suffix -}}
{{- $fcgi_endpoint := ternary "unix:/run/shared/fpm-www.sock|fcgi://localhost" "fcgi://127.0.0.1:9000" (eq .Values.php.fcgi_mode "FCGI_UNIX") }}
{{/* TODO: unify the dicts once we have multiline pipelines with go 1.16, see https://github.com/golang/go/issues/29770  */}}
{{- $base_params := dict "port" $port "domain_suffix" $domain_suffix "fcgi_endpoint" $fcgi_endpoint }}
{{- $tpl_defaults := dict "public_rewrites" true "legacy_rewrites" true "short_urls" false "https_only" false "encoded_slashes" "On" "canonical_name" "Off" }}
{{- range .Values.mw.sites }}
  {{ template "mw-vhost-filename" . }}: |
  {{- if .content }}
{{ .content | indent 4 }}
  {{- else }}
    {{- $defaults := .defaults -}}
    {{- range $v := .vhosts -}}
        {{- $params := merge $v $defaults $base_params $tpl_defaults -}}
        {{- include "mw-vhost" $params | indent 4 -}}
    {{- end }}
  {{- end -}}
{{ end }}
{{ end }}
