{{- define "config.app" }}

[[providers]]
name = "osm"
type = "postgis"
host = "{{ .Values.main_app.postgres.host }}"
max_connections = 10
port = "{{ .Values.main_app.postgres.port }}"
database = "{{ .Values.main_app.postgres.database }}"
user = "{{ .Values.main_app.postgres.user }}"
password = "${TEGOLA_POSTGRES_PASSWORD}"

  [[providers.layers]]
  name = "landuse"
  geometry_fieldname = "way"
  geometry_type = "Polygon"
  fields = [ "class", "osm_id", "way_area", "z_order" ]
  sql = """
  SELECT
    osm_id,
    ST_AsBinary(way) AS way,
    CASE
      WHEN \"natural\" = 'wood' OR landuse IN ('wood', 'forest') THEN 'wood'
      WHEN leisure IN ('national_reserve', 'nature_reserve', 'golf_course') OR boundary = 'national_park' THEN 'park'
      WHEN landuse IN ('cemetery', 'industrial') THEN landuse
      WHEN aeroway IS NOT NULL AND aeroway <> '' THEN 'industrial'
      WHEN landuse = 'village_green' OR leisure IN ('park', 'playground') THEN 'park'
      WHEN amenity IN ('school', 'university') THEN 'school'
      WHEN amenity = 'hospital' THEN 'hospital'
      ELSE bail_out('Unexpected landuse row with osm_id=%s', osm_id::TEXT)
    END AS class,
    z_order,
    way_area
  FROM planet_osm_polygon
  WHERE
    (
        (
            (
              \"natural\" = 'wood' OR landuse IN ('wood', 'forest')
              OR leisure IN ('national_reserve', 'nature_reserve', 'golf_course')
              OR boundary = 'national_park'
            )
            AND z(!SCALE_DENOMINATOR!) >= 7
        ) OR (
            (
              landuse IN ('cemetery', 'industrial', 'village_green')
              OR (aeroway IS NOT NULL AND aeroway <> '')
              OR leisure IN ('park', 'playground')
              OR amenity IN ('school', 'university')
            )
            AND z(!SCALE_DENOMINATOR!) >= 10
        ) OR (
            amenity = 'hospital'
            AND z(!SCALE_DENOMINATOR!) >= 12
        )
    )
    AND way && !BBOX!
    ORDER BY z_order, way_area DESC
  """

  [[providers.layers]]
  name = "waterway"
  geometry_fieldname = "way"
  geometry_type = "LineString"
  fields = [ "class", "osm_id" ]
  sql = """
  SELECT osm_id, ST_AsBinary(way) AS way, waterway AS class
  FROM planet_osm_line
  WHERE
    (
      (
        waterway IN ('river', 'canal')
        AND z(!SCALE_DENOMINATOR!) >= 8
      )
      OR
      (
        waterway IN ('stream', 'stream_intermittent')
        AND z(!SCALE_DENOMINATOR!) >= 13
      )
    )
    AND way && !BBOX!
  """

  [[providers.layers]]
  name = "water"
  geometry_type = "Polygon"
  geometry_fieldname = "way"
  fields = [ "osm_id" ]
  sql = """
  SELECT osm_id, ST_AsBinary(way) AS way
  FROM planet_osm_polygon
  WHERE
    (
      \"natural\" = 'water'
      OR (waterway IS NOT NULL AND waterway <> '')
      OR landuse = 'reservoir'
      OR landuse = 'pond'
    )
    AND
    (
      z(!SCALE_DENOMINATOR!) >= 14
      OR way_area >= 5000000000 / 2.3^z(!SCALE_DENOMINATOR!)
    )
    AND way && !BBOX!
  UNION ALL
  SELECT 0 AS osm_id, ST_AsBinary(way)
    FROM water_polygons
    WHERE
      way && !BBOX!
  """

  [[providers.layers]]
  name = "aeroway"
  geometry_type = "GeometryCollection"
  geometry_fieldname = "way"
  fields = [ "osm_id", "type" ]
  sql = """
  SELECT osm_id, ST_AsBinary(way) AS way, aeroway AS type
  FROM planet_osm_polygon
  WHERE
    (aeroway IS NOT NULL AND aeroway <> '')
    AND aeroway IN ('apron', 'helipad', 'runway', 'taxiway')
    AND z(!SCALE_DENOMINATOR!) >= 12
    AND way && !BBOX!
  UNION ALL
  SELECT osm_id, ST_AsBinary(way), aeroway AS type
    FROM planet_osm_line
    WHERE
      (aeroway IS NOT NULL AND aeroway <> '')
      AND z(!SCALE_DENOMINATOR!) >= 12
      AND way && !BBOX!
  """

  [[providers.layers]]
  name = "road"
  geometry_type = "LineString"
  geometry_fieldname = "way"
  fields = [ "class", "is", "osm_id" ]
  sql = """
  SELECT osm_id, ST_AsBinary(way) AS way, class, \"is\" FROM (
  SELECT
      osm_id,
      way,
      CASE
        WHEN highway IN ('motorway', 'motorway_link', 'driveway') THEN highway
        WHEN highway IN ('primary', 'primary_link', 'trunk', 'trunk_link', 'secondary', 'secondary_link', 'tertiary', 'tertiary_link') THEN 'main'
        WHEN highway IN ('residential', 'unclassified', 'living_street') THEN 'street'
        WHEN highway IN ('pedestrian', 'construction') OR access = 'private' THEN 'street_limited'
        WHEN railway IN ('rail', 'monorail', 'narrow_gauge', 'subway', 'tram') THEN 'major_rail'
        WHEN highway IN ('service', 'track') THEN 'service'
        WHEN highway IN ('path', 'cycleway', 'ski', 'steps', 'bridleway', 'footway') THEN 'path'
        WHEN railway IN ('funicular', 'light_rail', 'preserved') THEN 'minor_rail'
        ELSE bail_out('Unexpected road row with osm_id=%s', osm_id::TEXT)
      END AS class,
      z_order,
      CASE
        WHEN bridge IS NOT NULL AND bridge <> '' AND bridge <> 'no' AND bridge <> '0' THEN 'bridge'
        WHEN tunnel IS NOT NULL AND tunnel <> '' AND tunnel <> 'no' AND tunnel <> '0' THEN 'tunnel'
        ELSE 'road'
      END AS \"is\"
    FROM planet_osm_line
    WHERE
      (
          (
            highway IN ('motorway', -- 'motorway'
              'primary', 'primary_link', 'trunk', 'trunk_link' -- 'main'
            )
            AND z(!SCALE_DENOMINATOR!) >= 6
          )
          OR
          ( -- 'main'
            highway IN ('secondary', 'secondary_link')
            AND z(!SCALE_DENOMINATOR!) >= 9
          )
          OR
          ( -- 'main'
            highway IN ('tertiary', 'tertiary_link')
            AND z(!SCALE_DENOMINATOR!) >= 12
          )
          OR
          ( -- 'street'
            highway IN ('residential', 'unclassified', 'living_street')
            AND z(!SCALE_DENOMINATOR!) >= 12
          )
          OR
          ( -- 'street_limited'
            (highway IN ('pedestrian', 'construction') OR access = 'private')
            AND z(!SCALE_DENOMINATOR!) >= 12
          )
          OR
          ( -- 'major_rail'
            railway IN ('rail', 'monorail', 'narrow_gauge', 'subway', 'tram')
            AND z(!SCALE_DENOMINATOR!) >= 12
          )
          OR
          ( -- 'motorway_link'
            highway IN ('motorway_link')
            AND z(!SCALE_DENOMINATOR!) >= 13
          )
          OR
          ( -- 'service'
            highway IN ('service', 'track')
            AND z(!SCALE_DENOMINATOR!) >= 14
          )
          OR
          ( -- 'driveway'
            highway IN ('driveway')
            AND z(!SCALE_DENOMINATOR!) >= 14
          )
          OR
          ( -- 'path'
            highway IN ('path', 'cycleway', 'ski', 'steps', 'bridleway', 'footway')
            AND z(!SCALE_DENOMINATOR!) >= 14
          )
          OR
          ( -- 'minor_rail'
            railway IN ('funicular', 'light_rail', 'preserved')
            AND z(!SCALE_DENOMINATOR!) >= 14
          )
        )
      AND way && !BBOX!
  ) data JOIN (
    VALUES
      ('motorway', 1000),
      ('main', 900),
      ('street', 800),
      ('motorway_link', 700),
      ('street_limited', 600),
      ('driveway', 500),
      ('major_rail', 400),
      ('service', 300),
      ('minor_rail', 200),
      ('path', 100)
  ) AS ordertable(feature, prio) ON class=feature
    ORDER BY z_order + prio +
      CASE \"is\"
        WHEN 'tunnel' THEN -100000
        WHEN 'road' THEN 0
        WHEN 'bridge' THEN 100000
        ELSE bail_out('Unexpected row with is=%s, osm_id=%s', \"is\", osm_id::TEXT)::INT
      END
  """

  [[providers.layers]]
  name = "admin"
  geometry_type = "GeometryCollection"
  geometry_fieldname = "way"
  fields = [ "admin_level", "disputed", "maritime", "osm_id" ]
  sql = """
  SELECT
    osm_id, ST_AsBinary(way) AS way,
    admin_level::SMALLINT,
    maritime,
    CASE
      WHEN
        tags->'disputed' = 'yes'
        OR tags->'dispute' = 'yes'
        OR (tags->'disputed_by') IS NOT NULL
        OR tags->'status' = 'partially_recognized_state'
      THEN 1
      ELSE 0
    END AS disputed
  FROM admin
  WHERE
    maritime <> TRUE
    AND (
      ( admin_level = '2' AND z(!SCALE_DENOMINATOR!) >= 2 )
      OR ( admin_level = '4' AND z(!SCALE_DENOMINATOR!) >= 3 )
    )
    AND COALESCE(tags->'left:country', '') <> 'Demarcation Zone'
    AND COALESCE(tags->'right:country', '') <> 'Demarcation Zone'
    AND way && !BBOX!
  """

  [[providers.layers]]
  name = "country_label"
  geometry_type = "Point"
  geometry_fieldname = "way"
  fields = [ "code", "name", "osm_id", "scalerank" ]
  sql = """
  SELECT osm_id, ST_AsBinary(way) AS way, name, (hstore_to_json(extract_names(tags)))::text name_, CASE
      WHEN to_int(population) >= 250000000 THEN 1
      WHEN to_int(population) BETWEEN 100000000 AND  250000000 THEN 2
      WHEN to_int(population) BETWEEN 50000000 AND 100000000 THEN 3
      WHEN to_int(population) BETWEEN 25000000 AND 50000000 THEN 4
      WHEN to_int(population) BETWEEN 10000000 AND 25000000 THEN 5
      WHEN to_int(population) < 10000000 THEN 6
    END scalerank,
    COALESCE(tags->'ISO3166-1', tags->'country_code_iso3166_1_alpha_2') code
  FROM planet_osm_point
  WHERE
    place = 'country'
    AND z(!SCALE_DENOMINATOR!) BETWEEN 3 AND 10
    AND way && !BBOX!
  ORDER BY to_int(population) DESC NULLS LAST
  """

  [[providers.layers]]
  name = "poi_label"
  geometry_type = "GeometryCollection"
  geometry_fieldname = "way"
  fields = [ "localrank", "maki", "name", "osm_id", "scalerank" ]
  sql = """
  SELECT osm_id, ST_AsBinary(way1) AS way, name, rank AS scalerank, localrank, maki FROM
    (
      SELECT
        osm_id,
        name,
        (hstore_to_json(extract_names(tags)))::text name_,
        CASE
          WHEN railway='station' THEN 'rail'
          WHEN (tags->'subway') IS NOT NULL THEN 'rail-metro'
          WHEN highway='bus_stop' THEN 'bus'
          WHEN railway='tram_stop' THEN 'rail-light'
          WHEN amenity='ferry_terminal' THEN 'ferry'
          ELSE bail_out('Cannot classify poi_label, osm_id=%s', osm_id::TEXT)
        END AS maki,
        1 AS localrank,
        way AS way1
      FROM planet_osm_point
      WHERE
        z(!SCALE_DENOMINATOR!) >= 14
        AND
          (
            (public_transport='stop_position' AND (tags->'subway') IS NOT NULL)
            OR railway IN ('station', 'tram_stop')
            OR highway='bus_stop'
            OR amenity='ferry_terminal'
          )
        AND way && !BBOX!
    UNION ALL
      SELECT
        osm_id,
        name,
        (hstore_to_json(extract_names(tags)))::text name_,
        CASE
          WHEN railway='station' THEN 'rail'
          WHEN (tags->'subway') IS NOT NULL THEN 'rail-metro'
          WHEN highway='bus_stop' THEN 'bus'
          WHEN railway='tram_stop' THEN 'rail-light'
          WHEN amenity='ferry_terminal' THEN 'ferry'
          ELSE bail_out('Cannot classify poi_label, osm_id=%s', osm_id::TEXT)
        END AS maki,
        1 AS localrank,
        ST_Centroid(way) AS way1
      FROM planet_osm_polygon
      WHERE
        z(!scale_denominator!) >= 14
        AND
          (
            (public_transport='stop_position' AND (tags->'subway') IS NOT NULL)
            OR railway IN ('station', 'tram_stop')
            OR highway='bus_stop'
            OR amenity='ferry_terminal'
          )
        AND way && !BBOX!
    ) data JOIN (
      VALUES
        ('rail', 1),
        ('rail-metro', 1),
        ('rail-light', 1),
        ('ferry', 1),
        ('bus', 3)
      ) AS ranks(class, rank) ON class=maki
      ORDER BY scalerank, maki DESC, osm_id
  """

  [[providers.layers]]
  name = "road_label"
  geometry_type = "LineString"
  geometry_fieldname = "way"
  fields = [ "len", "name", "osm_id", "ref", "reflen", "shield" ]
  sql = """
  SELECT osm_id, 'default' AS shield, ST_AsBinary(way) AS way, name, name_, ref, reflen, len FROM (
    SELECT
        osm_id,
        way,
        name,
        (hstore_to_json(extract_names(tags)))::text name_,
        CASE
          WHEN highway IN ('motorway', 'motorway_link', 'driveway') THEN highway
          WHEN highway IN ('primary', 'primary_link', 'trunk', 'trunk_link', 'secondary', 'secondary_link', 'tertiary', 'tertiary_link') THEN 'main'
          WHEN highway IN ('residential', 'unclassified', 'living_street') THEN 'street'
          WHEN highway IN ('pedestrian', 'construction') OR access = 'private' THEN 'street_limited'
          WHEN railway IN ('rail', 'monorail', 'narrow_gauge', 'subway', 'tram') THEN 'major_rail'
          WHEN highway IN ('service', 'track') THEN 'service'
          WHEN highway IN ('path', 'cycleway', 'ski', 'steps', 'bridleway', 'footway') THEN 'path'
          WHEN railway IN ('funicular', 'light_rail', 'preserved') THEN 'minor_rail'
          ELSE bail_out('Unexpected road row with osm_id=%s', osm_id::TEXT)
        END AS class,
        z_order,
        CASE
          WHEN bridge IS NOT NULL AND bridge <> '' AND bridge <> 'no' AND bridge <> '0' THEN 'bridge'
          WHEN tunnel IS NOT NULL AND tunnel <> '' AND tunnel <> 'no' AND tunnel <> '0' THEN 'tunnel'
          ELSE 'road'
        END AS \"is\",
        ref,
        pg_catalog.char_length(ref) AS reflen,
        ROUND(merc_length(way)) AS len
      FROM planet_osm_line
      WHERE
        (
            (
              highway IN ('motorway', 'primary', 'primary_link', 'trunk',
                  'trunk_link', 'secondary', 'secondary_link'
                )
              AND ( (name IS NOT NULL AND name <> '') OR (ref IS NOT NULL AND ref <> ''))
              AND z(!SCALE_DENOMINATOR!) >= 11
            )
            OR
            ( -- 'main'
              highway IN ('tertiary', 'tertiary_link', 'residential', 'unclassified',
                  'living_street', 'pedestrian', 'construction', 'rail', 'monorail',
                  'narrow_gauge', 'subway', 'tram'
                )
              AND (name IS NOT NULL AND name <> '')
              AND z(!SCALE_DENOMINATOR!) >= 12
            )
            OR
            ( -- 'motorway_link'
              highway IN ('motorway_link', 'service', 'track', 'driveway', 'path',
                  'cycleway', 'ski', 'steps', 'bridleway', 'footway', 'funicular',
                  'light_rail', 'preserved'
                )
              AND (name IS NOT NULL AND name <> '')
              AND z(!SCALE_DENOMINATOR!) >= 14
            )
        )
        --AND linelabel(z(!SCALE_DENOMINATOR!), name, way)
        AND way && !BBOX!
      ) data JOIN (
        VALUES
          ('motorway', 1000),
          ('main', 900),
          ('street', 800),
          ('motorway_link', 700),
          ('street_limited', 600),
          ('driveway', 500),
          ('major_rail', 400),
          ('service', 300),
          ('minor_rail', 200),
          ('path', 100)
      ) AS ordertable(feature, prio) ON class=feature
        -- Sort the same way as the road layer, so that more important streets go
        -- first and have a higher priority to be rendered
        ORDER BY z_order + prio +
          CASE \"is\"
            WHEN 'tunnel' THEN -100000
            WHEN 'road' THEN 0
            WHEN 'bridge' THEN 100000
            ELSE bail_out('Unexpected row with is=%s, osm_id=%s', \"is\", osm_id::TEXT)::INT
          END
  """

  [[providers.layers]]
  name = "place_label"
  geometry_type = "Point"
  geometry_fieldname = "way"
  fields = [ "ldir", "localrank", "name", "osm_id", "type" ]
  sql = """
  SELECT
            osm_id,
            ST_AsBinary(way) AS way,
            name,
            name_,
            \"type\",
            ldir,
            localrank
  FROM(
  SELECT
    DISTINCT ON (labelgrid(way, 16, !PIXEL_WIDTH!))
      osm_id,
      way,
      get_label_name(name) AS name,
      (hstore_to_json(extract_names(tags)))::text name_,
      place AS \"type\",
      'SE' AS ldir,
      1 AS localrank, -- TODO:
      CASE
        WHEN place = 'city' THEN 5000000000 + to_int(population)
        WHEN place = 'town' THEN 3000000000 + to_int(population)
        WHEN place = 'village' THEN 1000000000 + to_int(population)
        ELSE to_int(population)
      END AS sort_order
    FROM planet_osm_point
    WHERE
      (
        (
          place = 'city'
          AND z(!SCALE_DENOMINATOR!) >= 4
          -- On zoom 4, display cities with 1M+ population. Decrease by 250k every level
          AND (to_int(population) + z(!SCALE_DENOMINATOR!) * 250000 - 2000000) > 0
        )
        OR
        (
          place = 'town'
          AND z(!SCALE_DENOMINATOR!) >= 9
        )
        OR
        (
          place = 'village'
          AND z(!SCALE_DENOMINATOR!) >= 11
        )
        OR
        (
          place IN ('hamlet', 'suburb','neighbourhood')
          AND z(!SCALE_DENOMINATOR!) >= 13
        )
      )
      AND (name IS NOT NULL AND name <> '')
      AND way && !BBOX! --ST_Expand(!BBOX!, 64*!PIXEL_WIDTH!)
    ORDER BY
      labelgrid(way, 16, !PIXEL_WIDTH!),
      sort_order DESC,
      pg_catalog.length(name) DESC,
      name
  ) data ORDER BY sort_order DESC
  """

  [[providers.layers]]
  name = "building"
  geometry_type = "Polygon"
  geometry_fieldname = "way"
  fields = [ "osm_id" ]
  sql = """
  SELECT osm_id, ST_AsBinary(way) AS way
  FROM planet_osm_polygon
  WHERE
    z(!SCALE_DENOMINATOR!) >= 14
    AND (building IS NOT NULL AND building <> '')
    AND building <> 'no'
    AND way && !BBOX!
  """

