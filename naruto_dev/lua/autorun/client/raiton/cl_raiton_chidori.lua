--========================================================
-- Raiton : Chidori (CLIENT)
-- Lancement depuis la barre de techniques, et particule solve_raiton_aura_ruee sur la MAIN GAUCHE du lanceur tant que
-- NW2Float "NA_ChidoriFin" est dans le futur (posé par sv_raiton_chidori.lua : charge + course). Vue par tout le monde.
-- L'onde d'impact est jouée par cl_raiton_poing.lua (même message que le Poing de foudre).
--========================================================

game.AddParticles("particles/solve_raiton.pcf")
local FX_MAIN = "solve_raiton_aura_ruee"
PrecacheParticleSystem(FX_MAIN)

NA_Cast = NA_Cast or {}
NA_Cast.raiton_chidori = function()
    net.Start("raiton_chidori_cast")
    net.SendToServer()
end

-- solve_raiton_aura_ruee est une AURA : ses particules naissent au hasard sur tout le MODÈLE de l'entité à laquelle elle
-- est attachée ("Position on Model Random" + "Movement Lock to Bone"). Attachée au joueur, elle couvrirait tout le corps.
-- On l'attache donc à un petit modèle invisible (une sphère de 3 unités environ) collé à la MAIN GAUCHE : l'aura n'existe
-- que sur la main.

-- Main GAUCHE : point d'attache et os. J'avais pris "anim_attachment_RH" (côté droit du modèle) et c'était la mauvaise main :
-- on prend donc l'autre, "anim_attachment_LH", et les noms d'os correspondants. Si l'aura apparaît sur la mauvaise main :
-- inverse ATTACHE_GAUCHE (LH <-> RH) et NOMS_G (L <-> R).
local ATTACHE_GAUCHE = "anim_attachment_LH"
local NOMS_G = { "ValveBiped.Bip01_R_Hand", "Bip01 R Hand", "Bip01_R_Hand", "R Hand", "RightHand" }
local MODELE_MAIN = "models/hunter/misc/sphere025x025.mdl"   -- rayon ~12 unités à l'échelle 1
local ECHELLE_MAIN = 0.35                                    -- ~4 unités de rayon : de la taille d'une main

local function OsMainGauche(ply)
    for _, n in ipairs(NOMS_G) do
        local id = ply:LookupBone(n)
        if id then return id end
    end
end

-- Position de la main gauche : le point d'attache si le modèle en a un, sinon l'os de la main
local function PosMain(ply)
    ply:SetupBones()
    local att = ply:LookupAttachment(ATTACHE_GAUCHE)
    if att and att > 0 then
        local a = ply:GetAttachment(att)
        if a then return a.Pos end
    end
    local os = OsMainGauche(ply)
    local m = os and ply:GetBoneMatrix(os)
    return m and m:GetTranslation() or ply:WorldSpaceCenter()
end

local mains = {}   -- joueur -> { mdl, fx }

local function Couper(ply)
    local m = mains[ply]
    if m then
        if m.fx and m.fx:IsValid() then m.fx:StopEmission(false, true) end
        if IsValid(m.mdl) then m.mdl:Remove() end
    end
    mains[ply] = nil
end

-- Le petit modèle est ACCROCHÉ à la main par le moteur (pas replacé à la main par nous) : il suit exactement,
-- à chaque image, y compris pendant l'animation de course :
--   1. SetParent sur le point d'attache de la main si le modèle du joueur en a un ;
--   2. sinon FollowBone sur l'os de la main ;
--   3. sinon (ni l'un ni l'autre) il est replacé à chaque image (hook PreRender plus bas).
local function CreerMain(ply)
    local mdl = ClientsideModel(MODELE_MAIN, RENDERGROUP_OTHER)
    if not IsValid(mdl) then return end
    mdl:SetModelScale(ECHELLE_MAIN, 0)
    mdl:SetNoDraw(true)   -- invisible : seule l'aura se voit

    local accroche = false
    local att = ply:LookupAttachment(ATTACHE_GAUCHE)
    if att and att > 0 then
        mdl:SetParent(ply, att)
        mdl:SetLocalPos(vector_origin)
        mdl:SetLocalAngles(angle_zero)
        accroche = true
    else
        local os = OsMainGauche(ply)
        if os then
            mdl:SetParent(ply)
            mdl:FollowBone(ply, os)
            mdl:SetLocalPos(vector_origin)
            accroche = true
        end
    end
    if not accroche then mdl:SetPos(PosMain(ply)) end

    local fx = CreateParticleSystem(mdl, FX_MAIN, PATTACH_ABSORIGIN_FOLLOW, 0)
    return { mdl = mdl, fx = fx, accroche = accroche }
