--[[
    Compatibilité : addon naruto_dev (serveur)

    - Détecte l'addon (hook PlayerSpawn "NA_SetHeadAndHair") et le signale aux clients.
    - Après que l'addon a posé sa tenue + tête + cheveux (0,1 s après l'apparition),
      réapplique la tenue choisie à la création. Si ce modèle a déjà une tête (hasHead),
      la tête et les cheveux de l'addon sont retirés.
    - Pendant la création de personnage, cache la tête et les cheveux de l'addon
      (le joueur est invisible et ne doit pas laisser une tête flotter).
]]

NRP.Compat = NRP.Compat or {}

local function Cfg()
    return NRP.Config.Compat.NarutoDev
end

local function Detect()
    local spawnHooks = hook.GetTable().PlayerSpawn
    local active = Cfg().Enabled and spawnHooks ~= nil and spawnHooks.NA_SetHeadAndHair ~= nil
    NRP.CompatNarutoDevActive = active
    SetGlobal2Bool("NRP_CompatNarutoDev", active)
    if active then
        NRP.Print("Compatibilité naruto_dev active (tenue, tête et cheveux de l'addon conservés)")
    end
end

hook.Add("InitPostEntity", "NRP.Compat.NarutoDev.Detect", Detect)

local function FindModelDef(data)
    local gender = NRP.Config.Character.Genders[data.gender or ""]
    for _, def in ipairs(gender and gender.models or {}) do
        if def.model == data.model then return def end
    end
end

local function SetAddonPartsHidden(ply, hidden)
    for _, part in ipairs({ ply.NA_Head, ply.NA_Hair }) do
        if IsValid(part) then
            part:SetNoDraw(hidden)
            part:DrawShadow(not hidden)
        end
    end
end

local function RemoveAddonParts(ply)
    for _, key in ipairs({ "NA_Head", "NA_Hair" }) do
        if IsValid(ply[key]) then ply[key]:Remove() end
        ply[key] = nil
    end
end

local function AfterAddonSetup(ply)
    if not IsValid(ply) or not ply:Alive() then return end

    local data = ply.NRPChar
    if not data then
        SetAddonPartsHidden(ply, true)
        return
    end

    if Cfg().KeepCharacterOutfit then
        NRP.Char.ApplyAppearance(ply)
    end

    local def = FindModelDef(data)
    if def and def.hasHead then
        RemoveAddonParts(ply)
    end
end

hook.Add("NRP.PlayerSpawned", "NRP.Compat.NarutoDev.Outfit", function(ply)
    if not NRP.CompatNarutoDevActive then return end
    -- L'addon agit 0,1 s après PlayerSpawn : on passe juste après lui.
    timer.Create("NRP.Compat.Outfit." .. ply:EntIndex(), Cfg().ReapplyDelay or 0.3, 1, function()
        AfterAddonSetup(ply)
    end)
end)

hook.Add("PlayerDisconnected", "NRP.Compat.NarutoDev.Cleanup", function(ply)
    timer.Remove("NRP.Compat.Outfit." .. ply:EntIndex())
end)

---------------------------------------------------------------------------
-- Armes de l'addon accessibles aux joueurs (menu Q)
---------------------------------------------------------------------------

function NRP.Compat.CanTakeWeapon(ply, class)
    local allowed = NRP.Config.Compat.PlayerWeapons or {}
    return allowed[class] == true and ply.NRPChar ~= nil
end
