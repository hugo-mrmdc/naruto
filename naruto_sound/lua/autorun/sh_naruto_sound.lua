-- Enregistre chaque son de sound/naruto_sound/<dossier>/<nom>.<ext> sous le nom "naruto.<dossier>.<nom>"
-- Usage : ply:EmitSound("naruto.doton.golem_cast") / sound.Play("naruto.katon.impact", pos)
local root = "sound/naruto_sound/"

local _, dirs = file.Find(root .. "*", "GAME")
for _, d in ipairs(dirs) do
    for _, f in ipairs(file.Find(root .. d .. "/*", "GAME")) do
        local name = string.StripExtension(f)
        sound.Add({
            name    = "naruto." .. d .. "." .. name,
            channel = CHAN_AUTO,
            volume  = 1,
            level   = 90,
            pitch   = { 95, 105 },
            sound   = "naruto_sound/" .. d .. "/" .. f,
        })
    end
end
