--[[
    Module : inventaire (serveur)

        NRP.Inventory.Give(ply, "kunai", 5)      -> quantité réellement donnée
        NRP.Inventory.Take(ply, "kunai", 1)      -> bool (tout ou rien)
        NRP.Inventory.Has(ply, "kunai", 3)
        NRP.Inventory.Use / Equip / Unequip / Drop
        NRP.Inventory.RemoveMissionItems(ply)

    Toutes les actions client passent par "NRP.ItemAction" et sont revalidées ici.
]]

local Inv = NRP.Inventory
local Char = NRP.Char
local CD = NRP.Cooldown

local function Touch(ply)
    Char.Touch(ply, "inventory")
end

local function Data(ply)
    return ply.NRPChar and ply.NRPChar.inventory
end

---------------------------------------------------------------------------
-- Base
---------------------------------------------------------------------------

function Inv.Has(ply, id, qty)
    return Inv.Count(ply, id) >= (qty or 1)
end

function Inv.Give(ply, id, qty, silent)
    local inv = Data(ply)
    local def = Inv.Items:Get(id)
    qty = math.floor(tonumber(qty) or 1)
    if not inv or not def or qty <= 0 then return 0 end

    local current = tonumber(inv.items[id]) or 0
    if current == 0 and Inv.StackCount(inv) >= Inv.Settings().MaxStacks then
        if not silent then NRP.Notify(ply, "Inventaire plein.", NRP.NOTIFY_ERROR) end
        return 0
    end

    local given = math.min(qty, def.stack - current)
    if given <= 0 then
        if not silent then NRP.Notify(ply, "Vous ne pouvez pas porter plus de " .. def.name .. ".", NRP.NOTIFY_ERROR) end
        return 0
    end

    inv.items[id] = current + given
    Touch(ply)
    Inv.RefreshWeight(ply)

    if not silent then
        NRP.Notify(ply, "+" .. given .. " " .. def.name, NRP.NOTIFY_SUCCESS, 2)
    end
    hook.Run("NRP.ItemGiven", ply, id, given)
    return given
end

function Inv.Take(ply, id, qty)
    local inv = Data(ply)
    qty = math.floor(tonumber(qty) or 1)
    if not inv or qty <= 0 then return false end

    local current = tonumber(inv.items[id]) or 0
    if current < qty then return false end

    local left = current - qty
    inv.items[id] = left > 0 and left or nil

    if left <= 0 then
        for slot, equipped in pairs(inv.equipped) do
            if equipped == id then
                inv.equipped[slot] = nil
                Inv.RefreshEquipment(ply)
            end
        end
    end

    Touch(ply)
    Inv.RefreshWeight(ply)
    hook.Run("NRP.ItemTaken", ply, id, qty)
    return true
end

function Inv.RemoveMissionItems(ply, onlyId)
    local inv = Data(ply)
    if not inv then return end
    for id, qty in pairs(table.Copy(inv.items)) do
        local def = Inv.Items:Get(id)
        if def and def.missionItem and (not onlyId or onlyId == id) then
            Inv.Take(ply, id, qty)
        end
    end
end

---------------------------------------------------------------------------
-- Équipement et poids
---------------------------------------------------------------------------

function Inv.RefreshEquipment(ply)
    local inv = Data(ply)
    if not inv then return end

    local mods = {}
    for _, id in pairs(inv.equipped) do
        local def = Inv.Items:Get(id)
        for key, m in pairs(def and def.equip and def.equip.modifiers or {}) do
            mods[key] = mods[key] or { add = 0, mul = 0 }
            mods[key].add = mods[key].add + (m.add or 0)
            mods[key].mul = mods[key].mul + (m.mul or 0)
        end
    end
    NRP.Stats.SetModifier(ply, "equip", mods)
end

function Inv.RefreshWeight(ply)
    local inv = Data(ply)
    if not inv then return end

    local over = Inv.GetWeight(inv) > NRP.Stats.Get(ply, "carryWeight")
    if over == (ply.NRPOverweight == true) then return end

    ply.NRPOverweight = over
    if over then
        local slow = Inv.Settings().OverweightSlow
        NRP.Stats.SetModifier(ply, "overweight", { walkSpeed = { mul = slow }, runSpeed = { mul = slow } })
        NRP.Notify(ply, "Vous êtes surchargé !", NRP.NOTIFY_WARNING)
    else
        NRP.Stats.RemoveModifier(ply, "overweight")
    end
end

