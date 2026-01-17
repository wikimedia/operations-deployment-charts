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
            user_id_cookie = "TestUserID",
            ratelimit_notice_text = "ratelimit notice text",
            default_policies = {
                "DefaultPolicy1",
                "DefaultPolicy2",
                "DefaultPolicy3",
            },
        }
    }
}

-- Run the code under test to define functions to test.
codeFunc()

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
        headers.get = function(h, k) return h.values[k] end
        headers.add = function(h, k, v) h.values[k] = v end
        headers.replace = function(h, k, v) h.values[k] = v end
        headers.remove = function(h, k) h.values[k] = nil end

        return headers
    end

    function fake_metadata(values)
        return {
            get = function(h, k) return values[k] end
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

    function fake_stream_info(address, metadata)
        return add_getters( {},{
            downstreamRemoteAddress = address,
            dynamicMetadata = fake_metadata(metadata),
        })
    end

    function noop() end

    function fake_request_handle(arg)
        local headers = arg.headers or { ["x-client-ip"] = "192.168.1.1" }

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

        return add_getters( {
            logDebug = noop,
            logInfo = noop,
            logWarning = noop,
        },{
            headers = fake_headers(headers),
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
            it("should use the x-is-browser header to recognize organic traffic", function()
                local headers = {
                    ["x-trusted-request"] = "E",
                    ["x-is-browser"] = "100", -- above 80
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
                    ["x-is-browser"] = "50", -- below 80
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
            it("should use the rlc claim if present", function()
                -- The JWT payload is stored in stream metadata
                local payload = {
                    sub = "12345",
                    rlc = "special-class"
                }
                local meta = { ["envoy.filters.http.jwt_authn"] = { ["jwt_payload"] = payload } }
                local req = fake_request_handle( { streamMetadata = meta } )
                wmf_ratelimit_info(req)

                local result = req:headers()
                assert.are.equal( "bearer-sub:12345", result:get("x-wmf-user-id") )
                assert.are.equal( "special-class", result:get("x-wmf-ratelimit-class") )
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
                assert.are.equal( "authed-other", result:get("x-wmf-ratelimit-class") )
            end)
            it("should use the rlc claim if present", function()
                -- The JWT payload is stored in stream metadata
                local payload = {
                    sub = "12345",
                    rlc = "special-class"
                }
                local meta = { ["envoy.filters.http.jwt_authn"] = { ["cookie_payload"] = payload } }
                local req = fake_request_handle( { streamMetadata = meta } )
                wmf_ratelimit_info(req)

                local result = req:headers()
                assert.are.equal( "cookie-sub:12345", result:get("x-wmf-user-id") )
                assert.are.equal( "special-class", result:get("x-wmf-ratelimit-class") )
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
        end)
        describe("cookie handling", function()
            it("should use the user ID from the cookie", function()
                -- cookie values are expected to be stored in stream metadata
                local streamMetadata = { ["envoy.wmf_cookies"] = { ["TestUserID"] = "Cindy" } }
                local req = fake_request_handle( { streamMetadata = streamMetadata } )
                wmf_ratelimit_info(req)

                local result = req:headers()
                assert.are.equal( "TestUserID:Cindy", result:get("x-wmf-user-id") )
                assert.are.equal( "authed-other", result:get("x-wmf-ratelimit-class") )
            end)
            it("should use the user ID from the cookie", function()
                -- cookie values are expected to be stored in stream metadata
                streamMetadata = { ["envoy.wmf_cookies"] = { ["TestUserID"] = "Cindy" } }

                -- make the request appear to come from a browser
                local headers = {
                    ["x-is-browser"] = "100", -- above 80
                    ["x-trusted-request"] = "C",
                    ["x-client-ip"] = "203.0.113.222", -- set x-client-ip to mark the request as external
                }

                local req = fake_request_handle( { streamMetadata = streamMetadata, headers = headers } )
                wmf_ratelimit_info(req)

                local result = req:headers()
                assert.are.equal( "TestUserID:Cindy", result:get("x-wmf-user-id") )
                assert.are.equal( "authed-browser", result:get("x-wmf-ratelimit-class") )
                assert.is_nil( result:get("x-wmf-ratelimit-policy-1") )
            end)
            it("should use the user ID from the cookie even for trust level A", function()
                -- cookie values are expected to be stored in stream metadata
                streamMetadata = { ["envoy.wmf_cookies"] = { ["TestUserID"] = "Cindy" } }

                -- make the request appear to come from a trusted network
                local headers = {
                    ["x-is-browser"] = "20", -- below 80
                    ["x-trusted-request"] = "A",
                    ["user-agent"] = "CindyBot 2.0 (User:Cindy)",
                    ["x-provenance"] = "client=cindy",
                    ["x-client-ip"] = "203.0.113.222", -- set x-client-ip to mark the request as external
                }

                local req = fake_request_handle( { streamMetadata = streamMetadata, headers = headers } )
                wmf_ratelimit_info(req)

                local result = req:headers()
                assert.are.equal( "TestUserID:Cindy", result:get("x-wmf-user-id") )
                assert.are.equal( "authed-other", result:get("x-wmf-ratelimit-class") )
            end)
        end)
    end)

    describe("wmf_request_cleanup", function()
        function assertHeaderUpate( headerName, headerValue, expectedResult )
            local headers = { test = "foobar" }
            headers[headerName] = headerValue

            local req = fake_request_handle{headers = headers}

            wmf_request_cleanup( req )

            local result = req:headers()
            assert.are.equal("foobar", result:get("test"))
            assert.are.equal(expectedResult, result:get(headerName))
        end

        it("should unset x-wmf-ratelimit-class header if it is 'no-limit'", function()
            assertHeaderUpate("x-wmf-ratelimit-class", "no-limit", nil)
        end)

        it("should preserve x-wmf-ratelimit-class header if it is 'some-class'", function()
            assertHeaderUpate("x-wmf-ratelimit-class", "some-class", "some-class")
        end)

        it("should preserve x-something-else header even if it is 'no-limit'", function()
            assertHeaderUpate("x-something-else", "no-limit", "no-limit")
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
end)
