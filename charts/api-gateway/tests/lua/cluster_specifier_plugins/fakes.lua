-- A partial fake for the header object API.
-- https://www.envoyproxy.io/docs/envoy/latest/configuration/http/cluster_specifier/lua#header-object-api
function fake_headers_obj(headers)
  local obj = { _headers = headers }
  obj.get = function(self, k) return self._headers[k] end
  return obj
end

-- A partial fake for the route handle API. Notably, the cluster API is not supported.
-- https://www.envoyproxy.io/docs/envoy/latest/configuration/http/cluster_specifier/lua#route-handle-api
function fake_route_handle(headers)
  local handle = { _headers_obj = fake_headers_obj(headers) }
  handle.headers = function(self) return self._headers_obj end
  return handle
end
