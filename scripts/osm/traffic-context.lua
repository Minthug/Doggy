local features = osm2pgsql.define_table({
    name = 'osm_context_features_stage',
    ids = { type = 'any', id_column = 'osm_id', type_column = 'osm_type' },
    columns = {
        { column = 'feature_type', type = 'text', not_null = true },
        { column = 'subtype', type = 'text' },
        { column = 'geom', type = 'geometry', projection = 4326, not_null = true },
    },
})

local function road_type(highway)
    local ignored = {
        footway = true, path = true, pedestrian = true, steps = true,
        cycleway = true, bridleway = true, corridor = true,
        proposed = true, construction = true,
    }
    return highway ~= nil and not ignored[highway]
end

local function walking_type(highway)
    return highway == 'footway' or highway == 'path'
        or highway == 'pedestrian' or highway == 'steps'
end

local function park_type(tags)
    return tags.leisure == 'park' or tags.leisure == 'garden'
        or tags.leisure == 'dog_park' or tags.leisure == 'recreation_ground'
        or tags.landuse == 'grass' or tags.landuse == 'forest'
        or tags.natural == 'wood'
end

function osm2pgsql.process_node(object)
    local highway = object.tags.highway
    if highway == 'traffic_signals' then
        features:insert({
            feature_type = 'TRAFFIC_SIGNAL',
            subtype = object.tags.traffic_signals or object.tags.crossing,
            geom = object:as_point(),
        })
    elseif highway == 'crossing' then
        features:insert({
            feature_type = 'CROSSWALK',
            subtype = object.tags.crossing,
            geom = object:as_point(),
        })
    end
end

function osm2pgsql.process_way(object)
    local tags = object.tags
    local highway = tags.highway

    if highway == 'footway' and tags.footway == 'crossing' then
        features:insert({
            feature_type = 'CROSSWALK', subtype = tags.crossing,
            geom = object:as_linestring(),
        })
    elseif walking_type(highway) then
        features:insert({
            feature_type = 'FOOTWAY', subtype = highway,
            geom = object:as_linestring(),
        })
    elseif road_type(highway) then
        features:insert({
            feature_type = 'ROAD', subtype = highway,
            geom = object:as_linestring(),
        })
    elseif object.is_closed and park_type(tags) then
        features:insert({
            feature_type = 'PARK', subtype = tags.leisure or tags.landuse or tags.natural,
            geom = object:as_polygon(),
        })
    end
end

function osm2pgsql.process_relation(object)
    if object.tags.type == 'multipolygon' and park_type(object.tags) then
        features:insert({
            feature_type = 'PARK',
            subtype = object.tags.leisure or object.tags.landuse or object.tags.natural,
            geom = object:as_multipolygon(),
        })
    end
end
