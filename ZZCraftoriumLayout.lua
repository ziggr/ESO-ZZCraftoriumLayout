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
    local unsequenced    = {}

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
            if i then
                sequenced[i] = item:ToTextLine()
            else
                table.insert(unsequenced, item:ToTextLine())
            end
        end
        seen_ct = seen_ct + 1

        furniture_id = GetNextPlacedHousingFurnitureId(furniture_id)
        loop_limit = loop_limit - 1
    end

    ZZCraftoriumLayout.savedVariables.get             = save_furniture
    ZZCraftoriumLayout.savedVariables.get_flat        = flat_furniture
    ZZCraftoriumLayout.savedVariables.get_sequenced   = sequenced
    ZZCraftoriumLayout.savedVariables.get_unsequenced = unsequenced

    d("ZZCraftoriumLayout seen:"..tostring(seen_ct)
            .."  saved:"..tostring(#save_furniture))
end


function ZZCraftoriumLayout.IsInteresting(item)
    local want = { "Rough Box, Boarded"
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
  "4620697946441608255 Rough Box, Boarded"
, "4620697946441423477 Blacksmithing Station (Alessia's Bulwark)"
, "4620697946441423479 Clothing Station (Alessia's Bulwark)"
, "4620697946441423481 Woodworking Station (Alessia's Bulwark)"

-- Run #2, lumpy manual after banker
, "4620697946441152019 Woodworking Station (Armor Master)"
, "4620697946441152018 Clothing Station (Armor Master)"
, "4620697946441146870 Blacksmithing Station (Armor Master)"
, "4620697946441605997 Rough Box, Boarded"

-- Run #3, from corner to stable, 4 sets
, "4620697946441606025 Rough Box, Boarded"
, "4620697946441423509 Blacksmithing Station (Ashen Grip)"
, "4620697946441423510 Clothing Station (Ashen Grip)"
, "4620697946441423511 Woodworking Station (Ashen Grip)"

, "4620697946441395843 Woodworking Station (Assassin's Guile)"
, "4620697946441395842 Clothing Station (Assassin's Guile)"
, "4620697946441395840 Blacksmithing Station (Assassin's Guile)"
, "4620697946441605987 Rough Box, Boarded"  -- index 16

, "4620697946441606000 Rough Box, Boarded"
, "4620697946441335509 Blacksmithing Station (Clever Alchemist)"
, "4620697946441335511 Clothing Station (Clever Alchemist)"
, "4620697946441335513 Woodworking Station (Clever Alchemist)"

, "4620697946441395831 Woodworking Station (Daedric Trickery)"
, "4620697946441395829 Clothing Station (Daedric Trickery)"
, "4620697946441395827 Blacksmithing Station (Daedric Trickery)"
, "4620697946441605999 Rough Box, Boarded"  -- index 24

-- Run #4, from stable to stairs, 2 sets
, "4620697946441606002 Rough Box, Boarded"
, "4620697946441423503 Blacksmithing Station (Death's Wind)"
, "4620697946441423505 Clothing Station (Death's Wind)"
, "4620697946441423507 Woodworking Station (Death's Wind)"

, "4620697946441335162 Woodworking Station (Eternal Hunt)"
, "4620697946441335160 Clothing Station (Eternal Hunt)"
, "4620697946441335158 Blacksmithing Station (Eternal Hunt)"
, "4620697946441606001 Rough Box, Boarded"  -- index 32

-- Run #5, upstairs to tree
, "4620697946441606004 Rough Box, Boarded"
, "4620697946441395846 Blacksmithing Station (Eyes of Mara)"
, "4620697946441395848 Clothing Station (Eyes of Mara)"
, "4620697946441395849 Woodworking Station (Eyes of Mara)"

-- Run #6, tree to outdent
, "4620697946441420111 Woodworking Station (Fortified Brass)"
, "4620697946441420110 Clothing Station (Fortified Brass)"
, "4620697946441420109 Blacksmithing Station (Fortified Brass)"
, "4620697946441606003 Rough Box, Boarded" -- index 40

-- Run #7, along back wall, 4 sets
, "4620697946441606016 Rough Box, Boarded"
, "4620697946441423483 Blacksmithing Station (Hist Bark)"
, "4620697946441423485 Clothing Station (Hist Bark)"
, "4620697946441423487 Woodworking Station (Hist Bark)"

, "4620697946441292182 Woodworking Station (Hunding's Rage)"
, "4620697946441292180 Clothing Station (Hunding's Rage)"
, "4620697946441292178 Blacksmithing Station (Hunding's Rage)"
, "4620697946441606005 Rough Box, Boarded"  -- index 48

, "4620697946441606018 Rough Box, Boarded"
, "4620697946441420073 Blacksmithing Station (Innate Axiom)"
, "4620697946441420075 Clothing Station (Innate Axiom)"
, "4620697946441420077 Woodworking Station (Innate Axiom)"

, "4620697946441291501 Woodworking Station (Kagrenac's Hope)"
, "4620697946441291500 Clothing Station (Kagrenac's Hope)"
, "4620697946441291499 Blacksmithing Station (Kagrenac's Hope)"
, "4620697946441606017 Rough Box, Boarded"  -- index 56

-- Run #8, across from wall, mirror run 7, 4 sets
, "4620697946441606022 Rough Box, Boarded"
, "4620697946441395790 Blacksmithing Station (Kvatch Gladiator)"
, "4620697946441395792 Clothing Station (Kvatch Gladiator)"
, "4620697946441395794 Woodworking Station (Kvatch Gladiator)"

, "4620697946441292194 Woodworking Station (Law of Julianos)"
, "4620697946441292192 Clothing Station (Law of Julianos)"
, "4620697946441292190 Blacksmithing Station (Law of Julianos)"
, "4620697946441606021 Rough Box, Boarded"  -- index 64

, "4620697946441606019 Rough Box, Boarded"
, "4620697946441292200 Blacksmithing Station (Magnus' Gift)"
, "4620697946441292201 Clothing Station (Magnus' Gift)"
, "4620697946441292202 Woodworking Station (Magnus' Gift)"

, "4620697946441420071 Woodworking Station (Mechanical Acuity)"
, "4620697946441420069 Clothing Station (Mechanical Acuity)"
, "4620697946441420067 Blacksmithing Station (Mechanical Acuity)"
, "4620697946441606020 Rough Box, Boarded"  -- index 72

-- Run #9, in front of stairs, 2 sets
, "4620697946441606024 Rough Box, Boarded"
, "4620697946441335142 Blacksmithing Station (Morkuldin)"
, "4620697946441335144 Clothing Station (Morkuldin)"
, "4620697946441335146 Woodworking Station (Morkuldin)"

, "4620697946441423499 Woodworking Station (Night's Silence)"
, "4620697946441423497 Clothing Station (Night's Silence)"
, "4620697946441423495 Blacksmithing Station (Night's Silence)"
, "4620697946441606023 Rough Box, Boarded"  -- index 80

-- Run #10, facing Azura
, "4620697946441607242 Rough Box, Boarded"
, "4620697946441335136 Blacksmithing Station (Night Mother's)"
, "4620697946441335138 Clothing Station (Night Mother's)"
, "4620697946441335140 Woodworking Station (Night Mother's)"

-- Run #11, balcony by Azura
, "4620697946441291113 Woodworking Station (Noble's Conquest)"
, "4620697946441291112 Clothing Station (Noble's Conquest)"
, "4620697946441291111 Blacksmithing Station (Noble's Conquest)"
, "4620697946441607241 Rough Box, Boarded"  -- index 88

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
, "4620697946441607243 Rough Box, Boarded" -- index 96

-- Run #13, finish run to pool path
, "4620697946441608214 Rough Box, Boarded"
, "4620697946441335515 Blacksmithing Station (Pelinal's Aptitude)"
, "4620697946441335517 Clothing Station (Pelinal's Aptitude)"
, "4620697946441335519 Woodworking Station (Pelinal's Aptitude)" -- index 100

-- Run #14, from pool path to corner. 2 sets.
-- MIGHT break this up later to properly mirror middle 2-of-4 sets
-- from run 3.
-- Begin the stuff not yet dragged over
, "4620697946441291120 Woodworking Station (Redistributor)"
, "4620697946441291119 Clothing Station (Redistributor)"
, "4620697946441291118 Blacksmithing Station (Redistributor)"
, "4620697946441608215 Rough Box, Boarded"

, "4620697946441608216 Rough Box, Boarded"
, "4620697946441335525 Blacksmithing Station (Seducer)"
, "4620697946441335527 Clothing Station (Seducer)"
, "4620697946441335529 Woodworking Station (Seducer)" -- index 108

-- Run #15, lumpy manual towards main entrance. 2 sets
, "4620697946441395838 Woodworking Station (Shacklebreaker)"
, "4620697946441395836 Clothing Station (Shacklebreaker)"
, "4620697946441395834 Blacksmithing Station (Shacklebreaker)"
, "4620697946441608217 Rough Box, Boarded"

, "4620697946441608218 Rough Box, Boarded"
, "4620697946441395852 Blacksmithing Station (Shalidor's Curse)"
, "4620697946441395851 Clothing Station (Shalidor's Curse)"
, "4620697946441395853 Woodworking Station (Shalidor's Curse)" -- index 116

-- Run #16, lumpy manual from main entrance to Transmute corner
, "4620697946441423475 Woodworking Station (Song of Lamae)"
, "4620697946441423473 Clothing Station (Song of Lamae)"
, "4620697946441423471 Blacksmithing Station (Song of Lamae)"
, "4620697946441608219 Rough Box, Boarded"

, "4620697946441608220 Rough Box, Boarded"
, "4620697946441422504 Blacksmithing Station (Spectre's Eye)"
, "4620697946441422506 Clothing Station (Spectre's Eye)"
, "4620697946441422508 Woodworking Station (Spectre's Eye)" -- index 124

-- Run #17, transmute corner to pool path. 2 sets
, "4620697946441395806 Woodworking Station (Tava's Favor)"
, "4620697946441395804 Clothing Station (Tava's Favor)"
, "4620697946441395802 Blacksmithing Station (Tava's Favor)"
, "4620697946441608221 Rough Box, Boarded"

, "4620697946441608222 Rough Box, Boarded"
, "4620697946441335533 Blacksmithing Station (Torug's Pact)"
, "4620697946441335534 Clothing Station (Torug's Pact)"
, "4620697946441335535 Woodworking Station (Torug's Pact)" -- index 132

-- Run #18, pool path to stairs. 3 sets.
-- break this up to better mirror.
, "4620697946441395822 Woodworking Station (Trial by Fire)"
, "4620697946441395820 Clothing Station (Trial by Fire)"
, "4620697946441395818 Blacksmithing Station (Trial by Fire)"
, "4620697946441608223 Rough Box, Boarded" -- index 140

, "4620697946441608224 Rough Box, Boarded"
, "4620697946441335168 Blacksmithing Station (Twice-Born Star)"
, "4620697946441335169 Clothing Station (Twice-Born Star)"
, "4620697946441335170 Woodworking Station (Twice-Born Star)"

, "4620697946441422484 Woodworking Station (Twilight's Embrace)"
, "4620697946441422482 Clothing Station (Twilight's Embrace)"
, "4620697946441422480 Blacksmithing Station (Twilight's Embrace)"
, "4620697946441608225 Rough Box, Boarded"

-- Run #19, stairs to grove path. 2 sets
, "4620697946441608226 Rough Box, Boarded"
, "4620697946441423459 Blacksmithing Station (Vampire's Kiss)"
, "4620697946441423461 Clothing Station (Vampire's Kiss)"
, "4620697946441423463 Woodworking Station (Vampire's Kiss)"

, "4620697946441395800 Woodworking Station (Varen's Legacy)"
, "4620697946441395798 Clothing Station (Varen's Legacy)"
, "4620697946441395796 Blacksmithing Station (Varen's Legacy)"
, "4620697946441608227 Rough Box, Boarded"

-- Run #20, grove path to Pirharri's corner. 4 sets
, "4620697946441608228 Rough Box, Boarded"
, "4620697946441422498 Blacksmithing Station (Way of the Arena)"
, "4620697946441422500 Clothing Station (Way of the Arena)"
, "4620697946441422502 Woodworking Station (Way of the Arena)"

, "4620697946441423493 Woodworking Station (Whitestrake's Retribution)"
, "4620697946441423491 Clothing Station (Whitestrake's Retribution)"
, "4620697946441423489 Blacksmithing Station (Whitestrake's Retribution)"
, "4620697946441608229 Rough Box, Boarded"

, "4620697946441608230 Rough Box, Boarded"
, "4620697946441422516 Blacksmithing Station (Willow's Path)"
, "4620697946441422517 Clothing Station (Willow's Path)"
, "4620697946441422518 Woodworking Station (Willow's Path)"

-- Summerset #1
, "4620697946441608231 Rough Box, Boarded"
, "4620697946441608244 Rough Box, Boarded"
, "4620697946441608245 Rough Box, Boarded"
, "4620697946441608246 Rough Box, Boarded"

-- Run #21, outfitter stairs
-- summerset #2
, "4620697946441608247 Rough Box, Boarded"
, "4620697946441608248 Rough Box, Boarded"
, "4620697946441608249 Rough Box, Boarded"
, "4620697946441608250 Rough Box, Boarded"

-- Run #22, banker stairs
-- Summerset #3
, "4620697946441608251 Rough Box, Boarded"
, "4620697946441608252 Rough Box, Boarded"
, "4620697946441608253 Rough Box, Boarded"
, "4620697946441608254 Rough Box, Boarded"

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
        -- d(msg)
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

-- Copy-and-paste positions from a spreadsheet.
ZZCraftoriumLayout.SET = {

  [001] = "57530 99893 19465"
, [002] = "56386 99852 19473"
, [003] = "56168 99784 19484"
, [004] = "56018 99778 19497"
, [005] = "55150 99820 19527"
, [006] = "54919 99820 19535"
, [007] = "54754 99805 19533"
, [008] = "54527 99772 19528"
, [009] = "53900 99753 19544"
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
, [025] = "53900 94285 19540"
, [026] = "53900 94090 19540"
, [027] = "53900 93866 19540"
, [028] = "53900 93664 19540"
, [029] = "53900 93266 19540"
, [030] = "53900 93027 19540"
, [031] = "53900 92832 19540"
, [032] = "53900 92608 19540"
, [033] = "53499 91600 19844"
, [034] = "53292 91600 19844"
, [035] = "53054 91600 19858"
, [036] = "52840 91600 19858"
, [037] = "52400 91419 19858"
, [038] = "52400 91165 19858"
, [039] = "52400 90981 19858"
, [040] = "52400 90720 19858"
, [041] = "52120 90408 19858"
, [042] = "52120 90196 19858"
, [043] = "52120 89952 19858"
, [044] = "52120 89732 19858"
, [045] = "52120 89300 19858"
, [046] = "52120 89040 19858"
, [047] = "52094 88828 19859"
, [048] = "52120 88583 19858"
, [049] = "52120 88151 19858"
, [050] = "52120 87938 19858"
, [051] = "52120 87695 19858"
, [052] = "52120 87475 19858"
, [053] = "52120 87043 19858"
, [054] = "52120 86782 19858"
, [055] = "52120 86570 19858"
, [056] = "52120 86326 19858"
, [057] = "52800 86307 19858"
, [058] = "52800 86519 19858"
, [059] = "52800 86763 19858"
, [060] = "52800 86983 19858"
, [061] = "52800 87415 19858"
, [062] = "52800 87675 19858"
, [063] = "52800 87888 19858"
, [064] = "52800 88132 19858"
, [065] = "52800 88564 19858"
, [066] = "52800 88777 19858"
, [067] = "52800 89020 19858"
, [068] = "52800 89240 19858"
, [069] = "52950 89672 19858"
, [070] = "52950 89933 19858"
, [071] = "52950 90145 19858"
, [072] = "52950 90389 19858"
, [073] = "53192 90815 19841"
, [074] = "53390 90815 19841"
, [075] = "53617 90815 19841"
, [076] = "53821 90815 19841"
, [077] = "54223 90815 19841"
, [078] = "54466 90815 19841"
, [079] = "54663 90815 19841"
, [080] = "54890 90815 19841"
, [081] = "55300 90832 19841"
, [082] = "55300 91055 19841"
, [083] = "55300 91311 19841"
, [084] = "55300 91542 19841"
, [085] = "55135 91800 19841"
, [086] = "54904 91800 19841"
, [087] = "54716 91800 19841"
, [088] = "54500 91800 19841"
, [089] = "54275 92634 19540"
, [090] = "54275 92807 19540"
, [091] = "54275 93053 19540"
, [092] = "54275 93255 19540"
, [093] = "54275 93653 19540"
, [094] = "54275 93892 19540"
, [095] = "54275 94066 19540"
, [096] = "54275 94312 19540"
, [097] = "54275 94725 19540"
, [098] = "54275 94982 19540"
, [099] = "54275 95277 19540"
, [100] = "54275 95542 19540"
, [101] = "54275 97020 19540"
, [102] = "54275 97262 19540"
, [103] = "54275 97437 19540"
, [104] = "54275 97685 19540"
, [105] = "54275 98086 19540"
, [106] = "54275 98261 19540"
, [107] = "54275 98510 19540"
, [108] = "54275 98714 19540"
, [109] = "54523 99314 19535"
, [110] = "54836 99334 19547"
, [111] = "55059 99281 19547"
, [112] = "55320 99281 19530"
, [113] = "55608 99283 19522"
, [114] = "55756 99278 19515"
, [115] = "55996 99299 19501"
, [116] = "56226 99292 19489"
, [117] = "57696 99234 19492"
, [118] = "58011 99241 19493"
, [119] = "58190 99217 19491"
, [120] = "58429 99232 19491"
, [121] = "58878 99250 19497"
, [122] = "59093 99248 19500"
, [123] = "59348 99239 19499"
, [124] = "59543 99240 19508"
, [125] = "60075 98725 19544"
, [126] = "60075 98483 19544"
, [127] = "60075 98286 19544"
, [128] = "60075 98060 19544"
, [129] = "60075 97658 19544"
, [130] = "60075 97461 19544"
, [131] = "60075 97235 19544"
, [132] = "60075 97031 19544"
, [133] = "60075 95726 19544"
, [134] = "60075 95478 19544"
, [135] = "60075 95290 19544"
, [136] = "60075 95054 19544"
, [137] = "60075 94285 19544"
, [138] = "60075 94090 19544"
, [139] = "60075 93866 19544"
, [140] = "60075 93664 19544"
, [141] = "60075 93266 19544"
, [142] = "60075 93027 19544"
, [143] = "60075 92832 19544"
, [144] = "60075 92608 19544"
, [145] = "60500 92584 19538"
, [146] = "60509 92763 19538"
, [147] = "60500 92989 19538"
, [148] = "60500 93184 19538"
, [149] = "60500 93568 19544"
, [150] = "60500 93800 19544"
, [151] = "60500 93989 19544"
, [152] = "60500 94205 19544"
, [153] = "60500 95356 19544"
, [154] = "60500 95620 19544"
, [155] = "60500 95922 19544"
, [156] = "60500 96195 19544"
, [157] = "60500 96975 19544"
, [158] = "60500 97217 19544"
, [159] = "60500 97414 19544"
, [160] = "60500 97641 19544"

}

-- Postamble -----------------------------------------------------------------

EVENT_MANAGER:RegisterForEvent( ZZCraftoriumLayout.name
                              , EVENT_ADD_ON_LOADED
                              , ZZCraftoriumLayout.OnAddOnLoaded
                              )

SLASH_COMMANDS["/clayget"] = ZZCraftoriumLayout.ScanNow
SLASH_COMMANDS["/clayset"] = ZZCraftoriumLayout.MoveAll



-- TODO
-- rotation
-- lamps

