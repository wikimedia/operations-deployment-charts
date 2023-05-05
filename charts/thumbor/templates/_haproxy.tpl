{{ define "haproxy.config" }}
listen thumbor
    mode http
    bind *:{{ .Values.haproxy.port }}
    option httplog
    log stdout local0 info

    # Short because if Haproxy attempts to connect, the Thumbor instance it tries must be
    # free (no other connection, because maxconn is 1)
    timeout connect 1000ms

    # Thumbor times out when processing of a given request takes 60s. Since we have certainty
    # of only one request at a time being handled by a Thumbor instance, thanks to maxconn, we don't
    # need that timeout to be much larger
    timeout server {{ .Values.haproxy.timeout_server }}ms

    # The server can take a while to respond (up to "timeout server" * 2 for the retry + "timeout queue")
    timeout client {{ add (mul .Values.haproxy.timeout_server 2) .Values.haproxy.timeout_queue  }}ms

    # When a request is queued because all Thumbor instances are busy, we want to wait for an
    # opportunity to run. Given that requests are a mix of short and long ones, it shouldn't be
    # necessary to wait very long to get off the queue. If it does, then Thumbor is truly overloaded
    # and we're better off 503ing.
    timeout queue {{ .Values.haproxy.timeout_queue }}ms

    # Use first available Thumbor instance for next request
    balance first
    # Retry once on a different Thumbor instance in case of connection timeout or failure
    retries 1
    option redispatch 1

    # Add a healthz for haproxy itself - checking /healthcheck will
    # actually hit thumbor which will give us an erroneous fail where we
    # could be queuing requests in haproxy.
    acl queue_too_big avg_queue() gt {{ .Values.haproxy.max_avg_queue }}
    monitor-uri /healthz
    monitor fail if queue_too_big

    # Deny /metrics scrapers to thumbor instances - these are
    #  connections that might make an instance seem busy when it
    #  isn't. Instances will be reporting their metrics to the statsd
    #  gateway anyway.
    acl is_metrics path /metrics
    http-request deny deny_status 400 if is_metrics

    # Send X-Forwarded-For header to Thumbor instance
    option forwardfor

    # Send a unique request id to Thumbor instance
    unique-id-format %{+X}o\ %ci:%cp_%fi:%fp_%Ts_%rt:%pid
    unique-id-header Thumbor-Request-Id

    http-request set-header Proxy-Request-Date %Tl
    http-request set-header X-Client-IP %[src]
    http-response set-header Proxy-Response-Date %Tl
    http-response set-header X-Upstream %si:%sp
    http-response set-header Thumbor-Request-Id %[unique-id]

    # Maxconn 1 ensures that each Thumbor instance only handles one request at a time
    # which is deliberate since Thumbor is single-threaded
    # Consider a thumbor worker healthy after one successful connection rather than 2
    # Check thumbor workers every 1 second rather than 2 seconds.
    {{ range $thumbor_worker := ( int .Values.main_app.thumbor_workers | until) -}}
    {{ $thumbor_port := (add 8080 $thumbor_worker) -}}
    server server{{$thumbor_port}} 127.0.0.1:{{$thumbor_port}} maxconn 1 check inter 1s raise 1
    {{ end -}}

listen stats
   bind *:{{ .Values.haproxy.stats_port }}
   mode http

   # These are somewhat arbitrary given how quickly stats backends
   # respond, required to make haproxy logging happy.
   timeout server 5000ms
   timeout connect 2000ms
   timeout client 5000ms

   http-request use-service prometheus-exporter if { path /metrics }
   stats enable
   stats uri /metrics
   stats refresh 10s
{{ end }}
