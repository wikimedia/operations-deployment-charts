-- Select the appropriate upstream cluster based on the value of the
-- X-Wikimedia-Debug header, if available.
function xwd_routing(route_handle)
  if not XWD_BACKEND_CLUSTERS then
    return nil
  end
  local xwd = route_handle:headers():get("x-wikimedia-debug")
  if not xwd then
    return nil
  end
  local backend = string.match(xwd, 'backend=([%a%d%.-]+)')
  if not backend then
    -- If no backend attribute is present, fall back to the header value.
    backend = xwd
  end
  return XWD_BACKEND_CLUSTERS[backend]
end

-- Select the appropriate upstream cluster based on the value of the
-- :authority pseudo-header.
function host_routing(route_handle)
  if not HOST_DIVERSION_CLUSTERS then
    return nil
  end
  local host = route_handle:headers():get(":authority")
  if not host then
    return nil  -- This is purely defensive and should not happen.
  end
  return HOST_DIVERSION_CLUSTERS[host]
end

-- A Lua cluster specifier plugin script to manage upstream cluster selection
-- for the MediaWiki API. See [0] for an overview of the plugin API.
-- [0] https://www.envoyproxy.io/docs/envoy/latest/configuration/http/cluster_specifier/lua
function envoy_on_route(route_handle)
  -- Host-based diversion (e.g., for Pretrain) always wins.
  local cluster = host_routing(route_handle)
  if cluster ~= nil then
    return cluster
  end
  cluster = xwd_routing(route_handle)
  if cluster ~= nil then
    return cluster
  end
  -- Send everything that remains to the default cluster.
  return DEFAULT_CLUSTER
end
