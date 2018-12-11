local cm =   1
local m  = 100

local RADIUS_START = 35 * m
local RADIUS_STEP  =  4 * m
local STATION_WIDTH = 2 * m

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

local CENTER = { x = 84446 * cm, z = 91337 * cm }
-- local CENTER = { x =     0 * cm, z =     0 * cm }
local TAU    = 2 * math.pi

function AddAngle(a,b)
    return (a + b) % TAU
end

function PlaceNextStation(radius, center_on_angle, station_width)
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
           , orient      = AddAngle(center_on_angle, TAU/2)
           , next_radius = radius - radius_step
           , next_angle  = AddAngle(center_on_angle, angular_width)
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
for i,v in ipairs(w) do
    print(string.format("[%d] '%s'",i,v))
end
            FURNITURE[row.type] = FURNITURE[row.type] or {}
            table.insert(FURNITURE[row.type], row )
        end
    end
end

function main()
    LoadFurniture()

    local angle  = TAU/4
    local radius = RADIUS_START

    local sequence = { "ww", "cl", "bs", "jw", "jw", "bs", "cl", "ww", "lamp" }
    local sequence_i = 1

    for i = 1, (47*4 + 47/2) do
        local station_type = sequence[sequence_i]
        sequence_i = sequence_i + 1
        if #sequence < sequence_i then sequence_i = 1 end

        local station = FURNITURE[station_type][1]
        table.remove(FURNITURE[station_type], 1)

        if not station then
            print(string.format("# Error: out of stations, i:%d", i))
            break
        end

        local r = PlaceNextStation(radius, angle, WIDTH[station_type])

        print(string.format( "%d\t%d\t%2.4f\t%d\t%s\t%s"
                           , r.x, r.z, r.orient
                           , station.id, station.type, station.name
                           ))

        angle  = r.next_angle
        radius = r.next_radius
    end
end

main()
