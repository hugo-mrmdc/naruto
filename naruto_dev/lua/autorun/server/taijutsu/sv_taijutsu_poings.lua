--========================================================
-- Taijutsu : réservé aux poings (SERVEUR)
--
--   NA_TaiPoings(ply) -> true si le joueur tient les poings (naruto_poings).
--   Sinon la technique ne part pas (sans message).
--   Appelé au début du lancement de chaque technique taijutsu.
--========================================================

if not SERVER then return end

function NA_TaiPoings(ply)
    local arme = IsValid(ply) and ply:GetActiveWeapon()
    return IsValid(arme) and arme:GetClass() == "naruto_poings"
end
