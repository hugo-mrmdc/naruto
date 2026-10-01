--========================================================
-- Inkuton : Singes d'encre (CLIENT)
-- Lancement (barre de techniques) + marque : le lanceur voit sa cible à travers les murs tant que
-- NW2Float "NA_SingeMarqueFin" n'est pas écoulé (posé par sv_inkuton_singes.lua).
--========================================================

NA_Cast = NA_Cast or {}
NA_Cast.inkuton_singes = function()
    net.Start("inkuton_singes_cast")
    net.SendToServer()
end

-- lancement refusé par le serveur (pas de cible...) : NA_Lancer avait déjà lancé la recharge locale
net.Receive("inkuton_singes_refus", function()
    NA_DernierLancer.inkuton_singes = nil
end)

local COULEUR =Color(235, 235, 235)

hook.Add("PreDrawHalos", "InkutonSinges_Marque", function()
    local moi = LocalPlayer()
    local marques = {}
    for _, ent in ipairs(ents.GetAll()) do
        -- seulement tant que les singes sont accrochés : plus de halo une fois qu'ils ont disparu
        if ent:GetNW2Bool("NA_Singes", false) and ent:GetNW2Entity("NA_SingeMarqueDe") == moi then
            marques[#marques + 1] = ent
        end
    end
    if #marques > 0 then halo.Add(marques, COULEUR, 3, 3, 2, true, true) end   -- true, true : additif + à travers les murs
end)
