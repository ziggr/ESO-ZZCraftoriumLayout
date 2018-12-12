local cm =   1
local m  = 100

local TAU           = 2 * math.pi
local RADIUS_START  = 33 * m
local RADIUS_STEP   =  6 * m
local PATH_WIDTH    =  RADIUS_STEP * 0.65
local STATION_WIDTH = 2 * m
local Y             = 36930
local ANGLE_START   = TAU*3/4
local CENTER        = { x = 84446 * cm, z = 91337 * cm }

local FURNITURE = {
    ["bs"  ] = {}
,   ["cl"  ] = {}
,   ["ww"  ] = {}
,   ["jw"  ] = {}
,   ["lamp"] = {}
}
local WIDTH = {
    ["bs"  ] = 160
,   ["cl"  ] = 200
,   ["ww"  ] = 200
,   ["jw"  ] = 200
,   ["lamp"] = 160
}
local ANGLE = {
    ["bs"  ] = 7/8 * TAU    -- 4/8 faces  2:00, want 6:00, try 7/8
,   ["cl"  ] = 6/8 * TAU    -- 3/8 faces 10:00, want 6:00, try 6/8
,   ["ww"  ] = 1/8 * TAU    -- 3/8 faces  3:00, want 6:00, try 1/8
,   ["jw"  ] = 1/8 * TAU    -- 3/8 faces  9:00, want 6:00, try 1/8
,   ["lamp"] = 160
}

--[[# width in pixels along the wall
WIDTH = {
      'omit lamp' :   0   # no lamp, no space for lamp
    , 'hide lamp' : 160   # suppress lamp, but count space as if one were there.
    , 'lamp'      : 160
    , 'sconce'    : 160
    , 'jw'        : 200
    , 'bs'        : 160
    , 'cl'        : 200
    , 'ww'        : 200
}
--]]

function AddAngle(a,b)
    return (a + b) % TAU
end

function PlaceNextStation(radius, center_on_angle, station_width, station_angle)
                        -- Station goes here.
    local offset = {
        x = math.cos(center_on_angle)*radius
      , z = math.sin(center_on_angle)*radius }

                        -- How wide is the station, at this radius, in radians?
    local angular_width = 2 * math.atan( (station_width or STATION_WIDTH)
                                       / radius )

    local radius_step = RADIUS_STEP * ( angular_width / TAU )

    return { x           = offset.x + CENTER.x
           , z           = offset.z + CENTER.z
           , orient      = AddAngle(center_on_angle, TAU/2 + station_angle)
           , radius_step = radius_step
           , next_angle  = AddAngle(center_on_angle, angular_width )
           }
end

-- From http://lua-users.org/wiki/SplitJoin
function split2(str,sep)
    local ret={}
    local n=1
    local offset = 1
                        -- "true" here is arg "plain", which turns off
                        -- pattern expressions and uses just boring old
                        -- byte matching.
    local delim_begin, delim_end = str:find(sep, offset, true)
    while delim_begin do
        local sub = str:sub(offset, delim_begin - 1)
        table.insert(ret, sub)
        offset = delim_end + 1
        delim_begin, delim_end = str:find(sep, offset, true)
    end
    if offset < str:len() then
        table.insert(ret, str:sub(offset, str:len()))
    end
    return ret
end


function LoadFurniture()
    for line in io.lines("furn.txt") do
        local w = split2(line, "\t")
        if w and w[2] then
            local row = { type = w[2]
                        , id   = w[3]
                        , name = w[4] }
-- for i,v in ipairs(w) do
--     print(string.format("[%d] '%s'",i,v))
-- end
            FURNITURE[row.type] = FURNITURE[row.type] or {}
            table.insert(FURNITURE[row.type], row )
        end
    end
end

function deg(rad)
    return rad * 360 / TAU
end

function main()
    LoadFurniture()

    local angle  = ANGLE_START
    local radius = RADIUS_START

    local sequence   = { "ww", "cl", "bs", "jw", "jw", "bs", "cl", "ww", "lamp" }
    local sequence_i = 1
    local comma      = " "
    for i = 1, 999 do
        local station_type = sequence[sequence_i]
        sequence_i = sequence_i + 1
        if #sequence < sequence_i then sequence_i = 1 end

        local station_inner = nil
        local station_outer = nil

        if 0 < #FURNITURE[station_type] then
            station_outer = FURNITURE[station_type][#FURNITURE[station_type]]
            table.remove(FURNITURE[station_type], #FURNITURE[station_type])
        end

        if 0 < #FURNITURE[station_type] then
            station_inner = FURNITURE[station_type][1]
            table.remove(FURNITURE[station_type], 1)
        end

        local r_inner = PlaceNextStation(radius - PATH_WIDTH / 2, angle, WIDTH[station_type], ANGLE[station_type])
        local r_outer = PlaceNextStation(radius + PATH_WIDTH / 2, angle, WIDTH[station_type], ANGLE[station_type])

        r_inner.orient = AddAngle(r_inner.orient, TAU/2 )

        if station_outer then
            print(string.format( "%s \"%s\t%d\t%d\t%d\t%d\t%s\ti %s\t%d\""
                               , comma
                               , station_outer.id
                               , r_outer.x
                               , r_outer.z
                               , Y
                               , deg(r_outer.orient)
                               , station_outer.type
                               , station_outer.name
                               , deg(angle)
                               ))
            comma = ","
        end

        if station_inner then
            print(string.format( "%s \"%s\t%d\t%d\t%d\t%d\t%s\to %s\""
                               , comma
                               , station_inner.id
                               , r_inner.x
                               , r_inner.z
                               , Y
                               , deg(r_inner.orient)
                               , station_inner.type
                               , station_inner.name
                               ))
            comma = ","
        end

        angle  = r_inner.next_angle
        radius = radius - r_inner.radius_step

        if not (station_outer or station_inner) then break end
    end
end

function preamble()
    print("ZZCraftoriumLayout = ZZCraftoriumLayout or { }                      ")
    print()
    print("-- furniture_unique_id  x       z       y       rot station index   ")
    print("ZZCraftoriumLayout.POSITION = {                                     ")
end
function postamble()
    print("}")
end

preamble()
main()
postamble()

