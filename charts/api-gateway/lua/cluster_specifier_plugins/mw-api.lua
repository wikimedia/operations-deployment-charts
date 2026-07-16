-- A Lua cluster specifier plugin script to manage upstream cluster selection
-- for the MediaWiki API. See [0] for an overview of the plugin API.
-- [0] https://www.envoyproxy.io/docs/envoy/latest/configuration/http/cluster_specifier/lua
function envoy_on_route(route_handle)
  -- Initially, send everything to the default cluster.
  return DEFAULT_CLUSTER
end
