{{- define "config.app" }}

{{- if .Values.tileCaching.enabled }}
[cache]
{{- range $k, $v := .Values.tileCaching.config }}
{{ $k }} = {{ kindIs "string" $v | ternary ($v | quote) $v}}
{{- end }}
{{- end }}

[observer]
type = "prometheus"

[[providers]]
name = "osm"
type = "mvt_postgis"
host = "{{ .Values.main_app.postgres.host }}"
max_connections = {{ .Values.main_app.postgres.max_connections }}
port = "{{ .Values.main_app.postgres.port }}"
database = "{{ .Values.main_app.postgres.database }}"
user = "{{ .Values.main_app.postgres.user }}"
password = "${TEGOLA_POSTGRES_PASSWORD}"

  [[providers.layers]]
  name = "landuse"
  geometry_fieldname = "geom"
  geometry_type = "polygon"
  id_fieldname = "osm_id"
  sql = "SELECT class, osm_id, way_area, z_order, ST_AsMVTGeom(geometry, !BBOX!) AS geom FROM layer_landuse(!BBOX!, !ZOOM!)"

  [[providers.layers]]
  name = "waterway"
  geometry_fieldname = "geom"
  geometry_type = "linestring"
  id_fieldname = "osm_id"
  sql = "SELECT class, osm_id, ST_AsMVTGeom(geometry, !BBOX!) AS geom FROM layer_waterway(!BBOX!, !ZOOM!)"

  [[providers.layers]]
  name = "water"
  geometry_type = "polygon"
  geometry_fieldname = "geom"
  id_fieldname = "osm_id"
  sql = "SELECT osm_id, ST_AsMVTGeom(geometry, !BBOX!) AS geom FROM layer_water(!BBOX!, !ZOOM!)"

  [[providers.layers]]
  name = "aeroway"
  geometry_type = "polygon"
  geometry_fieldname = "geom"
  id_fieldname = "osm_id"
  sql = "SELECT osm_id, ST_AsMVTGeom(geometry, !BBOX!) AS geom, type FROM layer_aeroway(!BBOX!, !ZOOM!)"

  [[providers.layers]]
  name = "road"
  geometry_type = "linestring"
  geometry_fieldname = "geom"
  id_fieldname = "osm_id"
  sql = "SELECT osm_id, ST_AsMVTGeom(geometry, !BBOX!) AS geom, class, z_order, 'is' FROM layer_transportation(!BBOX!, !ZOOM!)"

  [[providers.layers]]
  name = "admin"
  geometry_type = "linestring"
  geometry_fieldname = "geom"
  fields = [ "admin_level", "disputed", "maritime", "osm_id" ]
  sql = "SELECT osm_id, ST_AsMVTGeom(geometry, !BBOX!) AS geom, admin_level, maritime, disputed FROM layer_admin(!BBOX!, !ZOOM!)"

  [[providers.layers]]
  name = "country_label"
  geometry_type = "point"
  geometry_fieldname = "geom"
  id_fieldname = "osm_id"
  sql = "SELECT osm_id, ST_AsMVTGeom(geometry, !BBOX!) AS geom, name, name_, scalerank, code FROM layer_country_label(!BBOX!, !ZOOM!)"

  [[providers.layers]]
  name = "poi_label"
  geometry_type = "point"
  geometry_fieldname = "geom"
  id_fieldname = "osm_id"
  sql = "SELECT osm_id, ST_AsMVTGeom(geometry, !BBOX!) AS geom, localrank, scalerank, maki, name FROM layer_poi_label(!BBOX!, !ZOOM!)"

  [[providers.layers]]
  name = "road_label"
  geometry_type = "linestring"
  geometry_fieldname = "geom"
  id_fieldname = "osm_id"
  sql = "SELECT osm_id, ST_AsMVTGeom(geometry, !BBOX!) AS geom, shield, name, name_, ref, reflen, len FROM layer_transportation_name(!BBOX!, !ZOOM!)"

  [[providers.layers]]
  name = "place_label"
  geometry_type = "point"
  geometry_fieldname = "geom"
  id_fieldname = "osm_id"
  sql = "SELECT osm_id, ST_AsMVTGeom(geometry, !BBOX!) AS geom, ldir, localrank, name, osm_id, type FROM layer_place_label(!BBOX!, !ZOOM!, !PIXEL_WIDTH!)"

  [[providers.layers]]
  name = "building"
  geometry_type = "polygon"
  geometry_fieldname = "geom"
  id_fieldname = "osm_id"
  sql = "SELECT osm_id, ST_AsMVTGeom(geometry, !BBOX!) AS geom FROM layer_building(!BBOX!, !ZOOM!)"

[[maps]]
name = "osm"
attribution = 'Map data © <a href="http://openstreetmap.org/copyright">OpenStreetMap contributors</a>'
center = [ -122.4144, 37.7907, 14.0 ]
tile_buffer = 8

  [[maps.layers]]
  provider_layer = "osm.landuse"
  min_zoom = 7
  max_zoom = 15

  [[maps.layers]]
  provider_layer = "osm.waterway"
  min_zoom = 8
  max_zoom = 15

  [[maps.layers]]
  provider_layer = "osm.water"
  min_zoom = 0
  max_zoom = 15

  [[maps.layers]]
  provider_layer = "osm.aeroway"
  min_zoom = 12
  max_zoom = 15

  [[maps.layers]]
  provider_layer = "osm.road"
  min_zoom = 6
  max_zoom = 15

  [[maps.layers]]
  provider_layer = "osm.admin"
  min_zoom = 0
  max_zoom = 15

  [[maps.layers]]
  provider_layer = "osm.country_label"
  min_zoom = 3
  max_zoom = 10

  [[maps.layers]]
  provider_layer = "osm.poi_label"
  min_zoom = 14
  max_zoom = 15

  [[maps.layers]]
  provider_layer = "osm.road_label"
  min_zoom = 11
  max_zoom = 15

  [[maps.layers]]
  provider_layer = "osm.place_label"
  min_zoom = 3
  max_zoom = 15

  [[maps.layers]]
  provider_layer = "osm.building"
  min_zoom = 14
  max_zoom = 15

{{- end }}
