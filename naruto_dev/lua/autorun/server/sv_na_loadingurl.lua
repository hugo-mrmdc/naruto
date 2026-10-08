--========================================================
-- Écran de chargement natif (SERVEUR)
--
--   Applique sv_loadingurl depuis le ConVar na_loadingurl.
--   Exemple (server.cfg) :
--       na_loadingurl "https://mon-site.fr/narutorp/loading.html"
--   Le dossier addon "loadingscreen/" (loading.html + load1..4.png) doit
--   être hébergé à cette adresse.
--========================================================
local cv = CreateConVar("na_loadingurl", "", FCVAR_ARCHIVE, "URL de la page de chargement (loadingscreen/loading.html hébergée)")

local function Appliquer()
    local url = string.Trim(cv:GetString())
    if url ~= "" then RunConsoleCommand("sv_loadingurl", url) end
end

hook.Add("Initialize", "NA.LoadingUrl", Appliquer)
cvars.AddChangeCallback("na_loadingurl", function() Appliquer() end, "NA.LoadingUrl")
