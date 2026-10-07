--========================================================
-- Jinton : Bouclier (CLIENT)
-- Lancement depuis la barre de techniques. La sphère est l'entité jinton_bouclier.
--========================================================

NA_Cast = NA_Cast or {}
NA_Cast.jinton_bouclier = function()
    net.Start("jinton_bouclier_cast")
    net.SendToServer()
end

--========================================================
-- Particules d'explosion attachées à un joueur / une cible (attachement natif du moteur :
-- la particule est liée à l'entité, elle la suit toute seule)
--========================================================
net.Receive("jinton_bouclier_fx", function()
    local ent = net.ReadEntity()
    local nom = net.ReadString()
    if not IsValid(ent) then return end
    PrecacheParticleSystem(nom)
    CreateParticleSystem(ent, nom, PATTACH_ABSORIGIN_FOLLOW, 0)
end)
