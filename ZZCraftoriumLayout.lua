ZZCraftoriumLayout = ZZCraftoriumLayout or {}
ZZCraftoriumLayout.name            = "ZZCraftoriumLayout"
ZZCraftoriumLayout.savedVarVersion = 1
ZZCraftoriumLayout.default = {
    house = {}
}
ZZCraftoriumLayout.unique_id_to_item = {}

                        -- Leave false most of the time to skip pointless
                        -- rotation/roundoff fiddling, set to true when you're
                        -- fighting rotation problems.
ZZCraftoriumLayout.force_rotation = false
-- Item ----------------------------------------------------------------------
--
-- The occupant of a placed housing slot. This is a single furnishing item.


local Item = {}
function Item:FromFurnitureId(furniture_id)
    local o = { furniture_id = furniture_id }

    local r = { GetPlacedHousingFurnitureInfo(furniture_id) }
    o.item_name             = r[1]
    o.texture_name          = r[2]
    o.furniture_data_id     = r[3]
    local furniture_data_id = r[3]

    o.quality           = GetPlacedHousingFurnitureQuality(furniture_id)
    o.link              = GetPlacedFurnitureLink(
                                furniture_id, LINK_STYLE_DEFAULT)
    o.collectible_id    = GetCollectibleIdFromFurnitureId(furniture_id)
    o.unique_id         = GetItemUniqueIdFromFurnitureId(furniture_id)

    r = { HousingEditorGetFurnitureWorldPosition(furniture_id) }
    o.x = r[1]
    o.y = r[2]
    o.z = r[3]

    r = { HousingEditorGetFurnitureWorldBounds(furniture_id) }
    o.x_min = r[1]
    o.y_min = r[2]
    o.z_min = r[3]
    o.x_max = r[4]
    o.y_max = r[5]
    o.z_max = r[6]

    r = { HousingEditorGetFurnitureOrientation(furniture_id) }
    o.rotation = r[2] / math.pi * 180

    setmetatable(o, self)
    self.__index = self
    return o
end

function Item.ToStorage(self)
    local store = {
          furniture_id = Id64ToString(self.furniture_data_id)
        , unique_id    = Id64ToString(self.unique_id)
        , item_name    = self.item_name
        , x            = self.x
        , y            = self.y
        , z            = self.z
        , x_min        = self.x_min
        , y_min        = self.y_min
        , z_min        = self.z_min
        , x_max        = self.x_max
        , y_max        = self.y_max
        , z_max        = self.z_max
        , rotation     = self.rotation
    }
    return store
end

function Item.ToTextLine(self)
                        -- All rough boxes have the same furniture_data_id
                        -- so use unique_id instead. But I'm not sure if
                        -- unique_id survives a relog or rezone. If not,
                        -- furniture_data_id *is* sufficient, once we get
                        -- unique Attuned Jewelry Stations.
    return string.format( "%s %6d %6d %6d %5.3f %s"
                     -- , Id64ToString(self.furniture_data_id)
                        , Id64ToString(self.unique_id)
                        , self.x
                        , self.z
                        , self.y
                        , self.rotation
                        , self.item_name
                        )
end

function max(a, b)
    if not a then return b end
    if not b then return a end
    return math.max(a, b)
end


function ZZCraftoriumLayout.ErrorIfNotHome()
    local okay = {
        [HOUSE_ID_LINCHAL_MANOR               or 46] = 1
    ,   [HOUSE_ID_COLDHARBOUR_SURREAL_ESTATE  or 47] = 1
    }
    local house_id = GetCurrentZoneHouseId()
    if not okay[house_id] then
        d("ZZCraftoriumLayout: not in one of Zig's big crafting houses. Exiting.")
        return true
    end
    return false
end


-- Fetch Inventory Data from the server ------------------------------------------
--
-- Write to savedVariables so that we can see furniture unique_id

