--========================================================
-- Shuriken de papier (CLIENT)
-- Touche de lancement. Le projectile et ses particules sont gérés par
-- l'entité kami_paper_shuriken (lua/entities).
--========================================================

local KEY = KEY_M   -- pense à faire "unbind m" (lié à Stop Motion Helper par défaut chez toi)

game.AddParticles("particles/atg_faris.pcf")
PrecacheParticleSystem("[2]_paper_shuriken")
PrecacheParticleSystem("[2]_paper_impact")

local wasDown = false

hook.Add("Think", "KamiShuriken_Key", function()
    local ply = LocalPlayer()
    if vgui.GetKeyboardFocus() or gui.IsGameUIVisible() or not IsValid(ply) or ply:IsTyping() or not ply:Alive() then
        wasDown = false
        return
    end

    local down = input.IsKeyDown(KEY)
    if down and not wasDown and NA_TouchesDirectes() then
        NA_Lancer("kami_shuriken")
    end
    wasDown = down
end)

-- Lancement (appelé par la touche ET par la barre de techniques)
NA_Cast = NA_Cast or {}
NA_Cast.kami_shuriken = function()
    net.Start("kami_shuriken_cast")
    net.SendToServer()
end
