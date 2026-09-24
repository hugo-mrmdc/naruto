--========================================================
-- Jiton : Nuage de sable (CLIENT)
-- Lancement depuis la barre de techniques, et affichage du nuage sous tous les
-- joueurs dont NW2Bool "NA_Nuage" est vrai (posé par sv_jiton_nuage.lua) :
-- tout le monde le voit, y compris ceux qui arrivent après le lancement.
--========================================================

--========================================================
-- RÉGLAGES
--========================================================
local FX      = "[1]_sand_cloud"   -- particles/atg_faris.pcf
local DECALAGE = Vector(0, 0, 0)   -- position du nuage par rapport aux pieds (z négatif = plus bas)
--========================================================

NA_Cast = NA_Cast or {}
NA_Cast.jiton_nuage = function()
    net.Start("jiton_nuage_cast")
    net.SendToServer()
end

game.AddParticles("particles/atg_faris.pcf")
PrecacheParticleSystem(FX)

-- joueur -> ancre invisible qui suit sa POSITION mais garde des angles fixes
-- (le nuage ne tourne pas avec la caméra)
local ancres = {}

local function Arreter(ply)
    local ancre = ancres[ply]
    if IsValid(ancre) then
        ancre:StopParticles()
        ancre:Remove()
    end
    ancres[ply] = nil
end

hook.Add("Think", "NA_JitonNuage_FX", function()
    for _, ply in ipairs(player.GetAll()) do
        local actif = ply:Alive() and not ply:IsDormant() and ply:GetNW2Bool("NA_Nuage", false)
        local ancre = ancres[ply]

        if not actif then
            if ancre then Arreter(ply) end
        elseif not IsValid(ancre) then
            ancre = ClientsideModel("models/props_junk/PopCan01a.mdl")
            if IsValid(ancre) then
                ancre:SetNoDraw(true)
                ancre:SetAngles(angle_zero)
                ancre:SetPos(ply:GetPos() + DECALAGE)
                ancres[ply] = ancre
                ParticleEffectAttach(FX, PATTACH_ABSORIGIN_FOLLOW, ancre, 0)
            end
        else
            ancre:SetPos(ply:GetPos() + DECALAGE)
        end
    end

    for ply in pairs(ancres) do
        if not IsValid(ply) then Arreter(ply) end
    end
end)

-- Rappel discret
hook.Add("HUDPaint", "NA_JitonNuage_HUD", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:GetNW2Bool("NA_Nuage", false) then return end

    draw.SimpleText("NUAGE DE SABLE  —  déplacement : ZQSD   monter : Espace   descendre : Ctrl   quitter le nuage : E",
        "DermaDefaultBold", ScrW() * 0.5, ScrH() - 160,
        Color(235, 235, 235, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)
