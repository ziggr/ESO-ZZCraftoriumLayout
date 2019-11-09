dofile("data/ZZCraftoriumLayout.lua")

flat = ZZCraftoriumLayoutVars["Default"]["@ziggr"]["$AccountWide"]["get_flat"]

ITEM_TYPE = { "bs", "cl", "ww", "jw", "lamp", "lantern" }
local NAME_TO_TYPE = {
    ["Blacksmithing Station"]               = "bs"
,   ["Clothing Station"]                    = "cl"
,   ["Woodworking Station"]                 = "ww"
,   ["Jewelry Crafting Station"]            = "jw"
,   ["Common Lantern"]                      = "lantern"
,   ["Dark Elf Streetpost"]                 = "lamp"
,   ["Breton Sconce"]                       = "sc"  -- not output, do the wall sconces manually
}
function name_to_type(name)
    for k,v in pairs(NAME_TO_TYPE) do
        if string.find(name, k) then return v end
    end
    return nil
end

function msg(...)
    print(string.format(...))
end

function table_i_dump(t)
    for i,v in pairs(t) do
        msg("%2d %s", i, tostring(v))
    end
end
--                     -- All rough boxes have the same furniture_data_id
--                     -- so use unique_id instead. But I'm not sure if
--                     -- unique_id survives a relog or rezone. If not,
--                     -- furniture_data_id *is* sufficient, once we get
--                     -- unique Attuned Jewelry Stations.
-- return string.format( "%s %6d %6d %6d %5.3f %s"
--                  -- , Id64ToString(self.furniture_data_id)
--                     , Id64ToString(self.unique_id)
--                     , self.x
--                     , self.z
--                     , self.y
--                     , self.rotation
--                     , self.item_name
--                     )
-- [1] = "4620697946441146870  53789  98306  19530 151.150 Blacksmithing Station (Armor Master)",

DATA = {}
for i,line in ipairs(flat) do
    local m = { string.find(line, "(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s+([-0-9.]+)%s(.*)") }
    -- for k,v in ipairs(m) do print('"'..v..'"') end
    -- break
    local row = { unique_id = m[3]
                , x         = m[4]
                , z         = m[5]
                , y         = m[6]
                , rotation  = m[7]
                , item_name = m[8]
                }
    if not row.item_name then
        msg("Unknown item_name  line:%d \"%s\"", i, line)
        table_i_dump(m)
        break
    end
    row.item_type = name_to_type(m[8])
    if not row.item_type then
        msg("Unknown type  line:%d \"%s\"", i, row.item_name)
        table_i_dump(m)
        break
    end

    DATA[row.item_type] = DATA[row.item_type] or {}
    table.insert(DATA[row.item_type], row)
end

for _,item_type in ipairs(ITEM_TYPE) do
    local t = DATA[item_type]
    table.sort(t, function(a,b)
                    if a.item_name ~= b.item_name then
                        return a.item_name < b.item_name
                    end
                    return a.unique_id < b.unique_id
                  end )
    for _,row in ipairs(t) do
        msg("furn    %-7s  %s %s", item_type, row.unique_id, row.item_name)
    end
    msg("")
end
