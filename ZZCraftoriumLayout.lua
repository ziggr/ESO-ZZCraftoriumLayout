local LAM2 = LibStub("LibAddonMenu-2.0")

local ZZCraftoriumLayout = {}
ZZCraftoriumLayout.name            = "ZZCraftoriumLayout"
ZZCraftoriumLayout.version         = "3.3.1"
ZZCraftoriumLayout.savedVarVersion = 1
ZZCraftoriumLayout.default = {
    house = {}
}

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
    }
    return store
end

function Item.ToTextLine(self)
                        -- All rough boxes have the same furniture_data_id
                        -- so use unique_id instead. But I'm not sure if
                        -- unique_id survives a relog or rezone. If not,
                        -- furniture_data_id *is* sufficient, once we get
                        -- unique Attuned Jewelry Stations.
    return string.format( "%s %6d %6d %6d %s"
                     -- , Id64ToString(self.furniture_data_id)
                        , Id64ToString(self.unique_id)
                        , self.x
                        , self.z
                        , self.y
                        , self.item_name
                        )
end

function max(a, b)
    if not a then return b end
    if not b then return a end
    return math.max(a, b)
end

-- Init ----------------------------------------------------------------------

function ZZCraftoriumLayout.OnAddOnLoaded(event, addonName)
    if addonName ~= ZZCraftoriumLayout.name then return end
    if not ZZCraftoriumLayout.version then return end
    if not ZZCraftoriumLayout.default then return end
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

-- Fetch Inventory Data from the server ------------------------------------------

