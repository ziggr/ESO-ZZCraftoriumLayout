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

    local location_name  = GetPlayerLocationName()
    local save_furniture = {}
    local seen_ct        = 0

    local furniture_id = GetNextPlacedHousingFurnitureId(nil)
    local loop_limit   = 1000 -- avoid infinite loops in case GNPHFI() surprises us
    while furniture_id and 0 < loop_limit do
        local item = Item:FromFurnitureId(furniture_id)
        local store = item:ToStorage()
        if ZZCraftoriumLayout.IsInteresting(item) then
            table.insert(save_furniture, store)
        end
        seen_ct = seen_ct + 1

        furniture_id = GetNextPlacedHousingFurnitureId(furniture_id)
        loop_limit = loop_limit - 1
    end

    ZZCraftoriumLayout.savedVariables.get = save_furniture

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

-- Postamble -----------------------------------------------------------------

EVENT_MANAGER:RegisterForEvent( ZZCraftoriumLayout.name
                              , EVENT_ADD_ON_LOADED
                              , ZZCraftoriumLayout.OnAddOnLoaded
                              )

SLASH_COMMANDS["/clayget"] = ZZCraftoriumLayout.ScanNow