end

-- cycle de vie : l'aura existe tant que NW2Float "NA_ChidoriFin" est dans le futur
hook.Add("Think", "RaitonChidori_Main", function()
    local now = CurTime()
    for _, ply in ipairs(player.GetAll()) do
        local actif = ply:Alive() and not ply:IsDormant() and ply:GetNW2Float("NA_ChidoriFin", 0) > now
        if actif then
            local m = mains[ply]
            if not (m and IsValid(m.mdl) and m.fx and m.fx:IsValid()) then
                Couper(ply)
                mains[ply] = CreerMain(ply)
            end
        elseif mains[ply] then
            Couper(ply)
        end
    end
    for ply in pairs(mains) do
        if not IsValid(ply) then Couper(ply) end   -- joueurs partis
    end
end)

-- repli : si le modèle n'a pu être accroché ni à un point d'attache ni à un os, on le replace à la main à chaque image
hook.Add("PreRender", "RaitonChidori_MainPos", function()
    for ply, m in pairs(mains) do
        if IsValid(ply) and IsValid(m.mdl) and not m.accroche then m.mdl:SetPos(PosMain(ply)) end
    end
end)

----------------------------------------------------------
-- Animation de COURSE : forcée à chaque image tant que la course dure (NA_ChidoriVit > 0), quoi qu'il arrive
-- (saut, chute, autre animation...). Même principe que la pose du dragon d'encre : CalcMainActivity + UpdateAnimation
-- imposent la séquence, et la boucle est avancée à la main (le cycle revient à 0 à chaque tour). Ces hooks tournent
-- pour TOUS les joueurs : le test vient en premier. Le nom de la séquence n'est pas mis en cache (wOS DynaBase peut
-- changer les index). La première animation de la liste qui existe sur le modèle est jouée.
----------------------------------------------------------
local SEQ_COURSE = {
    "M_NI_SHT_Ninjutsu_Chidori_Run_Lv3_Loop", "nrp_ninjutsu_trow_chidori_run_lv3_loop", "m_ni_ninjutsu_chidori_run_lv3_loop",
}

local function EnCourse(ply)
    return ply:Alive() and ply:GetNW2Float("NA_ChidoriFin", 0) > CurTime() and ply:GetNW2Float("NA_ChidoriVit", 0) > 0
end

local function SeqCourse(ply)
    for _, nom in ipairs(SEQ_COURSE) do
        local seq = ply:LookupSequence(nom)
        if seq and seq >= 0 then return seq end
    end
end

hook.Add("CalcMainActivity", "NA_RaitonChidori_Course", function(ply)
    if not EnCourse(ply) then return end
    local seq = SeqCourse(ply)
    if seq then return ACT_INVALID, seq end
    return ACT_HL2MP_RUN, -1
end)

hook.Add("UpdateAnimation", "NA_RaitonChidori_Course_Update", function(ply)
    if not EnCourse(ply) then
        ply.NA_ChidoriT0 = nil
        return
    end
    local seq = SeqCourse(ply)
    if not seq then return end

    ply.NA_ChidoriT0 = ply.NA_ChidoriT0 or CurTime()
    if ply:GetSequence() ~= seq then ply:SetSequence(seq) end
    -- boucle manuelle : le cycle avance tout seul et repart à 0 à chaque tour, même si la séquence n'est pas marquée "loop"
    local duree = math.max(ply:SequenceDuration(seq), 0.1)
    ply:SetCycle(((CurTime() - ply.NA_ChidoriT0) / duree) % 1)
    ply:SetPlaybackRate(0)
    return true
end)
