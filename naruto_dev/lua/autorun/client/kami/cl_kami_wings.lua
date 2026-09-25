--========================================================
-- Ailes de papier (CLIENT)
-- Touche d'activation + petit repère à l'écran pendant le vol.
--========================================================

local KEY    = KEY_H   -- touche des ailes de papier
local MODELE = "models/clan/ame/kami/ailekami.mdl"
local SEQ_AILES = "aileland"   -- séquence des ailes (la même que côté serveur)

-- Animation du joueur pendant le vol (nom exact : anim_extension_mod6.mdl)
local ANIM_VOL = "nrp_ninjutsu_trow_d70nj1_loop"

--[[
    Placement des ailes, appliqué à l'AFFICHAGE : le décalage (convars répliquées
    kami_aile_x/_y/_z, _pitch/_yaw/_roll, _echelle, définies dans sv_kami_wings.lua)
    est exprimé dans le repère de l'os Spine2 du joueur. Changer une valeur dans la
    console se voit immédiatement, pour tout le monde.
]]
local OS_DOS = "ValveBiped.Bip01_Spine2"
local cvAile = {}

local function CV(nom)
    local cv = cvAile[nom] or GetConVar("kami_aile_" .. nom)
    cvAile[nom] = cv
    return cv and cv:GetFloat() or 0
end

local function AfficherAiles(self, flags)
    local ply = self:GetParent()
    if IsValid(ply) then
        KamiWings.AppliquerCap(ply)
        ply:SetupBones()   -- squelette de CETTE image, pas de la précédente
    end
    local os = IsValid(ply) and ply:LookupBone(OS_DOS)
    local m = os and ply:GetBoneMatrix(os)

    if m then
        local pos, ang = LocalToWorld(
            Vector(CV("x"), CV("y"), CV("z")),
            Angle(CV("pitch"), CV("yaw"), CV("roll")),
            m:GetTranslation(), m:GetAngles())
        self:SetRenderOrigin(pos)
        self:SetRenderAngles(ang)
    end

    local echelle = CV("echelle")
    if echelle > 0 and self:GetModelScale() ~= echelle then self:SetModelScale(echelle, 0) end

    self:DrawModel(flags)

    -- Position réelle des os À L'ENDROIT OÙ LES AILES SONT AFFICHÉES (décalage compris) :
    -- les particules des ailes lisent ces positions, pour être exactement dessus.
    local pos = self.PosOs or {}
    for i = 0, self:GetBoneCount() - 1 do
        pos[i] = self:GetBonePosition(i)
    end
    self.PosOs = pos
end

-- Les props attachés au joueur n'avancent pas toujours leur animation tout seuls :
-- on demande au client de faire tourner leurs images.
hook.Add("NetworkEntityCreated", "NA_Wings_Anim", function(ent)
    if not IsValid(ent) then return end

    timer.Simple(0, function()
        if not IsValid(ent) then return end
        if ent:GetModel() ~= MODELE then return end

        ent.AutomaticFrameAdvance = true
        ent:SetPlaybackRate(1)
        ent.RenderOverride = AfficherAiles   -- placement réglable (convars kami_aile_*)

        local seq = ent:LookupSequence(SEQ_AILES)
        if seq and seq >= 0 and ent:GetSequence() ~= seq then
            ent:ResetSequence(seq)
        end
    end)
end)

surface.CreateFont("NA.Wings.Label", { font = "Roboto", size = 17, weight = 600 })

local wasDown = false

hook.Add("Think", "NA_Wings_Key", function()
    local ply = LocalPlayer()
    if vgui.GetKeyboardFocus() or gui.IsGameUIVisible() or not IsValid(ply) or ply:IsTyping() or not ply:Alive() then
        wasDown = false
        return
    end

    local down = input.IsKeyDown(KEY)
    if down and not wasDown and NA_TouchesDirectes() then
        NA_Lancer("kami_ailes")
    end
    wasDown = down
end)

-- Lancement (appelé par la touche ET par la barre de techniques)
NA_Cast = NA_Cast or {}
NA_Cast.kami_ailes = function()
    net.Start("kami_wings_toggle")
    net.SendToServer()
end

----------------------------------------------------------
-- Animation du joueur pendant le vol
----------------------------------------------------------
local function EnVol(ply)
    return IsValid(ply) and ply:Alive() and ply:GetNW2Bool("NA_Wings", false)
end

local function SeqVol(ply)
    if not ANIM_VOL or ANIM_VOL == "" then return -1 end
    local seq = ply:LookupSequence(ANIM_VOL)
    return seq or -1
end

hook.Add("CalcMainActivity", "NA_Wings_Anim", function(ply)
    if not EnVol(ply) then return end

    local seq = SeqVol(ply)
    if seq >= 0 then
        return ACT_INVALID, seq
    end
end)

hook.Add("UpdateAnimation", "NA_Wings_Anim_Update", function(ply)
    if not EnVol(ply) then return end

    local seq = SeqVol(ply)
    if seq < 0 then return end

    if ply:GetSequence() ~= seq then
        ply:SetSequence(seq)
        ply:SetCycle(0)
    end
    ply:SetPlaybackRate(1)
    return true
end)

-- Vérifie que l'animation de vol existe sur ton modèle
concommand.Add("na_wings_anim_check", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    print(string.format("[Ailes] %s -> %d (modèle : %s)", ANIM_VOL, ply:LookupSequence(ANIM_VOL), ply:GetModel()))
end)