[[maps]]
name = "osm"
attribution = 'Map data © <a href="http://openstreetmap.org/copyright">OpenStreetMap contributors</a>'
center = [ -122.4144, 37.7907, 14.0 ]
tile_buffer = 8

  [[maps.layers]]
  provider_layer = "osm.landuse"
  min_zoom = 0
  max_zoom = 14

  [[maps.layers]]
  provider_layer = "osm.waterway"
  min_zoom = 0
  max_zoom = 14

  [[maps.layers]]
  provider_layer = "osm.water"
  min_zoom = 0
  max_zoom = 14

  [[maps.layers]]
  provider_layer = "osm.aeroway"
  min_zoom = 0
  max_zoom = 14

  [[maps.layers]]
  provider_layer = "osm.road"
  min_zoom = 0
  max_zoom = 14

  [[maps.layers]]
  provider_layer = "osm.admin"
  min_zoom = 0
  max_zoom = 14

  [[maps.layers]]
  provider_layer = "osm.country_label"
  min_zoom = 0
  max_zoom = 14

  [[maps.layers]]
  provider_layer = "osm.poi_label"
  min_zoom = 0
  max_zoom = 14

  [[maps.layers]]
  provider_layer = "osm.road_label"
  min_zoom = 0
  max_zoom = 14

  [[maps.layers]]
  provider_layer = "osm.place_label"
  min_zoom = 0
  max_zoom = 14

  [[maps.layers]]
  provider_layer = "osm.building"
  min_zoom = 0
  max_zoom = 14

{{- end }}
