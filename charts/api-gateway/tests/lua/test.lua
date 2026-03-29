-- Tests for the Lua filters
-- File under test:
local thisdir = debug.getinfo(1).source:match("@?(.*/)") or "."

-- Load code under test.
local codeFile = thisdir .. "/../../lua/restgateway.lua"
local codeFunc = loadfile( codeFile )

if not codeFunc then
    print( "Code under test is invalid:" )
    os.execute( "lua " .. codeFile )
    os.exit(3)
end

_G.HelmValues = {
    main_app = {
        ratelimiter = {
            fallback_class = "anon",
            browser_threshold = 80,
            ratelimit_notice_text = "ratelimit notice text",
            anon_class_by_address = {
                 ["11.22.33."] = "special-network",
            },
            default_policies = {
                "DefaultPolicy1",
                "DefaultPolicy2",
                "DefaultPolicy3",
            },
            exposed_headers = {
                "x-wmf-user-id",
                "x-wmf-ratelimit-class",
            },
        }
    }
}

-- Run the code under test to define functions to test.
codeFunc()

-- Recursive dump for debugging, don't delete if unused.
-- Based on https://github.com/ToxicFrog/luautil/blob/master/table.lua
-- by Ben "ToxicFrog" Kelly (MIT license).
function var_str(T)
    if not type(v) == 'table' then
        return "" .. v
    end

    local buf = {}
    local done = {}
    local function tstr(T, prefix)
        for k,v in pairs(T) do
            table.insert(buf, prefix..tostring(k)..'\t=\t'..tostring(v))
            if type(v) == 'table' then
                if not done[v] then
                    done[v] = true
                    tstr(v, prefix.."  ")
                end
            end
        end
    end
    done[T] = true
    tstr(T, "")
    return string.gsub( table.concat(buf, "\n"), "^%s*(.-)%s*$", "%1")
end

-- This uses the Busted test framework, see https://lunarmodules.github.io/busted/.
-- The structure is similar to Mocha tests.
-- Installation: luarocks install busted