-- Rappel discret des commandes pendant le vol
hook.Add("HUDPaint", "NA_Wings_HUD", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:GetNW2Bool("NA_Wings", false) then return end

    draw.SimpleText("AILES DE PAPIER  —  déplacement : ZQSD   monter : Espace   descendre : Ctrl   se poser : H",
        "NA.Wings.Label", ScrW() * 0.5,
        ScrH() - ((NA_SkillBar and NA_SkillBar.HauteurOccupee and NA_SkillBar.HauteurOccupee() or 88) + 70),
        Color(235, 235, 235, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)

----------------------------------------------------------
-- Particules de papier pendant le vol (kami_02_solve_geams_tornado_v2)
-- Le tourbillon monte par défaut (vitesse locale +Z du point de contrôle 0) :
-- on retourne l'orientation du point de contrôle 0 pour qu'il DESCENDE.
--   * CORPS : un tourbillon autour du torse du joueur, plus les feuilles de la Roue de
--     papier (kami_02_solve_geams_weapon) réparties sur tout le corps.
--   * AILES : un tourbillon centré sur chaque aile
--     (le modèle ailekami n'a pas de hitbox), recalé à chaque image.
-- (l'autre variante du .pcf : kami_02_solve_geams_tornado)
----------------------------------------------------------
game.AddParticles("particles/solve_kami_geams.pcf")

local FX_TOURBILLON = "kami_02_solve_geams_tornado_v2"
PrecacheParticleSystem(FX_TOURBILLON)

-- Les mêmes particules que dans les mains pendant la Roue de papier, sur tout le corps
local FX_PAPIER_CORPS = "kami_02_solve_geams_weapon"
PrecacheParticleSystem(FX_PAPIER_CORPS)

local HAUTEUR_TORSE = 50                        -- hauteur du tourbillon du corps au-dessus des pieds
local AILES_OS      = { { 1, 2, 3, 4, 5 }, { 6, 7, 8, 9, 10 } }   -- os de chaque aile (0-based, racine du modèle exclue) : le tourbillon est CENTRÉ sur leur moyenne
local HAUTEUR_AILES = 30                        -- les tourbillons des ailes sont relevés de cette hauteur (la v2 fait naître les feuilles 40 u sous le point)

-- Orientation retournée (rotation de 180° autour de X) : le "haut" du point de contrôle regarde vers le bas
local AVANT, DROITE, HAUT = Vector(1, 0, 0), Vector(0, -1, 0), Vector(0, 0, -1)

local fxVol = {}   -- joueur -> { corps = fx, ailes = { fx par os }, ent = ailes, prochaineRecherche = heure }

local function Placer(fx, pos)
    if not IsValid(fx) then return end
    fx:SetControlPoint(0, pos)
    fx:SetControlPointOrientation(0, AVANT, DROITE, HAUT)
end

local function Creer(pos)
    local fx = CreateParticleSystemNoEntity(FX_TOURBILLON, pos)
    Placer(fx, pos)
    return fx
end

local function TrouverAiles(ply)
    for _, e in ipairs(ents.FindByClass("prop_dynamic")) do
        if e:GetModel() == MODELE and e:GetParent() == ply then return e end
    end
end

local function ArreterFxVol(ply)
    local etat = fxVol[ply]
    if not etat then return end
    if IsValid(etat.corps) then etat.corps:StopEmission() end
    if IsValid(etat.papier) then etat.papier:StopEmission() end
    for _, fx in ipairs(etat.ailes) do
        if IsValid(fx) then fx:StopEmission() end
    end
    fxVol[ply] = nil
end

hook.Add("Think", "NA_Wings_Particules", function()
    for _, ply in ipairs(player.GetAll()) do
        local etat = fxVol[ply]

        if not EnVol(ply) or ply:IsDormant() then
            if etat then ArreterFxVol(ply) end
            continue
        end

        local pos = ply:GetPos() + Vector(0, 0, HAUTEUR_TORSE)

        if not etat then
            etat = {
                corps = Creer(pos),
                -- attachée au joueur : les feuilles naissent sur ses hitbox, donc partout sur le corps
                papier = CreateParticleSystem(ply, FX_PAPIER_CORPS, PATTACH_ABSORIGIN_FOLLOW, 0),
                ailes = {},
                prochaineRecherche = 0,
            }
            fxVol[ply] = etat
        end
        Placer(etat.corps, pos)

        -- entité ailes (créée côté serveur, elle peut arriver un peu après le joueur)
        if not IsValid(etat.ent) and CurTime() >= etat.prochaineRecherche then
            etat.prochaineRecherche = CurTime() + 0.5
            local ailes = TrouverAiles(ply)
            if ailes then
                etat.ent = ailes
                for _ = 1, #AILES_OS do
                    etat.ailes[#etat.ailes + 1] = Creer(ailes:GetPos())
                end
            end
        end

        -- recale chaque tourbillon d'aile sur son os
        if IsValid(etat.ent) then
            local posOs = etat.ent.PosOs or {}   -- remplies à l'affichage (AfficherAiles)
            for i, fx in ipairs(etat.ailes) do
                -- centre de l'aile = moyenne des positions de tous ses os
                local somme, n = Vector(0, 0, 0), 0
                for _, os in ipairs(AILES_OS[i]) do
                    local opos = posOs[os]
                    if opos then somme = somme + opos; n = n + 1 end
                end
                if n > 0 then Placer(fx, somme / n + Vector(0, 0, HAUTEUR_AILES)) end
            end
        end
    end

    -- joueurs partis
    for ply in pairs(fxVol) do
        if not IsValid(ply) then ArreterFxVol(ply) end
    end
end)