function ZZCraftoriumLayout.ScanNow()
    local HOUSE_ID_LINCHAL_MANOR      = 46
    local house_id = GetCurrentZoneHouseId()
    if not (house_id and HOUSE_ID_LINCHAL_MANOR == house_id) then
        d("ZZCraftoriumLayout: not in the Craftorium. Exiting.")
        return
    end

    local save_furniture = {}
    local flat_furniture = {}
    local sequenced      = {}

    local seen_ct        = 0

    local furniture_id = GetNextPlacedHousingFurnitureId(nil)
    local loop_limit   = 1000 -- avoid infinite loops in case GNPHFI() surprises us
    while furniture_id and 0 < loop_limit do
        local item = Item:FromFurnitureId(furniture_id)
        local store = item:ToStorage()
        if ZZCraftoriumLayout.IsInteresting(item) then
            table.insert(save_furniture, store)
            table.insert(flat_furniture, item:ToTextLine())
            local i = ZZCraftoriumLayout.ToSequenceIndex(item)
            if i then sequenced[i] = item:ToTextLine() end
        end
        seen_ct = seen_ct + 1

        furniture_id = GetNextPlacedHousingFurnitureId(furniture_id)
        loop_limit = loop_limit - 1
    end

    ZZCraftoriumLayout.savedVariables.get           = save_furniture
    ZZCraftoriumLayout.savedVariables.get_flat      = flat_furniture
    ZZCraftoriumLayout.savedVariables.get_sequenced = sequenced

    d("ZZCraftoriumLayout seen:"..tostring(seen_ct)
            .."  saved:"..tostring(#save_furniture))
end


function ZZCraftoriumLayout.IsInteresting(item)
    local want = { "Rough Box, Boarded"
                 , "Blacksmithing Station"
                 , "Clothing Station"
                 , "Woodworking Station"
                 }
    for _, s in ipairs(want) do
        if string.find(item.item_name, s) then return true end
    end
    return false
end

function ZZCraftoriumLayout.ToSequenceIndex(item)
    local id = Id64ToString(item.unique_id)
    for index,s in ipairs(ZZCraftoriumLayout.SEQUENCE) do
        if string.find(s,id) then return index end
    end
    return nil
end

-- Sequence ------------------------------------------------------------------

local JW = "JW"
local BS = "BS"
local CL = "CL"
local WW = "WW"

ZZCraftoriumLayout.SEQUENCE = {
-- Run #1, lumpy manual by banker
  "4620697946441605998 Rough Box, Boarded"
, "4620697946441423477 Blacksmithing Station (Alessia's Bulwark)"
, "4620697946441423479 Clothing Station (Alessia's Bulwark)"
, "4620697946441423481 Woodworking Station (Alessia's Bulwark)"

-- Run #2, lumpy manual after banker
, "4620697946441152019 Woodworking Station (Armor Master)"
, "4620697946441152018 Clothing Station (Armor Master)"
, "4620697946441146870 Blacksmithing Station (Armor Master)"
, "4620697946441606006 Rough Box, Boarded"

-- Run #3, from corner to stable, 4 sets
, "4620697946441605997 Rough Box, Boarded"
, "4620697946441423509 Blacksmithing Station (Ashen Grip)"
, "4620697946441423510 Clothing Station (Ashen Grip)"
, "4620697946441423511 Woodworking Station (Ashen Grip)"

, "4620697946441395843 Woodworking Station (Assassin's Guile)"
, "4620697946441395842 Clothing Station (Assassin's Guile)"
, "4620697946441395840 Blacksmithing Station (Assassin's Guile)"
, "4620697946441605987 Rough Box, Boarded"

, "4620697946441606000 Rough Box, Boarded"
, "4620697946441335509 Blacksmithing Station (Clever Alchemist)"
, "4620697946441335511 Clothing Station (Clever Alchemist)"
, "4620697946441335513 Woodworking Station (Clever Alchemist)"

, "4620697946441395831 Woodworking Station (Daedric Trickery)"
, "4620697946441395829 Clothing Station (Daedric Trickery)"
, "4620697946441395827 Blacksmithing Station (Daedric Trickery)"
, "4620697946441605999 Rough Box, Boarded"

-- Run #4, from stable to stairs, 2 sets
, "4620697946441606002 Rough Box, Boarded"
, "4620697946441423503 Blacksmithing Station (Death's Wind)"
, "4620697946441423505 Clothing Station (Death's Wind)"
, "4620697946441423507 Woodworking Station (Death's Wind)"

, "4620697946441335162 Woodworking Station (Eternal Hunt)"
, "4620697946441335160 Clothing Station (Eternal Hunt)"
, "4620697946441335158 Blacksmithing Station (Eternal Hunt)"
, "4620697946441606001 Rough Box, Boarded"

-- Run #5, upstairs to tree
, "4620697946441606004 Rough Box, Boarded"
, "4620697946441395846 Blacksmithing Station (Eyes of Mara)"
, "4620697946441395848 Clothing Station (Eyes of Mara)"
, "4620697946441395849 Woodworking Station (Eyes of Mara)"

-- Run #6, tree to outdent
, "4620697946441420111 Woodworking Station (Fortified Brass)"
, "4620697946441420110 Clothing Station (Fortified Brass)"
, "4620697946441420109 Blacksmithing Station (Fortified Brass)"
, "4620697946441606003 Rough Box, Boarded"

-- Run #7, along back wall, 4 sets
, "4620697946441606016 Rough Box, Boarded"
, "4620697946441423483 Blacksmithing Station (Hist Bark)"
, "4620697946441423485 Clothing Station (Hist Bark)"
, "4620697946441423487 Woodworking Station (Hist Bark)"

, "4620697946441292182 Woodworking Station (Hunding's Rage)"
, "4620697946441292180 Clothing Station (Hunding's Rage)"
, "4620697946441292178 Blacksmithing Station (Hunding's Rage)"
, "4620697946441606005 Rough Box, Boarded"

, "4620697946441606018 Rough Box, Boarded"
, "4620697946441420073 Blacksmithing Station (Innate Axiom)"
, "4620697946441420075 Clothing Station (Innate Axiom)"
, "4620697946441420077 Woodworking Station (Innate Axiom)"

, "4620697946441291501 Woodworking Station (Kagrenac's Hope)"
, "4620697946441291500 Clothing Station (Kagrenac's Hope)"
, "4620697946441291499 Blacksmithing Station (Kagrenac's Hope)"
, "4620697946441606017 Rough Box, Boarded"

-- Run #8, across from wall, mirror run 7, 4 sets
, "4620697946441606022 Rough Box, Boarded"
, "4620697946441395790 Blacksmithing Station (Kvatch Gladiator)"
, "4620697946441395792 Clothing Station (Kvatch Gladiator)"
, "4620697946441395794 Woodworking Station (Kvatch Gladiator)"

, "4620697946441292194 Woodworking Station (Law of Julianos)"
, "4620697946441292192 Clothing Station (Law of Julianos)"
, "4620697946441292190 Blacksmithing Station (Law of Julianos)"
, "4620697946441606021 Rough Box, Boarded"

, "4620697946441606019 Rough Box, Boarded"
, "4620697946441292200 Blacksmithing Station (Magnus' Gift)"
, "4620697946441292201 Clothing Station (Magnus' Gift)"
, "4620697946441292202 Woodworking Station (Magnus' Gift)"

, "4620697946441420071 Woodworking Station (Mechanical Acuity)"
, "4620697946441420069 Clothing Station (Mechanical Acuity)"
, "4620697946441420067 Blacksmithing Station (Mechanical Acuity)"
, "4620697946441606020 Rough Box, Boarded"

-- Run #9, in front of stairs, 2 sets
, "4620697946441606024 Rough Box, Boarded"
, "4620697946441335142 Blacksmithing Station (Morkuldin)"
, "4620697946441335144 Clothing Station (Morkuldin)"
, "4620697946441335146 Woodworking Station (Morkuldin)"

, "4620697946441423499 Woodworking Station (Night's Silence)"
, "4620697946441423497 Clothing Station (Night's Silence)"
, "4620697946441423495 Blacksmithing Station (Night's Silence)"
, "4620697946441606023 Rough Box, Boarded"

-- Run #10, facing Azura
, "4620697946441607242 Rough Box, Boarded"
, "4620697946441335136 Blacksmithing Station (Night Mother's)"
, "4620697946441335138 Clothing Station (Night Mother's)"
, "4620697946441335140 Woodworking Station (Night Mother's)"

-- Run #11, balcony by Azura
, "4620697946441291113 Woodworking Station (Noble's Conquest)"
, "4620697946441291112 Clothing Station (Noble's Conquest)"
, "4620697946441291111 Blacksmithing Station (Noble's Conquest)"
, "4620697946441607241 Rough Box, Boarded"

-- Run #12, downstairs, partway to pool path. Mirror run 4. 2 sets
-- Run stops 1 set short to allow this 2-set run to properly mirror
-- the 2-set run 4.
, "4620697946441608213 Rough Box, Boarded"
, "4620697946441422510 Blacksmithing Station (Oblivion's Foe)"
, "4620697946441422512 Clothing Station (Oblivion's Foe)"
, "4620697946441422514 Woodworking Station (Oblivion's Foe)"

, "4620697946441291496 Woodworking Station (Orgnum's Scales)"
, "4620697946441291494 Clothing Station (Orgnum's Scales)"
, "4620697946441291492 Blacksmithing Station (Orgnum's Scales)"
, "4620697946441607243 Rough Box, Boarded"

-- Run #13, finish run to pool path
, "4620697946441608214 Rough Box, Boarded"
, "4620697946441335515 Blacksmithing Station (Pelinal's Aptitude)"
, "4620697946441335517 Clothing Station (Pelinal's Aptitude)"
, "4620697946441335519 Woodworking Station (Pelinal's Aptitude)"

} -- END OF SEQUENCE FOR NOW
local SEQUENCE_TODO = {
-- Run #14, from pool path to corner. 2 sets.
-- MIGHT break this up later to properly mirror middle 2-of-4 sets
-- from run 3.
-- Begin the stuff not yet dragged over
  "4620697946441291120 Woodworking Station (Redistributor)"
, "4620697946441291119 Clothing Station (Redistributor)"
, "4620697946441291118 Blacksmithing Station (Redistributor)"

, "4620697946441335525 Blacksmithing Station (Seducer)"
, "4620697946441335527 Clothing Station (Seducer)"
, "4620697946441335529 Woodworking Station (Seducer)"

-- Run #15, lumpy manual towards main entrance. 2 sets
, "4620697946441395838 Woodworking Station (Shacklebreaker)"
, "4620697946441395836 Clothing Station (Shacklebreaker)"
, "4620697946441395834 Blacksmithing Station (Shacklebreaker)"

, "4620697946441395852 Blacksmithing Station (Shalidor's Curse)"
, "4620697946441395851 Clothing Station (Shalidor's Curse)"
, "4620697946441395853 Woodworking Station (Shalidor's Curse)"

-- Run #16, lumpy manual from main entrance to Transmute corner
, "4620697946441423475 Woodworking Station (Song of Lamae)"
, "4620697946441423473 Clothing Station (Song of Lamae)"
, "4620697946441423471 Blacksmithing Station (Song of Lamae)"

, "4620697946441422504 Blacksmithing Station (Spectre's Eye)"
, "4620697946441422506 Clothing Station (Spectre's Eye)"
, "4620697946441422508 Woodworking Station (Spectre's Eye)"

-- Run #17, transmute corner to pool path. 2 sets
, "4620697946441395806 Woodworking Station (Tava's Favor)"
, "4620697946441395804 Clothing Station (Tava's Favor)"
, "4620697946441395802 Blacksmithing Station (Tava's Favor)"

, "4620697946441335533 Blacksmithing Station (Torug's Pact)"
, "4620697946441335534 Clothing Station (Torug's Pact)"
, "4620697946441335535 Woodworking Station (Torug's Pact)"

-- Run #18, pool path to stairs. 3 sets.
-- break this up to better mirror.
, "4620697946441395822 Woodworking Station (Trial by Fire)"
, "4620697946441395820 Clothing Station (Trial by Fire)"
, "4620697946441395818 Blacksmithing Station (Trial by Fire)"

, "4620697946441335168 Blacksmithing Station (Twice-Born Star)"
, "4620697946441335169 Clothing Station (Twice-Born Star)"
, "4620697946441335170 Woodworking Station (Twice-Born Star)"

, "4620697946441422484 Woodworking Station (Twilight's Embrace)"
, "4620697946441422482 Clothing Station (Twilight's Embrace)"
, "4620697946441422480 Blacksmithing Station (Twilight's Embrace)"

-- Run #19, stairs to grove path. 2 sets
, "4620697946441423459 Blacksmithing Station (Vampire's Kiss)"
, "4620697946441423461 Clothing Station (Vampire's Kiss)"
, "4620697946441423463 Woodworking Station (Vampire's Kiss)"

, "4620697946441395800 Woodworking Station (Varen's Legacy)"
, "4620697946441395798 Clothing Station (Varen's Legacy)"
, "4620697946441395796 Blacksmithing Station (Varen's Legacy)"

-- Run #20, grove path to Pirharri's corner. 4 sets
, "4620697946441422498 Blacksmithing Station (Way of the Arena)"
, "4620697946441422500 Clothing Station (Way of the Arena)"
, "4620697946441422502 Woodworking Station (Way of the Arena)"

, "4620697946441423493 Woodworking Station (Whitestrake's Retribution)"
, "4620697946441423491 Clothing Station (Whitestrake's Retribution)"
, "4620697946441423489 Blacksmithing Station (Whitestrake's Retribution)"

, "4620697946441422516 Blacksmithing Station (Willow's Path)"
, "4620697946441422517 Clothing Station (Willow's Path)"
, "4620697946441422518 Woodworking Station (Willow's Path)"

-- Summerset #1

-- Run #21, outfitter stairs
-- summerset #2

-- Run #22, banker stairs
-- Summerset #3

}

-- Copy-and-paste positions from a spreadsheet.
ZZCraftoriumLayout.SET = {

  [009] = "53900 99753 19544"
, [010] = "53900 99556 19544"
, [011] = "53900 99330 19544"
, [012] = "53900 99126 19544"
, [013] = "53900 98725 19544"
, [014] = "53900 98483 19544"
, [015] = "53900 98286 19544"
, [016] = "53900 98060 19544"
, [017] = "53900 97658 19544"
, [018] = "53900 97461 19544"
, [019] = "53900 97235 19544"
, [020] = "53900 97031 19544"
, [021] = "53900 96630 19544"
, [022] = "53900 96388 19544"
, [023] = "53900 96191 19544"
, [024] = "53900 95965 19544"

}

function ZZCraftoriumLayout.MoveAll()
    local HOUSE_ID_LINCHAL_MANOR      = 46
    local house_id = GetCurrentZoneHouseId()
    if not (house_id and HOUSE_ID_LINCHAL_MANOR == house_id) then
        d("ZZCraftoriumLayout: not in the Craftorium. Exiting.")
        return
    end

    local furniture_id = GetNextPlacedHousingFurnitureId(nil)
    local loop_limit   = 1000 -- avoid infinite loops in case GNPHFI() surprises us
    while furniture_id and 0 < loop_limit do
        local item = Item:FromFurnitureId(furniture_id)
        local store = item:ToStorage()
        if ZZCraftoriumLayout.IsInteresting(item) then
            ZZCraftoriumLayout.MaybeMoveOne(item)
        end

        furniture_id = GetNextPlacedHousingFurnitureId(furniture_id)
        loop_limit = loop_limit - 1
    end
end

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

function ZZCraftoriumLayout.MaybeMoveOne(item)
                        -- Is this a station that has been assigned
                        -- an index in our list of coordinates?
    local i = ZZCraftoriumLayout.ToSequenceIndex(item)
    if not i then return end

                        -- Fetch coordinates for this index. Eventually
                        -- all assigned indices will have corresponding
                        -- coordinates, but while we develop/debug this
                        -- addon, many won't. That's okay. Skip the unworthy.
    local set_line = ZZCraftoriumLayout.SET[i]
    if not set_line then return end

    -- d("set_line:"..tostring(set_line))
    local w = split(set_line,"%S+")
    -- d(w)
    local want_coords = { x = tonumber(w[1])
                        , z = tonumber(w[2])
                        , y = tonumber(w[3])
                        }

    -- d("want_coords  x:"..tostring(want_coords.x).."  z:"..tostring(want_coords.z))
    if not want_coords.x and want_coords.z then
        d("ZZCraftoriumLayout: cannot parse SET["..tonumber(i).."]"
          .." '"..tostring(set_line).."'")
        return
    end

                        -- Already in position, nothing to do.
                        -- Intentionally ignoring Y here. If the station
                        -- is already in x/z position, Zig might have manually
                        -- futzed with y-position to touch the local surface.
                        -- No need to un-futz here.
    if      want_coords.x == item.x
        and want_coords.z == item.z then
        local msg = string.format("Skipping: already in position x:%d,z:%d  %s"
            , item.x
            , item.z
            , item.item_name
            )
        d(msg)
        return
    end


    local r = HousingEditorRequestChangePosition(
                      item.furniture_id
                    , want_coords.x
                    , want_coords.y
                    , want_coords.z
                    )
    local result_text = HR[r] or tostring(r)
    local msg = string.format("Moving from x:%d,z:%d -> x:%d,z:%d result:%s  %s"
                    , item.x
                    , item.z
                    , want_coords.x
                    , want_coords.z
                    , tostring(result_text)
                    , item.item_name
                    )
    d(msg)
end


-- Postamble -----------------------------------------------------------------

EVENT_MANAGER:RegisterForEvent( ZZCraftoriumLayout.name
                              , EVENT_ADD_ON_LOADED
                              , ZZCraftoriumLayout.OnAddOnLoaded
                              )

SLASH_COMMANDS["/clayget"] = ZZCraftoriumLayout.ScanNow
SLASH_COMMANDS["/clayset"] = ZZCraftoriumLayout.MoveAll

