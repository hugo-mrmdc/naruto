--========================================================
-- Bakuton : Dragon d'argile (CLIENT)
-- Lancement depuis la barre de techniques, et affichage du dragon sous tous les joueurs dont
-- NW2Bool "NA_Dragon" est vrai (posé par sv_bakuton_dragon.lua) : tout le monde le voit.
-- Le dragon est un modèle côté client collé à la position du joueur (prédite : pas de retard en vol),
-- qui joue atg_fly en boucle et tourne avec le corps (même cap que les ailes de papier).
--========================================================

--========================================================
-- RÉGLAGES
--========================================================
local MODELE      = "models/bakuton/atg_dragon_bakuton.mdl"
local ANIM        = "atg_fly"
local ECHELLE     = 0.5
local DECALAGE    = Vector(-10, 0, -70)   -- par rapport aux pieds, dans le repère du dragon (z négatif = plus bas)
local DECALAGE_YAW = 0                  -- si le dragon ne regarde pas devant : essayer 90, -90 ou 180
--========================================================

NA_Cast = NA_Cast or {}
NA_Cast.bakuton_dragon = function()
    net.Start("bakuton_dragon_cast")
    net.SendToServer()
end

local dragons = {}   -- joueur -> modèle client

local function Arreter(ply)
    if IsValid(dragons[ply]) then dragons[ply]:Remove() end
    dragons[ply] = nil
end

-- éclairage fixe : sinon le dragon devient noir quand il passe dans le sol ou un mur
local function Dessiner(self)
    render.SuppressEngineLighting(true)
    render.ResetModelLighting(0.7, 0.7, 0.7)
    render.SetModelLighting(BOX_TOP, 1, 1, 1)
    self:DrawModel()
    render.SuppressEngineLighting(false)
end

local function Creer()
    local ent = ClientsideModel(MODELE)
    if not IsValid(ent) then return end
    ent:SetModelScale(ECHELLE, 0)
    ent.RenderOverride = Dessiner
    local id = ent:LookupSequence(ANIM)
    if id >= 0 then ent:ResetSequence(id) end
    return ent
end

-- une fois par image, avant le dessin : position et cap à jour (le cap du corps vient de KamiWings_BodyYaw)
hook.Add("PreRender", "NA_BakutonDragon", function()
  for ply, ent in pairs(dragons) do
    if not IsValid(ply) or not IsValid(ent) then continue end
    local yaw = (ply.KamiWingsYaw or ply:EyeAngles().y) + DECALAGE_YAW
    local ang = Angle(0, yaw, 0)
    ent:SetPos(ply:GetPos() + ang:Forward() * DECALAGE.x + ang:Right() * DECALAGE.y + Vector(0, 0, DECALAGE.z))
    ent:SetAngles(ang)
    -- même principe que les ailes de papier : lecture automatique, toujours atg_fly
    local id = ent:LookupSequence(ANIM)
    if id >= 0 and ent:GetSequence() ~= id then ent:ResetSequence(id) end
    ent.AutomaticFrameAdvance = true
    ent:SetPlaybackRate(1)
  end
end)

hook.Add("Think", "NA_BakutonDragon_FX", function()
    for _, ply in ipairs(player.GetAll()) do
        local actif = ply:Alive() and not ply:IsDormant() and ply:GetNW2Bool("NA_Dragon", false)
        if not actif then
            if dragons[ply] then Arreter(ply) end
        elseif not IsValid(dragons[ply]) then
            dragons[ply] = Creer()
        end
    end
    for ply in pairs(dragons) do
        if not IsValid(ply) then Arreter(ply) end
    end
end)

-- animation du joueur sur le dragon : pose debout normale (comme le ride Inkuton)
local function SurDragon(ply)
    return IsValid(ply) and ply:Alive() and ply:GetNW2Bool("NA_Dragon", false)
end

hook.Add("CalcMainActivity", "NA_BakutonDragon_Anim", function(ply)
    if SurDragon(ply) then return ACT_HL2MP_IDLE, -1 end
end)

hook.Add("UpdateAnimation", "NA_BakutonDragon_Anim_Update", function(ply)
    if not SurDragon(ply) then return end
    ply:SetPlaybackRate(1)
    return true
end)

-- Rappel discret
hook.Add("HUDPaint", "NA_BakutonDragon_HUD", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:GetNW2Bool("NA_Dragon", false) then return end

    draw.SimpleText("DRAGON D'ARGILE  —  déplacement : ZQSD   monter : Espace   descendre : Ctrl   quitter le dragon : E",
        "DermaDefaultBold", ScrW() * 0.5, ScrH() - 160,
        Color(235, 235, 235, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)
