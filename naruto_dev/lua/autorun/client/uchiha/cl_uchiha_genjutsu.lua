--========================================================
-- Uchiha : Genjutsu du Sharingan (CLIENT)
-- Lancement (touche ou barre de techniques). La victime (joueur local uniquement)
-- voit le modèle du genjutsu autour d'elle pendant toute la durée du stun.
--========================================================

local MODEL   = "models/clan/konoha/uchiha/nr_sharingan_genjutsu1.mdl"
local KEY     = KEY_PERIOD
local ECHELLE = 1       -- taille du modèle (il fait ~1000 unités de large : il englobe la victime)
local ROTATION = 20     -- degrés par seconde
local FONDU   = 0.4     -- secondes de fondu à l'apparition et à la disparition

local last = false
hook.Add("Think", "uchiha_genjutsu_key", function()
    local lp = LocalPlayer()
    if vgui.GetKeyboardFocus() or gui.IsGameUIVisible() or not IsValid(lp) or lp:IsTyping() or not lp:Alive() then
        last = false
        return
    end
    local pressed = input.IsKeyDown(KEY)
    if pressed and not last and NA_TouchesDirectes() then
        NA_Lancer("uchiha_genjutsu")
    end
    last = pressed
end)

NA_Cast = NA_Cast or {}
NA_Cast.uchiha_genjutsu = function()
    net.Start("uchiha_genjutsu_cast")
    net.SendToServer()
end

local mdl, debut, fin = nil, 0, 0

local function Nettoyer()
    if IsValid(mdl) then mdl:Remove() end
    mdl, fin = nil, 0
end

net.Receive("uchiha_genjutsu_cible", function()
    local cible = net.ReadEntity()
    local duree = net.ReadFloat()
    if cible ~= LocalPlayer() then return end   -- seule la victime voit le genjutsu

    Nettoyer()
    mdl = ClientsideModel(MODEL, RENDERGROUP_TRANSLUCENT)
    if not IsValid(mdl) then return end
    mdl:SetModelScale(ECHELLE, 0)
    mdl:SetRenderMode(RENDERMODE_TRANSALPHA)
    mdl:DrawShadow(false)
    mdl:SetPos(cible:GetPos())
    debut, fin = CurTime(), CurTime() + duree
end)

hook.Add("Think", "uchiha_genjutsu_suivi", function()
    if not IsValid(mdl) then return end
    local lp = LocalPlayer()
    local now = CurTime()
    if now >= fin or not IsValid(lp) or not lp:Alive() then Nettoyer() return end

    mdl:SetPos(lp:GetPos())
    mdl:SetAngles(Angle(0, (now - debut) * ROTATION, 0))
    local a = math.min((now - debut) / FONDU, (fin - now) / FONDU, 1)
    mdl:SetColor(ColorAlpha(color_white, 255 * math.Clamp(a, 0, 1)))
end)
