--========================================================
-- Téléportation Fuma (SERVEUR)
--
--   1er appui : mudras, animation de lancer, puis le shuriken part dans la
--               direction du regard.
--   2e appui  : téléporte le joueur sur le shuriken.
--
--   Le shuriken touche un joueur / PNJ -> il explose (dégâts de zone) et disparaît.
--   Le shuriken touche un mur          -> téléportation AUTOMATIQUE contre le mur.
--   Il ne touche rien (fin de course) et le joueur ne s'est pas téléporté
--                                      -> il disparaît, sans exploser.
--
-- Hitbox du shuriken visible avec : developer 1
--========================================================

local NET_FUMA    = "naruto_dev_fumaTp"
local NET_FUMA_FX = "naruto_dev_fumaTp_fx"

util.AddNetworkString(NET_FUMA)
util.AddNetworkString(NET_FUMA_FX)

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs
--========================================================
local MODELE        = "models/fumaSpell/orga_props_shuriken.mdl"
local VITESSE       = 2400   -- unités / seconde
local DUREE_VIE     = 1.5    -- secondes avant que le shuriken disparaisse s'il ne touche rien
local HITBOX        = 16     -- demi-taille de la zone qui touche joueurs et PNJ
local HITBOX_MUR    = 6      -- demi-taille pour les murs (petite : il passe près des bords)

local DEGATS        = 60     -- dégâts de l'explosion sur un joueur / PNJ
local RAYON_EXPLO   = 200    -- rayon de l'explosion (dégâts réduits avec la distance)

local RECHARGE      = 2      -- secondes avant de relancer un shuriken (après sa disparition)

local DUREE_MUDRA   = 0.4    -- mudras avant le lancer
local ANIM_MUDRA    = "nrp_ninjutsu_defend_dragonflamebombs_start"
local ANIM_LANCER   = "nrp_ninjutsu_defend_d35nj2_throw"   -- après les mudras
local DELAI_LANCER  = 0.3    -- après le début de l'animation de lancer, le shuriken part
--========================================================

-- réglages par niveau (_na_niveaux_techniques.lua) : Niv(joueur, "stat", VALEUR)
local function Niv(ply, stat, base) return NA_Stat(ply, "fuma_tp", stat, base) end

local fumaActive = {}   -- joueur -> shuriken en vol
local nextUse = {}
local enCours = {}      -- joueur -> true pendant les mudras et le lancer

local function JouerAnim(ply, seq)
    NA_AnimJutsu(ply, seq)   -- animation + pas de coups pendant (_na_mudra.lua)
end

local function Dev()
    return GetConVar("developer"):GetInt() > 0
end

local function EstCible(ent, lanceur)
    if not IsValid(ent) or ent == lanceur then return false end
    if ent:IsPlayer() then return ent:Alive() end
    if ent:IsNPC() then return ent:GetNPCState() ~= NPC_STATE_DEAD end
    if ent:IsNextBot() then return ent:Health() > 0 end
    return false
end

