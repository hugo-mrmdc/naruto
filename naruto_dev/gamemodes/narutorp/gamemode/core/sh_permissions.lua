--[[
    Core : permissions

    NRP.Perm.Has(ply, "admin.xp") est évalué dans cet ordre :
        1. CAMI (ULX, SAM, ServerGuard...) si présent et si le privilège y est déclaré
        2. NRP.Config.Permissions.Groups (usergroup -> permissions, avec héritage)
        3. permissions du grade ninja du joueur (NRP.Config.Ranks[..].permissions)

    La console serveur a toutes les permissions.
    Côté client, Has() ne sert qu'à l'affichage : le serveur revérifie toujours.
]]

NRP.Perm = NRP.Perm or {}
local Perm = NRP.Perm

Perm.List = Perm.List or {}

-- minAccess : "user" | "admin" | "superadmin" (utilisé pour CAMI)
function Perm.Register(id, description, minAccess)
    Perm.List[id] = { id = id, description = description, minAccess = minAccess or "admin" }
end

function Perm.RegisterCAMI()
    if not CAMI or not CAMI.RegisterPrivilege then return end
    for id, p in pairs(Perm.List) do
        CAMI.RegisterPrivilege({
            Name = "NRP " .. id,
            MinAccess = p.minAccess,
            Description = p.description,
        })
    end
end

local function GroupHas(group, perm, depth)
    local groups = (NRP.Config.Permissions or {}).Groups or {}
    local def = groups[group]
    if not def or depth > 8 then return false end

    local perms = def.permissions or {}
    if perms[perm] == false then return false end -- refus explicite
    if perms["*"] or perms[perm] then return true end

    -- "admin.*" autorise toutes les permissions "admin.xxx"
    local prefix = string.match(perm, "^([%w_]+)%.")
    if prefix and perms[prefix .. ".*"] then return true end

    if def.inherits then
        return GroupHas(def.inherits, perm, depth + 1)
    end
    return false
end

function Perm.Has(ply, perm)
    if SERVER and ply == NULL then
        return true -- console serveur
    end
    if not IsValid(ply) or not ply:IsPlayer() then
        return false
    end

    if CAMI and CAMI.GetPrivilege and CAMI.GetPrivilege("NRP " .. perm) then
        local result
        CAMI.PlayerHasAccess(ply, "NRP " .. perm, function(allowed)
            result = allowed
        end)
        if result then return true end
    end

    if GroupHas(ply:GetUserGroup(), perm, 0) then
        return true
    end

    if NRP.Ranks and NRP.Ranks.HasPermission then
        return NRP.Ranks.HasPermission(ply, perm)
    end

    return false
end

-- Permissions du gamemode
Perm.Register("admin.menu", "Accès au panneau d'administration")
Perm.Register("admin.sandbox", "Spawn menu, outils et physgun")
Perm.Register("admin.noclip", "Noclip")
Perm.Register("admin.physgunplayers", "Déplacer les joueurs au physgun", "superadmin")
Perm.Register("admin.xp", "Donner de l'XP / changer le niveau")
Perm.Register("admin.ryo", "Modifier les Ryo")
Perm.Register("admin.rank", "Changer le grade d'un joueur")
Perm.Register("admin.clan", "Attribuer un clan / des points de clan")
Perm.Register("admin.affinity", "Modifier les affinités")
Perm.Register("admin.jutsu", "Donner / retirer des techniques")
Perm.Register("admin.dojutsu", "Modifier les dojutsu")
Perm.Register("admin.stats", "Modifier les statistiques")
Perm.Register("admin.items", "Donner / retirer des objets")
Perm.Register("admin.mission", "Lancer / terminer des missions")
Perm.Register("admin.event", "Créer des événements")
Perm.Register("admin.villages", "Modifier les relations entre villages")
Perm.Register("admin.village", "Changer le village / statut déserteur")
Perm.Register("admin.reputation", "Modifier la réputation")
Perm.Register("admin.bounty", "Gérer les primes")
Perm.Register("admin.inspect", "Consulter les fiches personnage")
Perm.Register("admin.character", "Supprimer / renommer un personnage", "superadmin")
Perm.Register("admin.world", "Points de spawn, points de mission, PNJ")
Perm.Register("rp.promote", "Promouvoir des ninjas (responsable RP)", "admin")
Perm.Register("rp.exam", "Organiser des examens", "admin")
Perm.Register("rp.event", "Lancer des événements RP", "admin")

Perm.RegisterCAMI()
hook.Add("Initialize", "NRP.Perm.CAMI", Perm.RegisterCAMI)
