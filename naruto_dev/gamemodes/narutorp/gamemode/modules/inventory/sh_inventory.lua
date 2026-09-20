--[[
    Module : inventaire (partagé)

    Données : char.inventory = { items = { kunai = 12 }, equipped = { tool = "kunai" } }
    Ajouter un objet : config/items.lua ou NRP.Inventory.Items:Register(id, def)
]]

NRP.Inventory = NRP.Inventory or {}
local Inv = NRP.Inventory

Inv.ACTION_USE = 1
Inv.ACTION_EQUIP = 2
Inv.ACTION_UNEQUIP = 3
Inv.ACTION_DROP = 4

Inv.Items = NRP.CreateRegistry("items", {
    defaults = {
        category = "misc", rarity = "common", weight = 0, stack = 99, price = 0,
        tradeable = true, droppable = true, description = "",
    },
    validate = function(def)
        if not isstring(def.name) then return false, "nom manquant" end
        if def.missionItem then
            def.tradeable = false
            def.droppable = false
        end
        if def.equip and not NRP.Config.InventorySettings.EquipSlots[def.equip.slot] then
            return false, "emplacement d'équipement inconnu"
        end
        return true
    end,
})

Inv.Items:RegisterAll(NRP.Config.Items)

NRP.Char.RegisterField("inventory", { type = "json", default = { items = {}, equipped = {} } })
NRP.Keys.Register("throw", { name = "Lancer l'outil équipé", default = KEY_H, order = 15 })

function Inv.Settings()
    return NRP.Config.InventorySettings
end

function Inv.GetData(ply)
    local data = NRP.Char.GetData(ply)
    return data and data.inventory
end

function Inv.Count(ply, id)
    local inv = Inv.GetData(ply)
    return inv and tonumber(inv.items[id]) or 0
end

function Inv.GetWeight(inv)
    local total = 0
    for id, qty in pairs(inv and inv.items or {}) do
        local def = Inv.Items:Get(id)
        if def then
            total = total + def.weight * qty
        end
    end
    return total
end

function Inv.StackCount(inv)
    local n = 0
    for _, qty in pairs(inv and inv.items or {}) do
        if qty > 0 then n = n + 1 end
    end
    return n
end

function Inv.GetRarity(def)
    return Inv.Settings().Rarities[def.rarity] or { name = def.rarity, color = color_white }
end

function Inv.IsUsable(def)
    return def.use ~= nil or def.learnJutsu ~= nil
end

-- Objets triés (catégorie, rareté, nom) pour l'affichage
function Inv.SortedEntries(inv)
    local out = {}
    for id, qty in pairs(inv and inv.items or {}) do
        local def = Inv.Items:Get(id)
        if def and qty > 0 then
            out[#out + 1] = { id = id, qty = qty, def = def }
        end
    end

    local cats = Inv.Settings().Categories
    local rarities = Inv.Settings().Rarities
    table.sort(out, function(a, b)
        local ca = cats[a.def.category] and cats[a.def.category].order or 99
        local cb = cats[b.def.category] and cats[b.def.category].order or 99
        if ca ~= cb then return ca < cb end
        local ra = rarities[a.def.rarity] and rarities[a.def.rarity].order or 0
        local rb = rarities[b.def.rarity] and rarities[b.def.rarity].order or 0
        if ra ~= rb then return ra > rb end
        return a.def.name < b.def.name
    end)
    return out
end

---------------------------------------------------------------------------
-- Boutiques
---------------------------------------------------------------------------

Inv.Shops = NRP.CreateRegistry("shops", {
    defaults = { items = {}, sellRatio = 0 },
    validate = function(def) return isstring(def.name), "nom manquant" end,
})
Inv.Shops:RegisterAll(NRP.Config.Shops)

function Inv.ShopSells(shop, itemId)
    return shop ~= nil and table.HasValue(shop.items, itemId)
end
