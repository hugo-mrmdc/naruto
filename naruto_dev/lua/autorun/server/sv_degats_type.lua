--========================================================
-- Type de dégâts : jutsu (bleu) vs physique (orange)
-- But : permettre à cl_degats_affiches.lua de colorer le chiffre selon
-- la source du coup, sans avoir à modifier chaque script de jutsu/arme.
--
-- NRP.Combat.Damage (gamemode narutorp) connaît déjà le "kind" du coup et
-- pose lui-même cible.NRPTypeDegats avant TakeDamageInfo (voir sv_damage.lua).
-- Pour tous les autres appels directs à TakeDamageInfo (entités de jutsu
-- dans lua/entities/, scripts autorun par élément, armes...), on devine le
-- type à partir du fichier qui a fait l'appel : un SWEP (lua/weapons/) est
-- toujours un coup physique, tout le reste (entités de jutsu, techniques
-- lancées depuis lua/autorun/server/...) est considéré comme un jutsu.
--========================================================

local ENTITY = FindMetaTable("Entity")
local TakeDamageInfoOriginal = ENTITY.TakeDamageInfo

function ENTITY:TakeDamageInfo(dmg)
    local devine = self.NRPTypeDegats == nil
    if devine then
        local info = debug.getinfo(2, "S")
        local chemin = info and info.short_src or ""
        self.NRPTypeDegats = chemin:find("lua/weapons/", 1, true) and "physique" or "jutsu"
    end

    local ok, err = pcall(TakeDamageInfoOriginal, self, dmg)

    if devine then
        self.NRPTypeDegats = nil
    end

    if not ok then error(err, 0) end
end
