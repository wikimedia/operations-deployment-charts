-- Tests for the early Lua filter (restgw_headers.lua)
-- File under test:
local thisdir = debug.getinfo(1).source:match("@?(.*/)") or "."
dofile(thisdir .. "fakes.lua")

local codeFile = thisdir .. "/../../lua/restgw_headers.lua"
local codeFunc = loadfile( codeFile )

if not codeFunc then
    print( "Code under test is invalid:" )
    os.execute( "lua " .. codeFile )
    os.exit(3)
end

-- Run the code under test to define functions to test.
codeFunc()

-- This uses the Busted test framework, see https://lunarmodules.github.io/busted/.

describe("restgw_headers", function()
    -- -----------------------------------------------------------------------
    describe("wmf_stash_request_info", function()
        it("should stash :method, :path, and origin", function()
            local streamMetadata = {}
            local req = fake_request_handle{ streamMetadata = streamMetadata, headers = {
                [":method"] = "GET",
                [":path"]   = "/test/path",
                ["origin"]  = "https://en.wikipedia.org",
                ["x-wmf-user-id"]       = "some-user",
                ["x-wmf-ratelimit-class"] = "anon",
                ["x-client-ip"]         = "1.2.3.4",
            } }

            wmf_stash_request_info(req)

            local stashed = req:streamInfo():dynamicMetadata():get("envoy.wmf_request_info")
            assert.are.equal("GET", stashed[":method"])
            assert.are.equal("/test/path", stashed[":path"])
            assert.are.equal("https://en.wikipedia.org", stashed["origin"])

            -- should not stash other headers
            assert.is_nil(stashed["x-wmf-user-id"])
            assert.is_nil(stashed["x-wmf-ratelimit-class"])
            assert.is_nil(stashed["x-client-ip"])
        end)
    end)

    -- -----------------------------------------------------------------------
    describe("wmf_set_cors_access_control for CORS (T418969)", function()
        local test_origin = "https://en.wikipedia.org"

        it("should set Access-Control headers if the origin query parameter is present", function()
            local streamMetadata = {}
            local req = fake_request_handle{ streamMetadata = streamMetadata, headers = {
                ["origin"] = test_origin,
            } }

            -- Origin should be looped through by wmf_stash_request_info
            wmf_stash_request_info( req )

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
            wmf_stash_request_info( req )

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

            wmf_stash_request_info( req )

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

            wmf_stash_request_info( req )

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

        it("should set Access-Control headers for local (Envoy-generated) responses", function()
            local streamMetadata = {}
            local req = fake_request_handle{ streamMetadata = streamMetadata, headers = {
                ["origin"] = test_origin,
            } }

            wmf_stash_request_info( req )

            -- No x-envoy-upstream-service-time: simulates a local reply (e.g. 429, 404)
            local resp = fake_response_handle{ streamMetadata = streamMetadata }
            wmf_set_cors_access_control(resp)

            local result = resp:headers()
            assert.is.equal( "true", result:get("access-control-allow-credentials") )
            assert.is.equal( test_origin, result:get("access-control-allow-origin") )
            assert.is.equal( "Retry-After,WWW-Authenticate", result:get("access-control-expose-headers") )
        end)
    end)
end)