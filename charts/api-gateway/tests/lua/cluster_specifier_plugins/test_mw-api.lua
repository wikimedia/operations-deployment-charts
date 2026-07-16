-- Tests for the mw-api cluster specifier plugin.

local thisdir = debug.getinfo(1).source:match("@?(.*/)") or "."
dofile(thisdir .. "fakes.lua")

-- Load the code under test.
local codeFile = thisdir .. "/../../../lua/cluster_specifier_plugins/mw-api.lua"
local codeFunc = loadfile(codeFile)
if not codeFunc then
    print("Code under test is invalid:")
    os.execute("lua " .. codeFile)
    os.exit(3)
end

-- Execute the code under test to define the envoy_on_route hook.
codeFunc()

-- Common (global) fixture.
_G.DEFAULT_CLUSTER = "the-default_cluster"

describe("mw-api cluster specifier plugin", function()
  it("returns the default cluster", function()
    local handle = fake_route_handle({})
    assert.are.equal(DEFAULT_CLUSTER, envoy_on_route(handle))
  end)
end)
