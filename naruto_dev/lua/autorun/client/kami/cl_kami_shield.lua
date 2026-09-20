--========================================================
-- Paper Shield (CLIENT)
-- Touche de lancement + particules de papier autour du joueur.
--========================================================

local KEY      = KEY_P
local PCF_PATH = "particles/atg_faris.pcf"
local FX_NAME  = "[2]_paper_shield"   -- nom exact dans le .pcf

game.AddParticles(PCF_PATH)
PrecacheParticleSystem(FX_NAME)

----------------------------------------------------------
-- Touche
----------------------------------------------------------
local wasDown = false

hook.Add("Think", "KamiShield_Key", function()
    local ply = LocalPlayer()
    if vgui.GetKeyboardFocus() or gui.IsGameUIVisible() or not IsValid(ply) or ply:IsTyping() or not ply:Alive() then
        wasDown = false
        return
    end

    local down = input.IsKeyDown(KEY)
    if down and not wasDown and NA_TouchesDirectes() then
        NA_Lancer("kami_bouclier")
    end
    wasDown = down
end)

-- Lancement (appelé par la touche ET par la barre de techniques)
NA_Cast = NA_Cast or {}
NA_Cast.kami_bouclier = function()
    net.Start("kami_shield_cast")
    net.SendToServer()
end

----------------------------------------------------------
-- Particules
-- Portées par une petite entité invisible qui suit la POSITION du joueur mais
-- garde des angles fixes : l'effet ne tourne pas avec la caméra.
----------------------------------------------------------
local anchors = {}

local function Stop(ply)
    local anchor = anchors[ply]
    if IsValid(anchor) then
        anchor:StopParticles()
        anchor:Remove()
    end
    anchors[ply] = nil
end

net.Receive("kami_shield_fx", function()
    local ply = net.ReadEntity()
    local duree = net.ReadFloat()
    if not IsValid(ply) then return end

    Stop(ply)

    local anchor = ClientsideModel("models/props_junk/PopCan01a.mdl")
    if not IsValid(anchor) then return end
    anchor:SetNoDraw(true)
    anchor:SetPos(ply:GetPos())
    anchor:SetAngles(Angle(0, 0, 0))
    anchors[ply] = anchor

    ParticleEffectAttach(FX_NAME, PATTACH_ABSORIGIN_FOLLOW, anchor, 0)

    -- filet de sécurité si le message d'arrêt se perd
    timer.Simple(duree + 0.5, function()
        if anchors[ply] == anchor then Stop(ply) end
    end)
end)

net.Receive("kami_shield_stop", function()
    local ply = net.ReadEntity()
    Stop(ply)
end)

-- les ancres suivent leur joueur
hook.Add("Think", "KamiShield_Follow", function()
    for ply, anchor in pairs(anchors) do
        if not IsValid(ply) or not ply:Alive() then
            Stop(ply)
        elseif IsValid(anchor) then
            anchor:SetPos(ply:GetPos())
        end
    end
end)

-- Test isolé : joue le bouclier sur toi, sans passer par le serveur
concommand.Add("kami_shield_test", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    ParticleEffect(FX_NAME, ply:GetPos(), Angle(0, 0, 0))
    print("[PaperShield] effet '" .. FX_NAME .. "' lancé à " .. tostring(ply:GetPos()))
end)
