--========================================================
-- Kaguya : Armure d'os (CLIENT)
--
-- Lancement depuis la barre de techniques, et AFFICHAGE de l'armure sur chaque
-- joueur qui l'a (NW2Bool "NA_ArmureOs") : tout le monde la voit donc.
--
-- L'armure est recalée à chaque image sur l'os de la colonne du joueur : elle
-- suit l'animation comme une fusion au squelette, tout en acceptant le décalage
-- envoyé par le serveur (réglages dans sv_kaguya_armure.lua).
--========================================================

NA_Cast = NA_Cast or {}
NA_Cast.kaguya_armure = function()
    net.Start("kaguya_armure_cast")
    net.SendToServer()
end

local modeles = {}   -- joueur -> modèle affiché

local function Porte(ply)
    return IsValid(ply) and ply:Alive() and ply:GetNW2Bool("NA_ArmureOs", false)
        and not ply:GetNWBool("IsInvisible", false)
end

local function Supprimer(ply)
    local m = modeles[ply]
    if IsValid(m) then m:Remove() end
    modeles[ply] = nil
end

hook.Add("PostPlayerDraw", "NA_KaguyaArmure_Dessin", function(ply)
    if not Porte(ply) then
        Supprimer(ply)
        return
    end

    local modele = ply:GetNW2String("NA_ArmureModele", "")
    if modele == "" then return end

    local os = ply:LookupBone(ply:GetNW2String("NA_ArmureOsNom", "ValveBiped.Bip01_Spine"))
    if not os then return end
    local mat = ply:GetBoneMatrix(os)   -- os déjà animé pour cette image
    if not mat then return end

    local m = modeles[ply]
    if not IsValid(m) or m:GetModel() ~= modele then
        Supprimer(ply)
        m = ClientsideModel(modele, RENDERGROUP_OPAQUE)
        if not IsValid(m) then return end
        m:SetNoDraw(true)
        modeles[ply] = m
    end
    m:SetModelScale(ply:GetNW2Float("NA_ArmureEchelle", 1), 0)

    local dec = ply:GetNW2Vector("NA_ArmureDecalage", vector_origin)
    local rot = ply:GetNW2Angle("NA_ArmureRotation", angle_zero)

    local pos, ang = mat:GetTranslation(), mat:GetAngles()
    ang:RotateAroundAxis(ang:Right(), rot.p)
    ang:RotateAroundAxis(ang:Up(), rot.y)
    ang:RotateAroundAxis(ang:Forward(), rot.r)
    pos = pos + ang:Forward() * dec.x + ang:Right() * dec.y + ang:Up() * dec.z

    m:SetPos(pos)
    m:SetAngles(ang)

    -- couleurs propres : sinon l'armure prend la teinte du joueur
    local r, g, b = render.GetColorModulation()
    local blend = render.GetBlend()
    render.SetColorModulation(1, 1, 1)
    render.SetBlend(1)
    m:DrawModel()
    render.SetColorModulation(r, g, b)
    render.SetBlend(blend)
end)

hook.Add("EntityRemoved", "NA_KaguyaArmure_Nettoyage", function(ent)
    if ent:IsPlayer() then Supprimer(ent) end
end)