describe("rest_hooks", function()
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
        headers.get = function(self, k) return self.values[string.lower(k)] end
        headers.add = function(self, k, v) self.values[string.lower(k)] = v end
        headers.replace = function(self, k, v) self.values[string.lower(k)] = v end
        headers.remove = function(self, k) self.values[string.lower(k)] = nil end

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
            end
        }
    end

    function fake_stream_info(address, metadata, extra)
        return add_getters( {},{
            downstreamRemoteAddress = address,
            dynamicMetadata = fake_metadata(metadata),
            responseCodeDetails = (extra and extra.responseCodeDetails) or "local_reply",
        })
    end

    function noop() end

    function fake_request_handle(arg)
        local headers = arg.headers or { ["x-client-ip"] = "192.168.1.1" }
        headers[":method"] = headers[":method"] or "GET"
        headers[":path"] = headers[":path"] or "/"

        return add_getters( {
            logDebug = noop,
            logInfo = noop,
            logWarning = noop,
        },{
            headers = fake_headers(headers),
            streamInfo = fake_stream_info(arg.address or "127.0.0.1",
                    arg.streamMetadata or {}),
            metadata = fake_metadata(arg.routeMetadata or {}),
        })
    end

    function fake_response_handle(arg)
        local headers = arg.headers or { ["content-type"] = "unknown/unknown" }
        headers[":status"] = headers[":status"] or "200"

        return add_getters( {
            logDebug = noop,
            logInfo = noop,
            logWarning = noop,
        },{
            headers = fake_headers(headers),
            streamInfo = fake_stream_info(arg.address or "127.0.0.1",
                    arg.streamMetadata or {},
                    { responseCodeDetails = arg.responseCodeDetails }),
            metadata = fake_metadata(arg.routeMetadata or {}),
            body = fake_body("Lorem ipsum"),
        })
    end

    describe("wmf_ratelimit_info", function()
        describe("policy handling", function()
            it("should set x-wmf-ratelimit-policy based on route metadata", function()
                local headers = {
                    ["x-client-ip"] = "1.2.3.4",
                    ["x-wmf-ratelimit-policy-1"] = "xyzzy1",
                    ["x-wmf-ratelimit-policy-2"] = "xyzzy2",
                    ["x-wmf-ratelimit-policy-3"] = "xyzzy3",
                }
                local routeMeta = { ["wmf_ratelimit"] = { ["policies"] = { "one", "two" } } }
                local req = fake_request_handle( { routeMetadata = routeMeta, headers = headers } )

                wmf_ratelimit_info(req)

                local result = req:headers()
                assert.are.equal( "one", result:get("x-wmf-ratelimit-policy-1") )
                assert.are.equal( "two", result:get("x-wmf-ratelimit-policy-2") )
                assert.is_nil( result:get("x-wmf-ratelimit-policy-3") )
            end)
            it("should not set x-wmf-ratelimit-policy for BYPASS policy", function()
                local headers = {
                    ["x-client-ip"] = "1.2.3.4",
                }
                local routeMeta = { ["wmf_ratelimit"] = {
                    ["policies"] = { "BYPASS", "some-limits" } -- "BYPASS" is magical
                } }
                local req = fake_request_handle( { routeMetadata = routeMeta, headers = headers } )

                wmf_ratelimit_info(req)

                local result = req:headers()
                assert.is_nil( result:get("x-wmf-ratelimit-policy-1") )
                assert.are.equal( "some-limits", result:get("x-wmf-ratelimit-policy-2") )
            end)
            it("should unset x-wmf-ratelimit-policy based on route metadata", function()
                local headers = {
                    ["x-client-ip"] = "1.2.3.4",
                    ["x-wmf-ratelimit-policy-1"] = "xyzzy1",
                    ["x-wmf-ratelimit-policy-2"] = "xyzzy2",
                    ["x-wmf-ratelimit-policy-3"] = "xyzzy3",
                }
                local routeMeta = { ["wmf_ratelimit"] = { ["policies"] = {} } }
                local req = fake_request_handle( { routeMetadata = routeMeta, headers = headers } )

                wmf_ratelimit_info(req)

                local result = req:headers()
                assert.is_nil( result:get("x-wmf-ratelimit-policy-1") )
                assert.is_nil( result:get("x-wmf-ratelimit-policy-2") )
                assert.is_nil( result:get("x-wmf-ratelimit-policy-3") )
            end)
        end)
        describe("address handling", function()
            it("should bypass rate limiting if x-client-ip is not set", function()
                local headers = {} -- suppress default headers
                local req = fake_request_handle( { headers = headers } )
                wmf_ratelimit_info(req)

                local result = req:headers()

                assert.are.equal( nil, result:get("x-wmf-user-id") )
                assert.are.equal( nil, result:get("x-wmf-ratelimit-class") )
            end)
            it("should use the x-client-ip as the user ID, and assign the fallback class", function()
                local headers = { ["x-client-ip"] = "203.0.113.222" }
                local req = fake_request_handle( { headers = headers } )
                wmf_ratelimit_info(req)

                local result = req:headers()
                assert.are.equal( "x-client-ip:203.0.113.222", result:get("x-wmf-user-id") )
                assert.are.equal( "anon", result:get("x-wmf-ratelimit-class") )
                assert.is_nil( result:get("x-wmf-ratelimit-policy-1") )
            end)
            it("should assign a class based on anon_class_by_address", function()
                local headers = { ["x-client-ip"] = "11.22.33.44" }
                local req = fake_request_handle( { headers = headers } )
                wmf_ratelimit_info(req)

                local result = req:headers()
                assert.are.equal( "x-client-ip:11.22.33.44", result:get("x-wmf-user-id") )
                assert.are.equal( "special-network", result:get("x-wmf-ratelimit-class") )
            end)
        end)
        describe("x-wmf header handling", function()
            it("should ignore x-wmf-user-id header if x-client-ip is set", function()
                local routeMeta = { ["wmf_ratelimit"] = { ["policies"] = { "just-a-test" } } }
                local headers = {
                    ["x-wmf-user-id"] = "Cindy",
                    ["x-client-ip"] = "192.168.1.1"
                }
                local req = fake_request_handle( { routeMetadata = routeMeta, headers = headers } )
                wmf_ratelimit_info(req)

                local result = req:headers()
                assert.are_not.equal( "Cindy", result:get("x-wmf-user-id") )
            end)
            it("should ignore the x-wmf-ratelimit-class header if x-client-ip is set", function()
                local routeMeta = { ["wmf_ratelimit"] = { ["policies"] = { "just-a-test" } } }
                local headers = {
                    ["x-wmf-ratelimit-class"] = "SpecialClass",
                    ["x-client-ip"] = "192.168.1.1",
                }
                local req = fake_request_handle( { routeMetadata = routeMeta, headers = headers } )
                wmf_ratelimit_info(req)

                local result = req:headers()
                assert.are_not.equal( "SpecialClass", result:get("x-wmf-ratelimit-class") )
            end)
            it("should use the x-wmf-xxx headers if given", function()
                local routeMeta = { ["wmf_ratelimit"] = { ["policies"] = { "just-a-test" } } }
                local headers = {
                    ["x-wmf-user-id"] = "Cindy",
                    ["x-wmf-ratelimit-class"] = "CindysClass",
                    ["x-wmf-ratelimit-policy-1"] = "TestPolicy",
                    -- do not set "x-client-ip", so the request is treated as internal
                }
                local req = fake_request_handle( { routeMetadata = routeMeta, headers = headers } )
                wmf_ratelimit_info(req)

                local result = req:headers()
                assert.are.equal( "Cindy", result:get("x-wmf-user-id") )
                assert.are.equal( "CindysClass", result:get("x-wmf-ratelimit-class") )
                assert.are.equal( "TestPolicy", result:get("x-wmf-ratelimit-policy-1") )
            end)
        end)

        describe("x-trusted-request handling", function()
            it("should use the user-agent header for trust level A", function()
                local headers = {
                    ["x-trusted-request"] = "A",
                    ["x-is-browser"] = "100", -- should be ignored
                    ["user-agent"] = "CindyBot 2.0 (User:Cindy)",
                    ["x-provenance"] = "client=cindy",
                    ["x-client-ip"] = "203.0.113.222", -- set x-client-ip to mark the request as external
                }
                local req = fake_request_handle( { headers = headers } )
                wmf_ratelimit_info(req)

                local result = req:headers()
                assert.are.equal( "user-agent:CindyBot 2.0 (User:Cindy)", result:get("x-wmf-user-id") )
                assert.are.equal( "known-network", result:get("x-wmf-ratelimit-class") )
            end)
            it("should use the x-provenance header for trust level B", function()
                local headers = {
                    ["x-trusted-request"] = "B",
                    ["x-is-browser"] = "100", -- should be ignored
                    ["user-agent"] = "CindyBot 2.0 (User:Cindy)",
                    ["x-provenance"] = "client=cindy",
                    ["x-client-ip"] = "203.0.113.222", -- set x-client-ip to mark the request as external
                }
                local req = fake_request_handle( { headers = headers } )
                wmf_ratelimit_info(req)

                local result = req:headers()
                assert.are.equal( "x-provenance:client=cindy", result:get("x-wmf-user-id") )
                assert.are.equal( "known-client", result:get("x-wmf-ratelimit-class") )
            end)
            it("should recognize bots based on trust level D", function()
                local headers = {
                    ["x-trusted-request"] = "D",
                    ["x-is-browser"] = "100", -- should be ignored
                    ["x-ua-contact"] = "User:Cindy", -- used as key (for now)
                    ["x-client-ip"] = "203.0.113.222", -- set x-client-ip to mark the request as external
                }
                local req = fake_request_handle( { headers = headers } )
                wmf_ratelimit_info(req)

                local result = req:headers()
                -- NOTE: Using the user-agent is unsafe but useful for visibility. Go back to IP later.
                assert.are.equal( "x-ua-contact:User:Cindy", result:get("x-wmf-user-id") )
                assert.are.equal( "unauthed-bot", result:get("x-wmf-ratelimit-class") )
            end)
            it("should treat trust level C as unauthed-bot if there is no valid token", function()
                local headers = {
                    ["x-trusted-request"] = "C",
                    ["x-is-browser"] = "100", -- should be ignored
                    ["x-ua-contact"] = "User:Cindy", -- used as key (for now)
                    ["x-client-ip"] = "203.0.113.222", -- set x-client-ip to mark the request as external
                }
                local req = fake_request_handle( { headers = headers } )
                wmf_ratelimit_info(req)

                local result = req:headers()
                -- NOTE: Using the user-agent is unsafe but useful for visibility. Go back to IP later.
                assert.are.equal( "x-ua-contact:User:Cindy", result:get("x-wmf-user-id") )
                assert.are.equal( "unauthed-bot", result:get("x-wmf-ratelimit-class") )
            end)
            it("should use the x-is-browser header to recognize organic traffic", function()
                local headers = {
                    ["x-trusted-request"] = "E",
                    ["x-is-browser"] = "100", -- above browser_threshold = 80
                    ["x-client-ip"] = "192.168.1.1",
                }
                local req = fake_request_handle( { headers = headers } )
                wmf_ratelimit_info(req)

                local result = req:headers()
                assert.are.equal( "x-client-ip:192.168.1.1", result:get("x-wmf-user-id") )
                assert.are.equal( "anon-browser", result:get("x-wmf-ratelimit-class") )
            end)
            it("should ignore the x-is-browser header if the value is too small", function()
                local headers = {
                    ["x-trusted-request"] = "E",
                    ["x-is-browser"] = "15", -- below browser_threshold = 80
                    ["x-client-ip"] = "192.168.1.1",
                }
                local req = fake_request_handle( { headers = headers } )
                wmf_ratelimit_info(req)

                local result = req:headers()
                assert.are.equal( "x-client-ip:192.168.1.1", result:get("x-wmf-user-id") )

                -- should not be "anon-browser", since the score was too low
                assert.are.equal( "anon", result:get("x-wmf-ratelimit-class") )
            end)
            it("should recognize trust level F", function()
                local headers = {
                    ["x-trusted-request"] = "F",
                    ["x-client-ip"] = "203.0.113.222",
                }
                local req = fake_request_handle( { headers = headers } )
                wmf_ratelimit_info(req)

                local result = req:headers()
                assert.are.equal( "x-client-ip:203.0.113.222", result:get("x-wmf-user-id") )
                assert.are.equal( "anon", result:get("x-wmf-ratelimit-class") )
            end)
        end)
        describe("MediaWiki client handling", function()
            it("should recognize MediaWiki with trust-level D", function()
                local headers = {
                    ["user-agent"] = "MediaWiki/1.43.1 (https://some.fandom.com) ForeignAPIRepo/2.1",
                    ["x-trusted-request"] = "D", -- should be ignored
                    ["x-is-browser"] = "100", -- should be ignored
                    ["x-ua-contact"] = "https://some.fandom.com", -- used as key (for now)
                    ["x-client-ip"] = "203.0.113.222", -- set x-client-ip to mark the request as external
                }
                local req = fake_request_handle( { headers = headers } )
                wmf_ratelimit_info(req)

                local result = req:headers()
                assert.are.equal( "x-ua-contact:https://some.fandom.com", result:get("x-wmf-user-id") )
                assert.are.equal( "unauthed-mediawiki", result:get("x-wmf-ratelimit-class") )
            end)
            it("should recognize QuickInstantCommons with trust-level E", function()
                local headers = {
                    ["user-agent"] = "QuickInstantCommons/1.5 MediaWiki/1.39.5; Something",
                    ["x-trusted-request"] = "E", -- should be ignored
                    ["x-is-browser"] = "100", -- should be ignored
                    ["x-client-ip"] = "203.0.113.222", -- should be used as key
                }
                local req = fake_request_handle( { headers = headers } )
                wmf_ratelimit_info(req)

                local result = req:headers()
                assert.are.equal( "x-client-ip:203.0.113.222", result:get("x-wmf-user-id") )
                assert.are.equal( "unauthed-mediawiki", result:get("x-wmf-ratelimit-class") )
            end)
        end)
        describe("jwt_payload handling", function()
            it("should use the sub claim if present", function()
                -- The JWT payload is stored in stream metadata
                local payload = {
                    sub = "12345"
                }
                local meta = { ["envoy.filters.http.jwt_authn"] = { ["jwt_payload"] = payload } }
                local req = fake_request_handle( { streamMetadata = meta } )
                wmf_ratelimit_info(req)

                local result = req:headers()
                assert.are.equal( "bearer-sub:12345", result:get("x-wmf-user-id") )
                assert.are.equal( "authed-bot", result:get("x-wmf-ratelimit-class") )
            end)
            it("should use known-network for trust level A", function()
                local payload = { sub = "12345" }
                local meta = { ["envoy.filters.http.jwt_authn"] = { ["jwt_payload"] = payload } }
                local headers = { ["x-client-ip"] = "1234", ["x-trusted-request"] = "A" } -- should determine class
                local req = fake_request_handle( { streamMetadata = meta, headers = headers } )
                wmf_ratelimit_info(req)

                local result = req:headers()
                assert.are.equal( "bearer-sub:12345", result:get("x-wmf-user-id") )
                assert.are.equal( "known-network", result:get("x-wmf-ratelimit-class") )
            end)
            it("should use known-client for trust level B", function()
                local payload = { sub = "12345" } -- bearer token with no rlc claim
                local meta = { ["envoy.filters.http.jwt_authn"] = { ["jwt_payload"] = payload } }
                local headers = { ["x-client-ip"] = "1234", ["x-trusted-request"] = "B" } -- should determine class
                local req = fake_request_handle( { streamMetadata = meta, headers = headers } )
                wmf_ratelimit_info(req)

                local result = req:headers()
                assert.are.equal( "bearer-sub:12345", result:get("x-wmf-user-id") ) -- bearer token still used for ID
                assert.are.equal( "known-client", result:get("x-wmf-ratelimit-class") )
            end)
            it("should prefer the rlc claim from the token over the session cookie", function()
                -- If the bearer token and the session cookie both have an rlc claim,
                -- use the one from the bearer token.
                local payload = {
                    sub = "12345",
                    rlc = "special-class"
                }
                local cookie_payload = {
                    rlc = "cookie-class"
                }

                -- The JWT payload is stored in stream metadata
                local meta = { ["envoy.filters.http.jwt_authn"] = {
                    ["jwt_payload"] = payload,
                    ["cookie_payload"] = cookie_payload }
                }

                local headers = { ["x-client-ip"] = "1234" }
                local req = fake_request_handle( { streamMetadata = meta, headers = headers } )
                wmf_ratelimit_info(req)

                local result = req:headers()
                assert.are.equal( "bearer-sub:12345", result:get("x-wmf-user-id") )
                assert.are.equal( "special-class", result:get("x-wmf-ratelimit-class") )
            end)
            it("should fall back to the rlc claim from the session cookie (T418042)", function()
                -- If the bearer token doesn't have an rlc claim, use the one from the cookie.
                local payload = {
                    sub = "12345",
                }
                local cookie_payload = {
                    rlc = "updated-class"
                }

                -- The JWT payload is stored in stream metadata
                local meta = { ["envoy.filters.http.jwt_authn"] = {
                    ["jwt_payload"] = payload,
                    ["cookie_payload"] = cookie_payload }
                }

                local headers = { ["x-client-ip"] = "1234" }
                local req = fake_request_handle( { streamMetadata = meta, headers = headers } )
                wmf_ratelimit_info(req)

                local result = req:headers()
                assert.are.equal( "bearer-sub:12345", result:get("x-wmf-user-id") )
                assert.are.equal( "updated-class", result:get("x-wmf-ratelimit-class") )
            end)
            it("should not use the rlc claim if the sub claim is not present", function()
                -- The JWT payload is stored in stream metadata
                local payload = {
                    rls = "special-class" -- should be ignored
                }
                local meta = { ["envoy.filters.http.jwt_authn"] = { ["jwt_payload"] = payload } }
                local req = fake_request_handle( { streamMetadata = meta } )
                wmf_ratelimit_info(req)

                local result = req:headers()
                assert.are.equal( "anon", result:get("x-wmf-ratelimit-class") )
            end)
        end)
        describe("cookie_payload handling", function()
            it("should use the sub claim if present", function()
                -- The JWT payload is stored in stream metadata
                local payload = {
                    sub = "12345"
                }
                local meta = { ["envoy.filters.http.jwt_authn"] = { ["cookie_payload"] = payload } }
                local req = fake_request_handle( { streamMetadata = meta } )
                wmf_ratelimit_info(req)

                local result = req:headers()
                assert.are.equal( "cookie-sub:12345", result:get("x-wmf-user-id") )
                assert.are.equal( "authed-bot", result:get("x-wmf-ratelimit-class") )
            end)
            it("should use known-network for trust level A", function()
                local headers = { ["x-client-ip"] = "1234", ["x-trusted-request"] = "A", ["user-agent"] = "test" }
                local req = fake_request_handle( { headers = headers } )
                wmf_ratelimit_info(req)

                local result = req:headers()
                assert.are.equal( "user-agent:test", result:get("x-wmf-user-id") )
                assert.are.equal( "known-network", result:get("x-wmf-ratelimit-class") )
            end)
            it("should use known-client for trust level B", function()
                local headers = { ["x-client-ip"] = "1234", ["x-trusted-request"] = "B", ["x-provenance"] = "test" }
                local req = fake_request_handle( { headers = headers } )
                wmf_ratelimit_info(req)

                local result = req:headers()
                assert.are.equal( "x-provenance:test", result:get("x-wmf-user-id") ) -- token should still be used for ID
                assert.are.equal( "known-client", result:get("x-wmf-ratelimit-class") )
            end)
            it("should use the rlc claim if present", function()
                -- The JWT payload is stored in stream metadata
                local payload = {
                    sub = "12345",
                    rlc = "special-class"
                }
                local meta = { ["envoy.filters.http.jwt_authn"] = { ["cookie_payload"] = payload } }
                local headers = { ["x-client-ip"] = "1234"}
                local req = fake_request_handle( { streamMetadata = meta, headers = headers } )
                wmf_ratelimit_info(req)

                local result = req:headers()
                assert.are.equal( "cookie-sub:12345", result:get("x-wmf-user-id") )
                assert.are.equal( "special-class", result:get("x-wmf-ratelimit-class") )
            end)
            it("should ignore cookie rlc claim for known-network", function()
                -- The JWT payload is stored in stream metadata
                local payload = {
                    sub = "12345",
                    rlc = "special-class"
                }
                local meta = { ["envoy.filters.http.jwt_authn"] = { ["cookie_payload"] = payload } }
                local headers = { ["x-client-ip"] = "1234", ["x-trusted-request"] = "A" } -- should be preferred
                local req = fake_request_handle( { streamMetadata = meta, headers = headers } )
                wmf_ratelimit_info(req)

                local result = req:headers()
                assert.are.equal( "cookie-sub:12345", result:get("x-wmf-user-id") )
                assert.are.equal( "known-network", result:get("x-wmf-ratelimit-class") )
            end)
            it("should ignore bearer rlc claim for known-client", function()
                -- The JWT payload is stored in stream metadata
                local payload = {
                    sub = "12345",
                    rlc = "special-class"
                }
                local meta = { ["envoy.filters.http.jwt_authn"] = { ["jwt_payload"] = payload } }
                local headers = { ["x-client-ip"] = "1234", ["x-trusted-request"] = "B" } -- should be preferred
                local req = fake_request_handle( { streamMetadata = meta, headers = headers } )
                wmf_ratelimit_info(req)

                local result = req:headers()
                assert.are.equal( "bearer-sub:12345", result:get("x-wmf-user-id") )
                assert.are.equal( "known-client", result:get("x-wmf-ratelimit-class") )
            end)
            it("should not set x-wmf-ratelimit-class if rlc claim is BYPASS", function()
                -- The JWT payload is stored in stream metadata
                local payload = {
                    sub = "12345",
                    rlc = "BYPASS" -- magic value!
                }
                local meta = { ["envoy.filters.http.jwt_authn"] = { ["cookie_payload"] = payload } }
                local headers = { ["x-client-ip"] = "1234", }
                local req = fake_request_handle( { streamMetadata = meta, headers = headers } )
                wmf_ratelimit_info(req)

                local result = req:headers()
                assert.is_nil( result:get("x-wmf-ratelimit-class") )
            end)
            it("should not use the rlc claim if the sub claim is not present", function()
                -- The JWT payload is stored in stream metadata
                local payload = {
                    rls = "special-class" -- should be ignored
                }
                local meta = { ["envoy.filters.http.jwt_authn"] = { ["cookie_payload"] = payload } }
                local req = fake_request_handle( { streamMetadata = meta } )
                wmf_ratelimit_info(req)

                local result = req:headers()
                assert.are.equal( "anon", result:get("x-wmf-ratelimit-class") )
            end)
            it("should make use of the x-is-browser header", function()
                local payload = { sub = "12345" }
                local streamMetadata = { ["envoy.filters.http.jwt_authn"] = { ["cookie_payload"] = payload } }

                -- make the request appear to come from a browser
                local headers = {
                    ["x-is-browser"] = "100", -- above browser_threshold = 80
                    ["x-trusted-request"] = "C",
                    ["x-client-ip"] = "203.0.113.222", -- set x-client-ip to mark the request as external
                }

                local req = fake_request_handle( { streamMetadata = streamMetadata, headers = headers } )
                wmf_ratelimit_info(req)

                local result = req:headers()
                assert.are.equal( "cookie-sub:12345", result:get("x-wmf-user-id") )
                assert.are.equal( "authed-browser", result:get("x-wmf-ratelimit-class") )
                assert.is_nil( result:get("x-wmf-ratelimit-policy-1") )
            end)
        end)
        describe("OPTIONS support for CORS (T418969, T419866)", function()
            it("should bypass rate limiting for OPTIONS requests", function()
                local routeMeta = { ["wmf_ratelimit"] = { ["policies"] = { "just-a-test" } } }
                local headers = {
                    [":method"] = "OPTIONS",
                    ["x-client-ip"] = "192.168.1.1",
                }
                local req = fake_request_handle( { routeMetadata = routeMeta, headers = headers } )
                wmf_ratelimit_info(req)

                local result = req:headers()
                assert.is_nil( result:get("x-wmf-ratelimit-class") )
                assert.is_nil( result:get("x-wmf-ratelimit-policy-1") )
            end)
        end)
    end)

    describe("wmf_set_retry_after", function()
        function assertHeaderUpate( headers, headerName, expectedResult )
            local res = fake_response_handle{headers = headers}

            wmf_set_retry_after( res )

            local result = res:headers()
            assert.are.equal(expectedResult, result:get(headerName))
        end

        local retryable = { 429, 503 }

        for _, status in ipairs(retryable) do
            it("should use x-ratelimit-reset for status " .. status, function()
                local headers = {
                    [":status"] = "" .. status,
                    ["x-ratelimit-reset"] = "11",
                }

                assertHeaderUpate(headers, "retry-after", "11")
            end)

            it("should fall back to 60 seconds for status " .. status, function()
                local headers = {
                    [":status"] = "" .. status,
                }

                assertHeaderUpate(headers, "retry-after", "60")
            end)

            it("should preserve retry-after for status " .. status, function()
                local headers = {
                    [":status"] = "" .. status,
                    ["x-ratelimit-reset"] = "11",
                    ["retry-after"] = "5",
                }

                assertHeaderUpate(headers, "retry-after", "5")
            end)
        end

        it("should ignore x-ratelimit-reset for status 200", function()
            local headers = {
                [":status"] = "200",
                ["x-ratelimit-reset"] = "11",
            }

            assertHeaderUpate(headers, "retry-after", nil)
        end)

        it("should set response body when x-ratelimit-remaining is 0", function()
            local headers = {
                [":status"] = "429",
                ["x-ratelimit-reset"] = "11",
                ["x-ratelimit-remaining"] = "0", -- envoy caused the 429
            }

            local res = fake_response_handle{headers = headers}
            wmf_set_retry_after( res )

            assert.are.equal("ratelimit notice text", res:body():getBytes())
            assert.are.equal("text/plain", res:headers():get( "content-type" ))
        end)

        it("should not set response body when x-ratelimit-remaining is not 0", function()
            local headers = {
                [":status"] = "429",
                ["x-ratelimit-reset"] = "11",
                ["x-ratelimit-remaining"] = "2", -- something else caused the 429
            }

            local res = fake_response_handle{headers = headers}
            wmf_set_retry_after( res )

            local result = res:body():getBytes()
            assert.are_not.equal("ratelimit notice text", result)
        end)
    end)

    describe("wmf_stash_headers and wmf_expose_headers", function()
        it("should expose the configured headers", function()
            local headers = {
                ["something"] = "429",
                ["x-wmf-user-id"] = "Shawn",
                ["x-wmf-ratelimit-class"] = "user",
                [":method"] = "GET",
                [":path"] = "/test/this",
            }

            local streamMetadata = {}
            local req = fake_request_handle{
                headers = headers,
                streamMetadata = streamMetadata
            }

            wmf_stash_headers( req )

            local stashed = req:streamInfo():dynamicMetadata():get("envoy.wmf_headers")
            assert.is_nil(stashed["something"])
            assert.is_not_nil(stashed[":method"])
            assert.is_not_nil(stashed[":path"])
            assert.is_not_nil(stashed["x-wmf-user-id"])
            assert.is_not_nil(stashed["x-wmf-ratelimit-class"])

            local res = fake_response_handle{
                streamMetadata = streamMetadata
            }

            wmf_expose_headers( res )
            local result = res:headers()

            assert.is_nil(result:get("something"))
            assert.is_nil(result:get(":method"))
            assert.is_nil(result:get(":path"))
            assert.is.equal("Shawn", result:get("x-wmf-user-id"))
            assert.is.equal("user", result:get("x-wmf-ratelimit-class"))
        end)
    end)

    describe("wmf_set_cors_access_control for CORS (T418969)", function()
        local test_origin = "https://en.wikipedia.org"

        it("should set Access-Control headers if the origin header is present", function()
            local streamMetadata = {}
            local req = fake_request_handle{ streamMetadata = streamMetadata, headers = {
                ["origin"] = test_origin,
            } }

            -- Origin should be looped through by wmf_stash_headers
            wmf_stash_headers( req )

            -- No x-envoy-upstream-service-time: simulates a local (Envoy-generated) reply
            local resp = fake_response_handle{ streamMetadata = streamMetadata }
            wmf_set_cors_access_control(resp)

            local result = resp:headers()
            assert.is.equal( "true", result:get("access-control-allow-credentials") )
            assert.is.equal( test_origin, result:get("access-control-allow-origin") )
            assert.is.equal( "Retry-After,WWW-Authenticate", result:get("access-control-expose-headers") )
        end)

        it("should not set Access-Control headers if the Origin header is not present in request", function()
            local streamMetadata = {}
            local req = fake_request_handle{ streamMetadata = streamMetadata }
            wmf_stash_headers( req )

            -- No x-envoy-upstream-service-time: simulates a local (Envoy-generated) reply
            local resp = fake_response_handle{ streamMetadata = streamMetadata }
            wmf_set_cors_access_control(resp)

            local result = resp:headers()
            assert.is_nil( result:get("access-control-allow-credentials") )
            assert.is_nil( result:get("access-control-allow-origin") )
            assert.is_nil( result:get("access-control-expose-headers") )
        end)

        it("should not set Access-Control headers for OPTIONS requests", function()
            local streamMetadata = {}
            local req = fake_request_handle{ streamMetadata = streamMetadata, headers = {
                [":method"] = "OPTIONS",
                ["origin"] = test_origin,
            } }

            wmf_stash_headers( req )

            -- No x-envoy-upstream-service-time: simulates a local (Envoy-generated) reply
            local resp = fake_response_handle{ streamMetadata = streamMetadata }
            wmf_set_cors_access_control(resp)

            local result = resp:headers()
            assert.is_nil( result:get("access-control-allow-credentials") )
            assert.is_nil( result:get("access-control-allow-origin") )
            assert.is_nil( result:get("access-control-expose-headers") )
        end)

        it("should not set Access-Control headers for upstream responses", function()
            local streamMetadata = {}
            local req = fake_request_handle{ streamMetadata = streamMetadata, headers = {
                ["origin"] = test_origin,
            } }

            wmf_stash_headers( req )

            -- x-envoy-upstream-service-time present: simulates a proxied upstream response
            local resp = fake_response_handle{ streamMetadata = streamMetadata, headers = {
                ["x-envoy-upstream-service-time"] = "1",
            } }
            wmf_set_cors_access_control(resp)

            local result = resp:headers()
            assert.is_nil( result:get("access-control-allow-credentials") )
            assert.is_nil( result:get("access-control-allow-origin") )
            assert.is_nil( result:get("access-control-expose-headers") )
        end)
    end)
end)