function Inv.Equip(ply, id)
    local inv = Data(ply)
    local def = Inv.Items:Get(id)
    if not inv or not def or not def.equip then return false, "Cet objet ne s'équipe pas." end
    if not Inv.Has(ply, id) then return false, "Vous ne possédez pas cet objet." end

    inv.equipped[def.equip.slot] = id
    Touch(ply)
    Inv.RefreshEquipment(ply)
    return true
end

function Inv.Unequip(ply, slot)
    local inv = Data(ply)
    if not inv or not inv.equipped[slot] then return false end
    inv.equipped[slot] = nil
    Touch(ply)
    Inv.RefreshEquipment(ply)
    return true
end

---------------------------------------------------------------------------
-- Utilisation
---------------------------------------------------------------------------

function Inv.Use(ply, id)
    local def = Inv.Items:Get(id)
    if not def or not Inv.Has(ply, id) then return false, "Objet introuvable." end
    if not Inv.IsUsable(def) then return false, "Cet objet ne s'utilise pas." end
    if not ply:Alive() then return false end

    if CD.IsActive(ply, "item") then return false end
    local remaining = CD.Remaining(ply, "item:" .. id)
    if remaining > 0 then
        return false, string.format("%s : encore %.0f s", def.name, remaining)
    end

    if def.learnJutsu then
        local ok, err = NRP.Jutsu.Learn(ply, def.learnJutsu, { source = "scroll" })
        if not ok then return false, err end
    end

    local use = def.use
    if use then
        if use.heal and not use.chakra and not use.stamina and not use.cure and ply:Health() >= ply:GetMaxHealth() then
            return false, "Vous êtes en pleine santé."
        end

        if use.heal then
            ply:SetHealth(math.min(ply:GetMaxHealth(), ply:Health() + use.heal))
        end
        if use.chakra then NRP.Chakra.Add(ply, use.chakra) end
        if use.stamina then NRP.Stamina.Add(ply, use.stamina) end
        if use.cure then NRP.Status.Cure(ply, use.cure) end
        if use.regen then
            NRP.Status.Apply(ply, "regen", use.regen.duration, { hps = use.regen.amount / use.regen.duration })
        end
        if use.buff then
            NRP.Stats.SetTimedModifier(ply, "item:" .. id, use.buff.modifiers, use.buff.duration)
        end
        if use.cooldown then
            CD.Set(ply, "item:" .. id, use.cooldown)
        end
    end

    CD.Set(ply, "item", Inv.Settings().UseCooldown, true)
    if not use or use.consume ~= false then
        Inv.Take(ply, id, 1)
    end

    ply:EmitSound(def.useSound or "items/smallmedkit1.wav", 60)
    hook.Run("NRP.ItemUsed", ply, id)
    return true
end

---------------------------------------------------------------------------
-- Lancer d'outils (touche "throw")
---------------------------------------------------------------------------

function Inv.Throw(ply)
    local inv = Data(ply)
    if not inv or not ply:Alive() then return end

    local id = inv.equipped.tool
    local def = Inv.Items:Get(id)
    if not def or not def.throw then
        NRP.Notify(ply, "Aucun outil de lancer équipé.", NRP.NOTIFY_ERROR, 1.5)
        return
    end
    if not NRP.Status.CanAct(ply) or NRP.Combat.IsBlocking(ply) or NRP.Jutsu.IsCasting(ply) then return end
    if CD.IsActive(ply, "throw") then return end
    if not Inv.Take(ply, id, 1) then return end

    local t = def.throw
    CD.Set(ply, "throw", t.cooldown or 0.7)
    ply:DoAnimationEvent(ACT_GMOD_GESTURE_ITEM_THROW)
    ply:EmitSound("weapons/slam/throw.wav", 65, 120)

    local count = t.count or 1
    local eyeAng = ply:EyeAngles()
    local power = NRP.Stats.Get(ply, "meleePower")

    for i = 1, count do
        local ang = Angle(eyeAng.p, eyeAng.y, 0)
        if count > 1 then
            ang:RotateAroundAxis(ang:Up(), (i - (count + 1) / 2) * (t.spread or 4))
        end
        NRP.Projectile.Launch({
            owner = ply,
            pos = ply:EyePos() + ang:Forward() * 20 - Vector(0, 0, 4),
            dir = ang:Forward(),
            speed = t.speed or 2500,
            gravity = t.gravity or 200,
            radius = t.radius or 6,
            lifetime = t.lifetime or 1.5,
            fx = t.fx or "kunai",
            explosion = t.explosion,
            impactSound = "physics/metal/metal_solid_impact_bullet" .. math.random(1, 4) .. ".wav",
            damage = {
                attacker = ply, inflictor = ply,
                amount = (t.damage or 10) * power,
                kind = "tool",
                knockback = t.knockback,
                statuses = t.effects,
            },
        })
    end
