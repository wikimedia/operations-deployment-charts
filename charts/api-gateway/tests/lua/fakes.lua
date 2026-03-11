-- Shared fake handle helpers for Lua filter unit tests.
-- Load with: dofile(thisdir .. "fake_handles.lua")

function add_getters(obj, values)
    for k, v in pairs(values) do
        obj[k] = function () return v end
    end
    return obj
end

function fake_headers(values)
    local headers = { values = values }

    -- clone
    for k, v in pairs(values) do headers.values[k] = v end

    -- fake methods
    -- Note that add() is implemented like replace(). Good enough for now.
    headers.get     = function(self, k) return self.values[string.lower(k)] end
    headers.add     = function(self, k, v) self.values[string.lower(k)] = v end
    headers.replace = function(self, k, v) self.values[string.lower(k)] = v end
    headers.remove  = function(self, k) self.values[string.lower(k)] = nil end

    return headers
end

function fake_metadata(values)
    return {
        values = values,
        get = function(self, name) return self.values[name] end,
        set = function(self, name, k, v)
            if not self.values[name] then
                self.values[name] = {}
            end
            self.values[name][k] = v
        end,
    }
end

function fake_body(bytes)
    return {
        bytes = bytes,
        getBytes = function(self)
            return self.bytes
        end,
        setBytes = function(self, bytes)
            self.bytes = bytes
        end,
    }
end

function fake_stream_info(address, metadata, extra)
    return add_getters( {}, {
        downstreamRemoteAddress = address,
        dynamicMetadata = fake_metadata(metadata),
        responseCodeDetails = (extra and extra.responseCodeDetails) or "local_reply",
    })
end

function noop() end

function fake_request_handle(arg)
    local headers = arg.headers or { ["x-client-ip"] = "192.168.1.1" }
    headers[":method"] = headers[":method"] or "GET"
    headers[":path"]   = headers[":path"]   or "/"

    return add_getters( {
        logDebug   = noop,
        logInfo    = noop,
        logWarning = noop,
    }, {
        headers    = fake_headers(headers),
        streamInfo = fake_stream_info(arg.address or "127.0.0.1", arg.streamMetadata or {}),
        metadata   = fake_metadata(arg.routeMetadata or {}),
    })
end

function fake_response_handle(arg)
    local headers = arg.headers or { ["content-type"] = "unknown/unknown" }
    headers[":status"] = headers[":status"] or "200"

    return add_getters( {
        logDebug   = noop,
        logInfo    = noop,
        logWarning = noop,
    }, {
        headers    = fake_headers(headers),
        streamInfo = fake_stream_info(arg.address or "127.0.0.1",
                arg.streamMetadata or {},
                { responseCodeDetails = arg.responseCodeDetails }),
        metadata   = fake_metadata(arg.routeMetadata or {}),
        body       = fake_body("Lorem ipsum"),
    })
end
