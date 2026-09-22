--========================================================
-- Rendu toon plein écran (CLIENT)
-- Shader materials/shaders/toonized_orugi.vmt (+ shaders/fxc/*.vcs).
-- Réglages du rendu ($c0_x niveaux, $c0_z contours...) : dans le .vmt.
--   na_toon 0  -> désactivé
--   na_toon_mat "shaders/toonized_orugi_motionblur" -> variante flou de mouvement
--========================================================

-- désactivé par défaut : les .vcs ne sont lus qu'au démarrage de GMod, sinon écran bleu
local cv    = CreateClientConVar("na_toon", "0", true, false, "1 = rendu toon plein écran")
local cvMat = CreateClientConVar("na_toon_mat", "shaders/toonized_orugi", true, false, "matériau du rendu toon")

hook.Add("RenderScreenspaceEffects", "NA_Toon", function()
    if not cv:GetBool() then return end

    render.UpdateScreenEffectTexture()
    render.SetMaterial(Material(cvMat:GetString()))
    render.DrawScreenQuad()
end)