-- Fin du shuriken (quelle qu'en soit la raison) : il disparaît et la recharge démarre
local function RemoveFuma(ply)
    local proj = fumaActive[ply]
    if IsValid(proj) then SafeRemoveEntity(proj) end
    fumaActive[ply] = nil
    timer.Remove("fumaTpMove_" .. (IsValid(ply) and ply:EntIndex() or 0))

    if IsValid(ply) then
        nextUse[ply] = CurTime() + NA_Stat(ply, "fuma_tp", "recharge", RECHARGE)
        if NA_CD then NA_CD.Set(ply, "fuma_tp", NA_Stat(ply, "fuma_tp", "recharge", RECHARGE)) end   -- recharge visible dans la barre
    end
end

local function Exploser(ply, pos, inflicteur)
    for _, ent in ipairs(ents.FindInSphere(pos, Niv(ply, "rayon_explo", RAYON_EXPLO))) do
        if EstCible(ent, ply) then
            local scale = 1 - math.Clamp(ent:GetPos():Distance(pos) / Niv(ply, "rayon_explo", RAYON_EXPLO), 0, 1)
            local dmg = DamageInfo()
            dmg:SetDamage(NA_Stat(ply, "fuma_tp", "degats", DEGATS) * scale)
            dmg:SetAttacker(ply)
            dmg:SetInflictor(IsValid(inflicteur) and inflicteur or ply)
            dmg:SetDamageType(DMG_BLAST)
            dmg:SetDamagePosition(pos)
            ent:TakeDamageInfo(dmg)
        end
    end
    if Dev() then debugoverlay.Sphere(pos, Niv(ply, "rayon_explo", RAYON_EXPLO), 1, Color(255, 0, 0, 30), true) end
end

-- Position libre pour la téléportation (évite de rester coincé dans un mur)
local function FindFreePos(ply, pos, normale)
    local mins, maxs = ply:GetHull()
    local recul = normale or Vector(0, 0, 0)
    for _, d in ipairs({ 0, 16, 32, 48 }) do
        for _, up in ipairs({ 0, 10, 40, 80 }) do
            local test = pos + recul * d + Vector(0, 0, up)
            local tr = util.TraceHull({ start = test, endpos = test, mins = mins, maxs = maxs, mask = MASK_PLAYERSOLID, filter = ply })
            if not tr.Hit then return test end
        end
    end
end

local function Teleporter(ply, pos, normale)
    if not IsValid(ply) or not ply:Alive() then return end
    -- contre un mur : on recule un peu et on pose les pieds sous le point d'impact
    local depart = pos
    if normale then
        depart = pos + normale * 20 - Vector(0, 0, 36)
    end
    local dest = FindFreePos(ply, depart, normale)
    if not dest then return end

    ply:SetPos(dest)
    ply:SetVelocity(-ply:GetVelocity())

    -- fumée visible par tous les joueurs
    net.Start(NET_FUMA_FX)
        net.WriteEntity(ply)
    net.Broadcast()
end

local function Lancer(ply)
    local dir = ply:GetAimVector()
    local proj = ents.Create("prop_dynamic")
    if not IsValid(proj) then return end

    proj:SetModel(MODELE)
    proj:SetPos(ply:GetShootPos() + dir * 20)
    proj:SetAngles(dir:Angle())
    proj:Spawn()
    proj:SetOwner(ply)
    proj:SetSolid(SOLID_NONE)
    proj:SetMoveType(MOVETYPE_NONE)
    fumaActive[ply] = proj

    local fin = CurTime() + Niv(ply, "duree_vie", DUREE_VIE)
    local precedent = CurTime()
    local hb = NA_Stat(ply, "fuma_tp", "hitbox", HITBOX)   -- hitbox par niveau (pas celle des murs)
    local tH = Vector(hb, hb, hb)
    local tM = Vector(Niv(ply, "hitbox_mur", HITBOX_MUR), Niv(ply, "hitbox_mur", HITBOX_MUR), Niv(ply, "hitbox_mur", HITBOX_MUR))
    local nom = "fumaTpMove_" .. ply:EntIndex()

    timer.Create(nom, 0, 0, function()
        if not IsValid(proj) or not IsValid(ply) or not ply:Alive() then
            RemoveFuma(ply)
            return
        end

        local now = CurTime()
        local dt = now - precedent
        precedent = now

        -- fin de course sans rien toucher : le shuriken disparaît
        if now > fin then
            RemoveFuma(ply)
            return
        end

        local depart = proj:GetPos()
        local arrivee = depart + dir * Niv(ply, "vitesse", VITESSE) * dt

        -- 1. un mur (ou un décor solide) sur le trajet ?
        local mur = util.TraceHull({
            start = depart, endpos = arrivee, mins = -tM, maxs = tM,
            filter = { ply, proj }, mask = MASK_SOLID,
        })
        local finSegment = mur.Hit and mur.HitPos or arrivee

        -- 2. un joueur / PNJ dans la hitbox jusqu'au mur ?
        local cible
        for _, ent in ipairs(ents.FindAlongRay(depart, finSegment, -tH, tH)) do
            if EstCible(ent, ply) then cible = ent break end
        end

        if Dev() then
            debugoverlay.SweptBox(depart, finSegment, -tH, tH, angle_zero, 0.1, Color(0, 255, 0, 40))
        end

        if cible then
            Exploser(ply, cible:WorldSpaceCenter(), proj)
            RemoveFuma(ply)
            return
        end

        if mur.Hit and not mur.StartSolid then
            -- mur touché : téléportation automatique
            local pos, normale = mur.HitPos, mur.HitNormal
            RemoveFuma(ply)
            Teleporter(ply, pos, normale)
            return
        end

        proj:SetPos(arrivee)
    end)
end

net.Receive(NET_FUMA, function(_, ply)
    if not NA_Debloquee(ply, "fuma_tp") then return end   -- technique pas encore débloquée (F6)
    if not IsValid(ply) or not ply:Alive() then return end

    -- 2e appui : téléportation sur le shuriken
    local existing = fumaActive[ply]
    if IsValid(existing) then
        local pos = existing:GetPos()
        RemoveFuma(ply)
        Teleporter(ply, pos)
        return
    end

    -- 1er appui : mudras -> animation de lancer -> le shuriken part
    if enCours[ply] or (nextUse[ply] or 0) > CurTime() then return end
    enCours[ply] = true

    local mudra = Niv(ply, "duree_mudra", DUREE_MUDRA)
    JouerAnim(ply, ANIM_MUDRA)
    ply:EmitSound("base/mudra_sound_geams.wav", 75, 100)
    if NA_Mudra then NA_Mudra(ply, mudra) end   -- pas de coups pendant les mudras (_na_mudra.lua)

    timer.Simple(mudra, function()
        if not IsValid(ply) or not ply:Alive() then enCours[ply] = nil return end
        JouerAnim(ply, ANIM_LANCER)

        timer.Simple(Niv(ply, "delai_lancer", DELAI_LANCER), function()
            enCours[ply] = nil
            if not IsValid(ply) or not ply:Alive() then return end
            Lancer(ply)   -- direction = là où il regarde au moment du lancer
        end)
    end)
end)

hook.Add("PlayerDeath", "FumaTpMort", function(ply) RemoveFuma(ply) end)

hook.Add("PlayerDisconnected", "FumaTpCleanup", function(ply)
    RemoveFuma(ply)
    nextUse[ply] = nil
    enCours[ply] = nil
end)
