--[[
    Module : personnage - création (serveur)

    Le client n'envoie que des choix (textes, identifiants, index). Tout est revalidé ici :
    noms, sexe, modèle, village, clan, affinité, skin, bodygroups, couleur.
    Les autres modules complètent le personnage via le hook "NRP.InitCharacter".
]]

local Char = NRP.Char

local function Cfg()
    return NRP.Config.Character
end

local function SendResult(ply, ok, message)
    NRP.Net.Start("CreationResult")
        net.WriteBool(ok)
        net.WriteString(message or "")
    net.Send(ply)
end

local function IsLetter(code)
    return (code >= 65 and code <= 90) or (code >= 97 and code <= 122)
        or (code >= 192 and code <= 255 and code ~= 215 and code ~= 247)
end

-- Renvoie true, nomFormaté ou false, raison
function Char.ValidateName(name)
    local cfg = Cfg()
    name = string.Trim(tostring(name or ""))

    local len = utf8.len(name)
    if not len then
        return false, "Le nom contient des caractères invalides."
    end
    if len < cfg.NameMinLength or len > cfg.NameMaxLength then
        return false, string.format("Le nom doit faire entre %d et %d caractères.", cfg.NameMinLength, cfg.NameMaxLength)
    end

    local ok, err = pcall(function()
        local first = true
        for _, code in utf8.codes(name) do
            if first and not IsLetter(code) then
                error("start")
            end
            if not (IsLetter(code) or code == 45 or code == 39) then
                error("char")
            end
            first = false
        end
    end)
    if not ok then
        if string.find(tostring(err), "start", 1, true) then
            return false, "Le nom doit commencer par une lettre."
        end
        return false, "Seuls les lettres, tirets et apostrophes sont autorisés."
    end

    local lower = string.lower(name)
    for _, banned in ipairs(cfg.BlacklistedNames or {}) do
        if lower == banned then
            return false, "Ce nom est réservé."
        end
    end

    -- Majuscule initiale (lettres ASCII)
    name = string.upper(string.sub(name, 1, 1)) .. string.sub(name, 2)
    return true, name
end

function Char.ValidateCreation(ply, req)
    local cfg = Cfg()

    local ok, value = Char.ValidateName(req.firstname)
    if not ok then return false, "Prénom : " .. value end
    req.firstname = value

    ok, value = Char.ValidateName(req.lastname)
    if not ok then return false, "Nom : " .. value end
    req.lastname = value

    local gender = cfg.Genders[req.gender or ""]
    if not gender then return false, "Sexe invalide." end

    local modelDef = gender.models[req.modelIndex]
    if not modelDef or not util.IsValidModel(modelDef.model) then return false, "Apparence invalide." end
    req.model = modelDef.model

    local village = NRP.Villages:Get(req.village)
    if not village or not village.selectable then
        return false, "Village invalide."
    end

    if not table.HasValue(cfg.SelectableAffinities, req.affinity) or not NRP.Elements:Exists(req.affinity) then
        return false, "Affinité invalide."
    end

    if req.clan == "" then
        if not NRP.Config.ClanSettings.AllowNoClan then
            return false, "Vous devez choisir un clan."
        end
    else
        local canChoose, reason = NRP.Clans.CanChoose(req.clan, req.village)
        if not canChoose then return false, reason end
    end

    local hookOk, hookReason = hook.Run("NRP.ValidateCreation", ply, req)
    if hookOk == false then
        return false, hookReason or "Création refusée."
    end

    return true
end

function Char.Create(ply, req)
    local ok, err = Char.ValidateCreation(ply, req)
    if not ok then
        SendResult(ply, false, err)
        return
    end

    ply.NRPCreating = true
    local sid = ply:SteamID64()

    local function Proceed()
        local data = { steamid = sid }
        for _, key in ipairs(Char.FieldList) do
            data[key] = Char.DefaultValue(key)
        end

        data.firstname = req.firstname
        data.lastname = req.lastname
        data.gender = req.gender
        data.model = req.model
        data.skin = req.skin
        data.bodygroups = req.bodygroups
        data.color = Cfg().AllowPlayerColor and req.color or { 255, 255, 255 }
        data.village = req.village
        data.affinities = { req.affinity }
        data.ryo = Cfg().StartRyo or 0
        data.created = os.time()
        data.lastSeen = os.time()

        hook.Run("NRP.InitCharacter", ply, data, req)

        local row = { steamid = sid }
        for _, key in ipairs(Char.FieldList) do
            local f = Char.Fields[key]
            if f.save then
                row[f.column] = Char.Encode(f, data[key])
            end
        end

        NRP.DB.Insert(Char.TABLE, row, function()
            if not IsValid(ply) then return end
            ply.NRPCreating = nil
            SendResult(ply, true, "Bienvenue, " .. data.firstname .. " !")
            Char.Setup(ply, data, true)
            NRP.LogAction("character", ply, ply, "création de " .. data.firstname .. " " .. data.lastname
                .. " (" .. data.village .. ", clan " .. (data.clan ~= "" and tostring(data.clan) or "aucun") .. ")")
        end, function()
            if not IsValid(ply) then return end
            ply.NRPCreating = nil
            SendResult(ply, false, "Erreur de base de données, réessayez.")
        end)
    end

    if not Cfg().UniqueFullName then
        Proceed()
        return
    end

    NRP.DB.Query("SELECT steamid FROM " .. NRP.DB.Ident(NRP.DB.Table(Char.TABLE))
        .. " WHERE LOWER(firstname) = LOWER(?) AND LOWER(lastname) = LOWER(?)",
        { req.firstname, req.lastname },
        function(rows)
            if not IsValid(ply) then return end
            if rows[1] then
                ply.NRPCreating = nil
                SendResult(ply, false, "Un ninja porte déjà ce nom.")
                return
            end
            Proceed()
        end,
        function()
            if IsValid(ply) then ply.NRPCreating = nil end
        end)
end

NRP.Net.Receive("CreateCharacter", function(ply)
    if ply.NRPChar or ply.NRPCreating or not ply.NRPReady then return end

    local req = {
        firstname = NRP.Net.ReadString(64),
        lastname = NRP.Net.ReadString(64),
        gender = net.ReadString(),
        village = net.ReadString(),
        clan = net.ReadString(),
        affinity = net.ReadString(),
        modelIndex = net.ReadUInt(8),
        skin = net.ReadUInt(8),
        bodygroups = {},
    }

    local count = net.ReadUInt(5)
    local maxBg = Cfg().MaxBodygroups or 12
    for i = 1, count do
        local id, value = net.ReadUInt(8), net.ReadUInt(8)
        if i <= maxBg then
            req.bodygroups[id] = value
        end
    end

    req.color = { net.ReadUInt(8), net.ReadUInt(8), net.ReadUInt(8) }

    if req.clan ~= "" and not NRP.Util.IsValidId(req.clan) then return end

    Char.Create(ply, req)
end, { needChar = false, rate = 0.5, burst = 3, maxBytes = 512 })

-- Informations envoyées au menu de création
hook.Add("NRP.CreationInfo", "NRP.Char.CreationInfo", function()
    local clansByVillage = {}
    for villageId, village in NRP.Villages:Iterate() do
        if village.selectable then
            local list = {}
            for clanId in NRP.Clans.Registry:Iterate() do
                if NRP.Clans.CanChoose(clanId, villageId) then
                    list[#list + 1] = clanId
                end
            end
            clansByVillage[villageId] = list
        end
    end
    return { clans = clansByVillage }
end)