end

NRP.Keys.OnPress("throw", Inv.Throw)

---------------------------------------------------------------------------
-- Objets au sol
---------------------------------------------------------------------------

function Inv.Drop(ply, id, qty)
    local def = Inv.Items:Get(id)
    if not def or not def.droppable then return false, "Cet objet ne peut pas être jeté." end

    qty = math.Clamp(math.floor(qty or 1), 1, Inv.Count(ply, id))
    if qty <= 0 then return false end

    ply.NRPDrops = ply.NRPDrops or {}
    for i = #ply.NRPDrops, 1, -1 do
        if not IsValid(ply.NRPDrops[i]) then table.remove(ply.NRPDrops, i) end
    end
    if #ply.NRPDrops >= Inv.Settings().MaxDropsPerPlayer then
        return false, "Trop d'objets au sol, ramassez-en d'abord."
    end

    if not Inv.Take(ply, id, qty) then return false end

    local tr = util.TraceLine({
        start = ply:EyePos(),
        endpos = ply:EyePos() + ply:GetAimVector() * 60,
        filter = ply,
    })

    local ent = ents.Create("nrp_item")
    ent:SetPos(tr.HitPos + tr.HitNormal * 8)
    ent:SetItem(id, qty)
    ent.DroppedBy = ply
    ent:Spawn()
    SafeRemoveEntityDelayed(ent, Inv.Settings().DropLifetime)

    ply.NRPDrops[#ply.NRPDrops + 1] = ent
    return true
end

function Inv.Pickup(ply, ent)
    if not IsValid(ent) or ent.NRPPickedUp then return end
    if ply:GetPos():DistToSqr(ent:GetPos()) > Inv.Settings().PickupDistance ^ 2 then return end

    local id, qty = ent:GetItemId(), ent:GetQuantity()
    local given = Inv.Give(ply, id, qty)
    if given <= 0 then return end

    if given >= qty then
        ent.NRPPickedUp = true
        ent:Remove()
    else
        ent:SetQuantity(qty - given)
    end
end

---------------------------------------------------------------------------
-- Boutique
---------------------------------------------------------------------------

function Inv.Buy(ply, npc, itemId, qty)
    if not IsValid(npc) or npc:GetClass() ~= "nrp_shop_npc" then return false end
    if ply:GetPos():DistToSqr(npc:GetPos()) > 200 * 200 then return false, "Trop loin du marchand." end

    local shop = Inv.Shops:Get(npc:GetShopId())
    local def = Inv.Items:Get(itemId)
    if not shop or not def or not Inv.ShopSells(shop, itemId) then return false, "Objet indisponible." end

    qty = math.Clamp(math.floor(qty), 1, 100)
    qty = math.min(qty, def.stack - Inv.Count(ply, itemId))
    if qty <= 0 then return false, "Vous ne pouvez pas en porter plus." end

    local price = def.price * qty
    if not Char.CanAfford(ply, price) then return false, "Pas assez de Ryo." end

    local given = Inv.Give(ply, itemId, qty, true)
    if given <= 0 then return false, "Inventaire plein." end

    Char.AddRyo(ply, -def.price * given, "shop")
    NRP.Notify(ply, string.format("Acheté : %d x %s (%s Ryo)", given, def.name, NRP.Util.FormatNumber(def.price * given)), NRP.NOTIFY_SUCCESS)
    return true
end

function Inv.Sell(ply, npc, itemId, qty)
    if not IsValid(npc) or npc:GetClass() ~= "nrp_shop_npc" then return false end
    if ply:GetPos():DistToSqr(npc:GetPos()) > 200 * 200 then return false, "Trop loin du marchand." end

    local shop = Inv.Shops:Get(npc:GetShopId())
    local def = Inv.Items:Get(itemId)
    if not shop or not def or shop.sellRatio <= 0 or def.missionItem then return false, "Ce marchand n'achète pas cet objet." end

    qty = math.Clamp(math.floor(qty), 1, Inv.Count(ply, itemId))
    if qty <= 0 or not Inv.Take(ply, itemId, qty) then return false end

    local gain = math.floor(def.price * shop.sellRatio) * qty
    Char.AddRyo(ply, gain, "shop_sell")
    NRP.Notify(ply, string.format("Vendu : %d x %s (+%s Ryo)", qty, def.name, NRP.Util.FormatNumber(gain)), NRP.NOTIFY_SUCCESS)
    return true
end

---------------------------------------------------------------------------
-- Réseau
---------------------------------------------------------------------------

NRP.Net.Pool("OpenShop")

NRP.Net.Receive("ItemAction", function(ply)
    local action = net.ReadUInt(3)
    local id = NRP.Net.ReadId()
    local qty = net.ReadUInt(16)
    if not id then return end

    local ok, err
    if action == Inv.ACTION_USE then
        ok, err = Inv.Use(ply, id)
    elseif action == Inv.ACTION_EQUIP then
        ok, err = Inv.Equip(ply, id)
    elseif action == Inv.ACTION_UNEQUIP then
        ok, err = Inv.Unequip(ply, id)
    elseif action == Inv.ACTION_DROP then
        ok, err = Inv.Drop(ply, id, qty)
    end

    if not ok and err then
        NRP.Notify(ply, err, NRP.NOTIFY_ERROR, 2)
    end
end, { rate = 5, burst = 8, maxBytes = 96, alive = true })

NRP.Net.Receive("ShopTransaction", function(ply)
    local npc = net.ReadEntity()
    local buying = net.ReadBool()
    local id = NRP.Net.ReadId()
    local qty = net.ReadUInt(8)
    if not id then return end

    local ok, err
    if buying then
        ok, err = Inv.Buy(ply, npc, id, qty)
    else
        ok, err = Inv.Sell(ply, npc, id, qty)
    end
    if not ok and err then
        NRP.Notify(ply, err, NRP.NOTIFY_ERROR, 2)
    end
end, { rate = 3, burst = 5, maxBytes = 96, alive = true })

---------------------------------------------------------------------------
-- Cycle de vie
---------------------------------------------------------------------------

hook.Add("NRP.InitCharacter", "NRP.Inventory.Init", function(ply, data)
    data.inventory = { items = {}, equipped = {} }
    for id, qty in pairs(NRP.Config.Character.StartItems or {}) do
        local def = Inv.Items:Get(id)
        if def then
            data.inventory.items[id] = math.min(qty, def.stack)
            if def.equip and def.equip.slot == "tool" and not data.inventory.equipped.tool then
                data.inventory.equipped.tool = id
            end
        end
    end
end)

hook.Add("NRP.PreCharacterLoaded", "NRP.Inventory.Sanitize", function(ply, data)
    local inv = data.inventory
    inv.items = istable(inv.items) and inv.items or {}
    inv.equipped = istable(inv.equipped) and inv.equipped or {}

    for id, qty in pairs(inv.items) do
        qty = math.floor(tonumber(qty) or 0)
        if not Inv.Items:Exists(id) or qty <= 0 then
            inv.items[id] = nil
        else
            inv.items[id] = qty
        end
    end
    for slot, id in pairs(inv.equipped) do
        if not inv.items[id] then
            inv.equipped[slot] = nil
        end
    end
end)

hook.Add("NRP.CharacterLoaded", "NRP.Inventory.Apply", function(ply)
    ply.NRPOverweight = nil
    Inv.RefreshEquipment(ply)
end)

hook.Add("NRP.StatsUpdated", "NRP.Inventory.Weight", Inv.RefreshWeight)

---------------------------------------------------------------------------
-- Commandes
---------------------------------------------------------------------------

NRP.Commands.Add("giveitem", {
    perm = "admin.items", usage = "giveitem <joueur> <objet> [quantité]", description = "Donner un objet",
    args = { "player", "string", "number?" },
    run = function(caller, target, id, qty)
        if not Inv.Items:Exists(id) then return false, "Objet inconnu (voir !itemlist)." end
        local given = Inv.Give(target, id, qty or 1)
        NRP.LogAction("admin", caller, target, "objet +" .. given .. " " .. id)
        return given > 0, given .. " x " .. id .. " donné(s) à " .. target:Nick()
    end,
})

NRP.Commands.Add("takeitem", {
    perm = "admin.items", usage = "takeitem <joueur> <objet> [quantité]", description = "Retirer un objet",
    args = { "player", "string", "number?" },
    run = function(caller, target, id, qty)
        qty = qty or Inv.Count(target, id)
        if not Inv.Take(target, id, qty) then return false, "Quantité insuffisante." end
        NRP.LogAction("admin", caller, target, "objet -" .. qty .. " " .. id)
        return true, qty .. " x " .. id .. " retiré(s) à " .. target:Nick()
    end,
})

NRP.Commands.Add("itemlist", {
    perm = "admin.items", description = "Identifiants des objets (console)",
    run = function(caller)
        for id, def in Inv.Items:Iterate() do
            local line = id .. " - " .. def.name .. " [" .. def.category .. "]"
            if caller == NULL then NRP.Print(line) else caller:PrintMessage(HUD_PRINTCONSOLE, line) end
        end
        return true, Inv.Items:Count() .. " objets (voir console)"
    end,
})
