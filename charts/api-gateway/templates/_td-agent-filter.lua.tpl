{{- define "fluent-bit.lua" }}
function replace_client_id(tag, timestamp, record)
   for key, val in pairs(record) do
     if ( val == nil ) then
       -- This removed the key from the map
       record[key] = nil
     end
   end
   return 2, timestamp, record
end
{{ end }}