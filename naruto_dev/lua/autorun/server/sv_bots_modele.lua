--========================================================
-- Modèle des bots (fake players) (SERVEUR)
--
-- Un bot prend un modèle de joueur par défaut, qui n'a pas les animations nrp_*
-- (celles des techniques : étourdissement, prison aqueuse...) : elles ne se jouent
-- pas sur lui. À chaque apparition, il prend donc le modèle du premier vrai joueur
-- connecté (MODELE_DEFAUT s'il n'y en a aucun).
--========================================================

local MODELE_DEFAUT = "models/tenue/senju/genin/senju_a.mdl"

hook.Add("PlayerSpawn", "NA_Bots_Modele", function(bot)
    if not bot:IsBot() then return end

    timer.Simple(0, function()   -- après le choix du modèle par défaut
        if not IsValid(bot) then return end
        local modele = MODELE_DEFAUT
        for _, ply in ipairs(player.GetHumans()) do
            modele = ply:GetModel()
            break
        end
        bot:SetModel(modele)
    end)
end)
