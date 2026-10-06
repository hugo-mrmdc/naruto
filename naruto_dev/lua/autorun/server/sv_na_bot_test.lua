--========================================================
-- Bot d'entraînement (SERVEUR) : un VRAI joueur (bot GMod) qui a le même modèle
-- que toi, donc les mêmes animations (wOS DynaBase) que les autres joueurs.
--
--   na_bot            -> crée un bot immobile, avec TON modèle, devant toi
--   na_bot_vire       -> supprime tous les bots
--
-- Réservé aux admins (ou à la console du serveur).
--========================================================

if not SERVER then return end

local function Autorise(ply)
    return not IsValid(ply) or ply:IsAdmin()
end

local VIE_BOT   = 10000   -- vie des bots d'entraînement
local REGEN_DELAI = 3     -- secondes sans coup avant de revenir à fond

local function Habiller(bot, modele)
    if not IsValid(bot) then return end
    bot.NA_BotTest = true
    bot.NA_BotModele = modele or bot.NA_BotModele
    if bot.NA_BotModele then bot:SetModel(bot.NA_BotModele) end
    bot:SetMaxHealth(VIE_BOT)
    bot:SetHealth(VIE_BOT)
end

-- se soigne à fond après REGEN_DELAI secondes sans coup
hook.Add("PostEntityTakeDamage", "NA_BotTest_Coup", function(ent)
    if IsValid(ent) and ent:IsPlayer() and ent.NA_BotTest then ent.NA_BotDernierCoup = CurTime() end
end)

timer.Create("NA_BotTest_Soin", 0.5, 0, function()
    for _, bot in ipairs(player.GetBots()) do
        if bot.NA_BotTest and bot:Alive() and bot:Health() < VIE_BOT
            and CurTime() - (bot.NA_BotDernierCoup or 0) > REGEN_DELAI then
            bot:SetHealth(VIE_BOT)
        end
    end
end)

concommand.Add("na_bot", function(ply)
    if not Autorise(ply) then return end

    if player.GetCount() >= game.MaxPlayers() then
        local msg = "[na_bot] serveur plein (" .. player.GetCount() .. "/" .. game.MaxPlayers() .. ") : relance la partie avec plus de joueurs max."
        if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, msg) else print(msg) end
        return
    end

    local modele = IsValid(ply) and ply:GetModel() or nil
    local avant = {}
    for _, p in ipairs(player.GetBots()) do avant[p] = true end

    RunConsoleCommand("bot")
    RunConsoleCommand("bot_zombie", "1")   -- immobile, ne tire pas

    timer.Simple(0.5, function()
        for _, bot in ipairs(player.GetBots()) do
            if avant[bot] then continue end
            Habiller(bot, modele)
            if IsValid(ply) then
                bot:SetPos(ply:GetPos() + ply:GetForward() * 120)
                bot:SetEyeAngles(Angle(0, ply:EyeAngles().y + 180, 0))
            end
        end
    end)
end)

concommand.Add("na_bot_vire", function(ply)
    if not Autorise(ply) then return end
    for _, bot in ipairs(player.GetBots()) do bot:Kick("na_bot_vire") end
end)

-- le gamemode peut remettre un modèle au respawn : on remet celui du bot
hook.Add("PlayerSpawn", "NA_BotTest_Modele", function(bot)
    if not bot.NA_BotTest then return end
    timer.Simple(0.1, function() Habiller(bot) end)
end)
