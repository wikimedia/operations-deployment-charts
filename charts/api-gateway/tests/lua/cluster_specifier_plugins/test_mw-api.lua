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
  it("returns the default cluster when no other routing behaviors are configured", function()
    local handle = fake_route_handle({})
    assert.are.equal(DEFAULT_CLUSTER, envoy_on_route(handle))
  end)

  insulate("with x-wikimedia-debug routing", function()
    _G.XWD_BACKEND_CLUSTERS = {
      ["k8s-mwdebug"] = "mwdebug_cluster",
      ["k8s-mwdebug-next"] = "mwdebug-next_cluster",
    }

    it("returns the default cluster when the header is absent", function()
      local handle = fake_route_handle({})
      assert.are.equal(DEFAULT_CLUSTER, envoy_on_route(handle))
    end)

    it("returns the default cluster when the header specifies an unknown backend", function()
      local handle = fake_route_handle({ ["x-wikimedia-debug"] = "backend=unicorn" })
      assert.are.equal(DEFAULT_CLUSTER, envoy_on_route(handle))
    end)

    it("returns the appropriate cluster upon backend match", function()
      local handle = fake_route_handle({ ["x-wikimedia-debug"] = "backend=k8s-mwdebug" })
      assert.are.equal("mwdebug_cluster", envoy_on_route(handle))
    end)

    it("returns the appropriate cluster upon fallback to the header value", function()
      local handle = fake_route_handle({ ["x-wikimedia-debug"] = "k8s-mwdebug-next" })
      assert.are.equal("mwdebug-next_cluster", envoy_on_route(handle))
    end)
  end)
end)
