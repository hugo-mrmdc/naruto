--========================================================
-- Suiton : Tsunami (PARTAGÉ serveur + client)
--
-- Tant que NW2Float "NA_TsunamiFin" est dans le futur, le joueur est monté sur la vague, comme sur un dragon :
--   - la vague l'emporte EN CONTINU : sa vitesse horizontale est tenue à NW2Float "NA_TsunamiVit", dans la direction
--     où il REGARDE (il dirige la vague avec la souris) ;
--   - il est TENU À HAUTEUR DE LA CRÊTE : NA_Tsunami.Haut au-dessus du sol, qu'il suive les pentes. Il ne vole pas :
--     aucune commande de vol, la hauteur est fixe ; sauter est sans effet.
-- Fait dans SetupMove, exécuté par le serveur ET en prédiction par le client : la vague avance de façon fluide.
-- Le reste de la technique est dans server/suiton/sv_suiton_tsunami.lua et client/suiton/cl_suiton_tsunami.lua.
--========================================================

if SERVER then AddCSLuaFile() end

-- Taille de la vague et hauteur de sa crête. Le modèle fait 396 de large, 290 de profondeur et 209 de haut à
-- l'échelle 1 (mesuré sur le .vvd) : à 1.5 la crête est à ~314 unités du sol, la vague mesure ~600 de large.
-- Le joueur est tenu à la hauteur de la crête : une plus grande échelle le tient plus haut.
NA_Tsunami = NA_Tsunami or {}
NA_Tsunami.Echelle = 1.5
NA_Tsunami.Enfonce  = 60                      -- le joueur est tenu un peu SOUS la crête (unités) : plus grand = plus bas
NA_Tsunami.Haut    = 209 * NA_Tsunami.Echelle - NA_Tsunami.Enfonce   -- hauteur du joueur au-dessus du sol

local RAIDEUR = 12     -- vitesse de rattrapage vers la hauteur voulue
local VMAX    = 700    -- vitesse verticale maximale du rattrapage

hook.Add("SetupMove", "NA_Tsunami_Avance", function(ply, mv)
    if ply:GetNW2Float("NA_TsunamiFin", 0) <= CurTime() then return end

    local vit = ply:GetNW2Float("NA_TsunamiVit", 0)
    if vit <= 0 then return end

    local dir = Angle(0, mv:GetAngles().y, 0):Forward()
    local v = mv:GetVelocity()

    -- hauteur : on vise le sol + la hauteur de la crête (suit les pentes), sans gravité ni saut
    local o = mv:GetOrigin()
    local sol = util.TraceLine({
        start = o + Vector(0, 0, 40), endpos = o - Vector(0, 0, 600),
        filter = ply, mask = MASK_PLAYERSOLID_BRUSHONLY,
    })
    local vz = v.z
    if sol.Hit then
        vz = math.Clamp((sol.HitPos.z + NA_Tsunami.Haut - o.z) * RAIDEUR, -VMAX, VMAX)
    end
    mv:SetVelocity(Vector(dir.x * vit, dir.y * vit, vz))
end)
