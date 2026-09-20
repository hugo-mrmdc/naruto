--[[
    Module : personnage - affinités élémentaires (serveur)
    La première affinité de la liste est l'affinité principale.
]]

local Char = NRP.Char

function Char.AddAffinity(ply, element, silent)
    local data = ply.NRPChar
    if not data or not NRP.Elements:Exists(element) then return false, "Élément inconnu." end
    if Char.HasAffinity(data, element) then return false, "Affinité déjà possédée." end

    table.insert(data.affinities, element)
    Char.Touch(ply, "affinities")
    if not silent then
        NRP.Notify(ply, "Nouvelle affinité : " .. NRP.Elements:Get(element).name, NRP.NOTIFY_SUCCESS)
    end
    hook.Run("NRP.AffinityChanged", ply, element, true)
    return true
end

function Char.RemoveAffinity(ply, element)
    local data = ply.NRPChar
    if not data or not Char.HasAffinity(data, element) then return false, "Affinité non possédée." end

    table.RemoveByValue(data.affinities, element)
    Char.Touch(ply, "affinities")

    -- Retire les jutsu qui exigeaient cette affinité et ne sont plus accessibles
    for id in pairs(table.Copy(data.jutsus)) do
        local jutsu = NRP.Jutsu.Registry:Get(id)
        if jutsu and jutsu.requirements.affinity and not NRP.Jutsu.CheckRequirements(data, jutsu, ply, true) then
            NRP.Jutsu.Forget(ply, id)
        end
    end

    hook.Run("NRP.AffinityChanged", ply, element, false)
    return true
end

function Char.SetPrimaryAffinity(ply, element)
    local data = ply.NRPChar
    if not data or not Char.HasAffinity(data, element) then return false end
    table.RemoveByValue(data.affinities, element)
    table.insert(data.affinities, 1, element)
    Char.Touch(ply, "affinities")
    return true
end

NRP.Commands.Add("addaffinity", {
    perm = "admin.affinity", usage = "addaffinity <joueur> <element>", description = "Ajouter une affinité",
    args = { "player", "string" },
    run = function(caller, target, element)
        local ok, err = Char.AddAffinity(target, element)
        if not ok then return false, err end
        NRP.LogAction("admin", caller, target, "affinité +" .. element)
        return true, "Affinité ajoutée."
    end,
})

NRP.Commands.Add("removeaffinity", {
    perm = "admin.affinity", usage = "removeaffinity <joueur> <element>", description = "Retirer une affinité",
    args = { "player", "string" },
    run = function(caller, target, element)
        local ok, err = Char.RemoveAffinity(target, element)
        if not ok then return false, err end
        NRP.LogAction("admin", caller, target, "affinité -" .. element)
        return true, "Affinité retirée."
    end,
})

NRP.Commands.Add("primaryaffinity", {
    perm = "admin.affinity", usage = "primaryaffinity <joueur> <element>", description = "Définir l'affinité principale",
    args = { "player", "string" },
    run = function(caller, target, element)
        if not Char.SetPrimaryAffinity(target, element) then return false, "Affinité non possédée." end
        NRP.LogAction("admin", caller, target, "affinité principale " .. element)
        return true, "Affinité principale modifiée."
    end,
})
