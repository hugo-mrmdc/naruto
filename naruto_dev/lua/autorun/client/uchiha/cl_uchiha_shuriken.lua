--========================================================
-- Uchiha : Shuriken géant (CLIENT)
-- Touche de lancement. Le projectile et ses flammes sont gérés par
-- l'entité uchiha_giant_shuriken (lua/entities).
--========================================================

local KEY = KEY_SEMICOLON

game.AddParticles("particles/atg_reworkpvp.pcf")
PrecacheParticleSystem("katon_boule_feu_outils4")
PrecacheParticleSystem("katon_boule_feu_atg2")

local last = false
hook.Add("Think", "uchiha_shuriken_key", function()
    local lp = LocalPlayer()
    if vgui.GetKeyboardFocus() or gui.IsGameUIVisible() or not IsValid(lp) or lp:IsTyping() or not lp:Alive() then
        last = false
        return
    end
    local pressed = input.IsKeyDown(KEY)
    if pressed and not last and NA_TouchesDirectes() then
        NA_Lancer("uchiha_shuriken")
    end
    last = pressed
end)

NA_Cast = NA_Cast or {}
NA_Cast.uchiha_shuriken = function()
    net.Start("uchiha_shuriken_cast")
    net.SendToServer()
end