function ZZCraftoriumLayout.ScanNow()
    if ZZCraftoriumLayout.ErrorIfNotHome() then return end

    local save_furniture    = {}
    local flat_furniture    = {}
    local unique_id_to_item = {}
    local seen_ct           = 0
    local furniture_id = GetNextPlacedHousingFurnitureId(nil)
    local loop_limit   = 1000 -- avoid infinite loops in case GNPHFI() surprises us
    while furniture_id and 0 < loop_limit do
        local item = Item:FromFurnitureId(furniture_id)
        local store = item:ToStorage()
        if ZZCraftoriumLayout.IsInteresting(item) then
            table.insert(save_furniture, store)
            table.insert(flat_furniture, item:ToTextLine())
            unique_id_to_item[Id64ToString(item.unique_id)] = item
        end
        seen_ct = seen_ct + 1

        furniture_id = GetNextPlacedHousingFurnitureId(furniture_id)
        loop_limit = loop_limit - 1
    end

    ZZCraftoriumLayout.unique_id_to_item              = unique_id_to_item
    ZZCraftoriumLayout.savedVariables.get             = save_furniture
    ZZCraftoriumLayout.savedVariables.get_flat        = flat_furniture

    d("ZZCraftoriumLayout seen:"..tostring(seen_ct)
            .."  saved:"..tostring(#save_furniture))
end


function ZZCraftoriumLayout.IsInteresting(item)
    local want = { "Jewelry Crafting Station"
                 , "Blacksmithing Station"
                 , "Clothing Station"
                 , "Woodworking Station"
                 , "Breton Sconce, Torch"
                 , "Common Lantern, Hanging"
                 , "Dark Elf Streetpost, Banner"
                 }
    for _, s in ipairs(want) do
        if string.find(item.item_name, s) then return true end
    end
    return false
end

-- move furniture ------------------------------------------------------------

local HR = {
  [HOUSING_REQUEST_RESULT_ALREADY_APPLYING_TEMPLATE           ] = "ALREADY_APPLYING_TEMPLATE"
, [HOUSING_REQUEST_RESULT_ALREADY_BEING_MOVED                 ] = "ALREADY_BEING_MOVED"
, [HOUSING_REQUEST_RESULT_ALREADY_SET_TO_MODE                 ] = "ALREADY_SET_TO_MODE"
, [HOUSING_REQUEST_RESULT_FURNITURE_ALREADY_SELECTED          ] = "FURNITURE_ALREADY_SELECTED"
, [HOUSING_REQUEST_RESULT_HIGH_IMPACT_COLLECTIBLE_PLACE_LIMIT ] = "HIGH_IMPACT_COLLECTIBLE_PLACE_LIMIT"
, [HOUSING_REQUEST_RESULT_HIGH_IMPACT_ITEM_PLACE_LIMIT        ] = "HIGH_IMPACT_ITEM_PLACE_LIMIT"
, [HOUSING_REQUEST_RESULT_HOME_SHOW_NOT_ENOUGH_PLACED         ] = "HOME_SHOW_NOT_ENOUGH_PLACED"
, [HOUSING_REQUEST_RESULT_INCORRECT_MODE                      ] = "INCORRECT_MODE"
, [HOUSING_REQUEST_RESULT_INVALID_TEMPLATE                    ] = "INVALID_TEMPLATE"
, [HOUSING_REQUEST_RESULT_INVENTORY_REMOVE_FAILED             ] = "INVENTORY_REMOVE_FAILED"
, [HOUSING_REQUEST_RESULT_IN_COMBAT                           ] = "IN_COMBAT"
, [HOUSING_REQUEST_RESULT_IN_SAFE_ZONE                        ] = "IN_SAFE_ZONE"
, [HOUSING_REQUEST_RESULT_IS_DEAD                             ] = "IS_DEAD"
, [HOUSING_REQUEST_RESULT_ITEM_REMOVE_FAILED                  ] = "ITEM_REMOVE_FAILED"
, [HOUSING_REQUEST_RESULT_ITEM_REMOVE_FAILED_INVENTORY_FULL   ] = "ITEM_REMOVE_FAILED_INVENTORY_FULL"
, [HOUSING_REQUEST_RESULT_ITEM_STOLEN                         ] = "ITEM_STOLEN"
, [HOUSING_REQUEST_RESULT_LISTED                              ] = "LISTED"
, [HOUSING_REQUEST_RESULT_LOW_IMPACT_COLLECTIBLE_PLACE_LIMIT  ] = "LOW_IMPACT_COLLECTIBLE_PLACE_LIMIT"
, [HOUSING_REQUEST_RESULT_LOW_IMPACT_ITEM_PLACE_LIMIT         ] = "LOW_IMPACT_ITEM_PLACE_LIMIT"
, [HOUSING_REQUEST_RESULT_MOVE_FAILED                         ] = "MOVE_FAILED"
, [HOUSING_REQUEST_RESULT_NOT_HOME_SHOW                       ] = "NOT_HOME_SHOW"
, [HOUSING_REQUEST_RESULT_NOT_IN_HOUSE                        ] = "NOT_IN_HOUSE"
, [HOUSING_REQUEST_RESULT_NO_DUPLICATES                       ] = "NO_DUPLICATES"
, [HOUSING_REQUEST_RESULT_NO_SUCH_FURNITURE                   ] = "NO_SUCH_FURNITURE"
, [HOUSING_REQUEST_RESULT_PERMISSION_FAILED                   ] = "PERMISSION_FAILED"
, [HOUSING_REQUEST_RESULT_PERSONAL_TEMP_ITEM_PLACE_LIMIT      ] = "PERSONAL_TEMP_ITEM_PLACE_LIMIT"
, [HOUSING_REQUEST_RESULT_PLACE_FAILED                        ] = "PLACE_FAILED"
, [HOUSING_REQUEST_RESULT_REMOVE_FAILED                       ] = "REMOVE_FAILED"
, [HOUSING_REQUEST_RESULT_REQUEST_IN_PROGRESS                 ] = "REQUEST_IN_PROGRESS"
, [HOUSING_REQUEST_RESULT_SET_STATE_FAILED                    ] = "SET_STATE_FAILED"
, [HOUSING_REQUEST_RESULT_SUCCESS                             ] = "SUCCESS"
, [HOUSING_REQUEST_RESULT_TOTAL_TEMP_ITEM_PLACE_LIMIT         ] = "TOTAL_TEMP_ITEM_PLACE_LIMIT"
, [HOUSING_REQUEST_RESULT_UNKNOWN_FAILURE                     ] = "UNKNOWN_FAILURE"
}

-- from http://lua-users.org/wiki/SplitJoin
local function split(str,pat)
  local tbl={}
  str:gsub(pat,function(x) tbl[#tbl+1]=x end)
  return tbl
end


-- Use positions from script/parser ------------------------------------------

local function zzerror(s)
    d("|cFF3333ZZCraftoriumLayout error: "..s.."|r")
end

local function id4(unique_id)
    return unique_id:sub(#unique_id - 3)
end

local MOVED_INDEX = 0
local function next_moved_index()
    MOVED_INDEX = 1 + MOVED_INDEX
    return MOVED_INDEX
end

-- close enough, don't waste time moving.
local function equ(a,b)
    return math.abs(a-b) < 2
end

function ZZCraftoriumLayout.MaybeMoveOne2(args)
    local item = ZZCraftoriumLayout.unique_id_to_item[args.unique_id]
    if not item then
        return zzerror(string.format("missing furniture unique_id:'%s'  %s %d"
                    , args.unique_id, args.station, args.station_index or 0))
    end
    if item.moved then
        return zzerror(string.format("furniture moved twice: %s"
                                    , Id64ToString(args.unique_id)))
    end

                        -- Already in position? Nothing to do.
    if      args.x == item.x
        and args.z == item.z
        and args.y == item.y
        and ((not ZZCraftoriumLayout.force_rotation) or equ(args.rotation, item.rotation))
        then

        ZZCraftoriumLayout.skip_run_ct = 1 + (ZZCraftoriumLayout.skip_run_ct or 0)
        local msg = string.format("|c999999Skipping: already in position x:%d,z:%d  id:%s %s|r"
            , item.x
            , item.z
            , id4(Id64ToString(item.unique_id))
            , item.item_name
            )
        if ZZCraftoriumLayout.skip_run_ct < 3 then
            d(msg)
        elseif ZZCraftoriumLayout.skip_run_ct == 3 then
            d("|c999999...|r")
        end
        item.moved = "skipped"
        item.moved_index = next_moved_index()
        return
    end
    ZZCraftoriumLayout.skip_run_ct = 0

    args.item = item
    table.insert(ZZCraftoriumLayout.move_queue, args)
end

local white = "|cFFFFFF"
local grey  = "|c999999"

local function numstr(a,b)
    local color = white
    local diff = math.abs(a-b)
    if (diff < 2) then color = grey end
    return color .. string.format("%d",a) ..grey
         , color .. string.format("%d",b) ..grey
end
local function numstrdeg(a,b)
    if a < 0 then a = a + 360 end
    if b < 0 then b = b + 360 end
    return numstr(a,b)
end

function ZZCraftoriumLayout.MoveOne(args)
    local r = HousingEditorRequestChangePositionAndOrientation(
                      args.item.furniture_id
                    , args.x
                    , args.y
                    , args.z
                    , 0        -- pitch
                    , (args.rotation or 0) * math.pi / 180
                    , 0        -- roll
                    )
    args.item.moved = "moved"
    args.item.moved_index = next_moved_index()
    local result_text = HR[r] or tostring(r)

    local fmt = grey.."Moving from x:%s,z:%s,y:%s,rot:%s ->"
                              .." x:%s,z:%s,y:%s,rot:%s result:%s %s"

    local x1  , x2   = numstr   (args.item.x            , args.x            )
    local z1  , z2   = numstr   (args.item.z            , args.z            )
    local y1  , y2   = numstr   (args.item.y            , args.y            )
    local rot1, rot2 = numstrdeg(args.item.rotation or 0, args.rotation or 0)
    local msg = string.format(fmt
                    , x1, z1, y1, rot1
                    , x2, z2, y2, rot2
                    , tostring(result_text)
                    , args.item.item_name
                    )
    d(msg)
end

-- Moving too many items at once gets you insta-kicked for message spam.
-- Call this with a delay between bursts.
function ZZCraftoriumLayout.MoveQueued()
    if #ZZCraftoriumLayout.move_queue <= 0 then
        ZZCraftoriumLayout.MoveDone()
        return
    end
    local tail = table.remove(ZZCraftoriumLayout.move_queue, #ZZCraftoriumLayout.move_queue)
    ZZCraftoriumLayout.MoveOne(tail)
    zo_callLater(ZZCraftoriumLayout.MoveQueued, 200)
end

function ZZCraftoriumLayout.MoveAll2()
    if ZZCraftoriumLayout.ErrorIfNotHome() then return end
    ZZCraftoriumLayout.skip_run_ct = 0
    ZZCraftoriumLayout.move_queue = {}

                        -- Scan first to gather each existing furniture's
                        -- unique_id. There is no string-to-id64 conversion,
                        -- so we have to go from i64->string and then build
                        -- a lookup table.
    ZZCraftoriumLayout.ScanNow()

local ENOUGH = 2000
    for _,row in ipairs(ZZCraftoriumLayout.POSITION) do
ENOUGH = ENOUGH - 1
if ENOUGH <= 0 then break end
        local w = split(row,"%S+")
        local args = {
                     ['unique_id'    ] =          w[1]
                   , ['x'            ] = tonumber(w[2])
                   , ['z'            ] = tonumber(w[3])
                   , ['y'            ] = tonumber(w[4])
                   , ['rotation'     ] = tonumber(w[5])
                   , ['station'      ] =          w[6]
                   , ['station_index'] = tonumber(w[7])
                   }
        ZZCraftoriumLayout.MaybeMoveOne2(args)
    end
    ZZCraftoriumLayout.MoveQueued()
end

function ZZCraftoriumLayout.MoveDone()
                        -- Collect unmoved items into another saved_variables
                        -- bucket for later movement
    local unmoved = {}
    local moved = {}
    for unique_id, item in pairs(ZZCraftoriumLayout.unique_id_to_item) do
        if not item.moved then
            table.insert(unmoved, item)
        else
            table.insert(moved, item)
        end
    end
    table.sort(unmoved, function(a,b) return a.item_name < b.item_name end )
    table.sort(  moved, function(a,b)
                            if a.item_name == b.item_name then
                                return a.moved_index < b.moved_index
                            end
                            return a.item_name < b.item_name
                        end )
    local unmoved_flat = {}
    local   moved_flat = {}
    for _,item in ipairs(unmoved) do
        table.insert(unmoved_flat, item:ToTextLine())
    end
    for _,item in ipairs(moved) do
        table.insert(moved_flat, item:ToTextLine())
    end
    ZZCraftoriumLayout.savedVariables.unmoved = unmoved_flat
    ZZCraftoriumLayout.savedVariables.moved   = moved_flat
end

-- Init ----------------------------------------------------------------------

function ZZCraftoriumLayout.OnAddOnLoaded(event, addonName)
    if addonName ~= ZZCraftoriumLayout.name then return end
    ZZCraftoriumLayout:Initialize()
end

function ZZCraftoriumLayout:Initialize()

    self.savedVariables = ZO_SavedVars:NewAccountWide(
                              "ZZCraftoriumLayoutVars"
                            , self.savedVarVersion
                            , nil
                            , self.default
                            )
end

-- Postamble -----------------------------------------------------------------

EVENT_MANAGER:RegisterForEvent( ZZCraftoriumLayout.name
                              , EVENT_ADD_ON_LOADED
                              , ZZCraftoriumLayout.OnAddOnLoaded
                              )

SLASH_COMMANDS["/clayget"] = ZZCraftoriumLayout.ScanNow
SLASH_COMMANDS["/clayset"] = ZZCraftoriumLayout.MoveAll2
