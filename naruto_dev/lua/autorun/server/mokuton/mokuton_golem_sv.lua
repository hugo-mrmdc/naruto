--========================================================
-- Mokuton : Golem de bois (SERVEUR)
--
-- Après des mudras, le joueur DEVIENT le golem (models/mokuton/nr_mokuton_golem.mdl) pendant DUREE secondes :
--   - animations nr_golem_idle / nr_golem_walk (autorun/mokuton/mokuton_golem_sh.lua) ;
--   - clic gauche : combo d'attaques nr_golem_atk1 -> atk2 -> atk3, qui blessent et projettent devant lui ;
--   - plus de jutsu ni de dash pendant la transformation (refusés par _na_registre.lua / sh_dash.lua) ;
--   - résistance : les dégâts reçus sont réduits de REDUCTION % (50 par défaut) ;
--   - relancer la technique redonne tout de suite son apparence.
-- Le serveur décide de tout : mudras, recharge, chakra, dégâts.
--========================================================

if not SERVER then return end

util.AddNetworkString("mokuton_golem_cast")
util.AddNetworkString("mokuton_golem_atk")

--========================================================
-- RÉGLAGES -> c'est ICI qu'on change les valeurs
--========================================================
local DUREE        = 30     -- secondes sous forme de golem
local RECHARGE     = 40     -- secondes avant de pouvoir relancer (depuis la FIN de la transformation)
local CHAKRA_COUT  = 60     -- chakra dépensé au lancement (0 = gratuit)
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100   -- réglé dans autorun/_na_chakra.lua
local REDUCTION    = 50     -- % de dégâts en moins tant que tu es golem (résistance ; 50 = tu prends la moitié)
local DUREE_MUDRA  = 0.6    -- mudras avant la transformation

-- Transitions (particles/solve_doton.pcf)
local FX_DEBUT     = "solve_doton_golem_start"   -- quand tu deviens golem
local FX_FIN       = "solve_doton_golem_end"     -- quand le golem se détruit
local DELAI_FIN    = 0.4    -- secondes entre le début de la destruction et le retour à ton apparence (la particule la cache)
local ANIM_MUDRA   = "nrp_ninjutsu_defend_dragonflamebombs_start"

-- Attaques du golem (clic gauche)
local DEGATS       = 40     -- dégâts de l'attaque 1 ; l'attaque 2 fait x1,3 et l'attaque 3 x2
local MULT_ATK     = { 1, 1.3, 2 }
local PORTEE_ATK   = 220    -- distance devant lui du centre de la zone qui frappe
local RAYON_ATK    = 200    -- rayon de la zone qui frappe (developer 1 pour la voir)
local MOMENT_COUP  = 0.5    -- le coup part à cette fraction de l'animation (0 = début, 1 = fin)
local ENCHAINE     = 1.5    -- secondes max après la fin d'une attaque pour enchaîner la suivante du combo
local RECUL        = 600    -- projection dans le sens du coup
local SOULEVE      = 250    -- projection vers le haut
--========================================================

-- réglages par niveau (_na_niveaux_techniques.lua) : Niv(joueur, "stat", VALEUR)
local function Niv(ply, stat, base) return NA_Stat(ply, "mokuton_golem", stat, base) end

NA_GOLEM = NA_GOLEM or {}
NA_GOLEM.etat = NA_GOLEM.etat or {}   -- joueur -> état (lu aussi par autorun/mokuton/mokuton_golem_sh.lua)
local etat = NA_GOLEM.etat

local pret     = {}   -- joueur -> moment où la technique est de nouveau disponible
local enMudra  = {}   -- joueur -> true pendant les mudras

resource.AddFile("particles/solve_doton.pcf")
game.AddParticles("particles/solve_doton.pcf")
PrecacheParticleSystem(FX_DEBUT)
PrecacheParticleSystem(FX_FIN)

local function EstCible(ent, lanceur)
    if not IsValid(ent) or ent == lanceur then return false end
    if ent:IsPlayer() then return ent:Alive() end
    if ent:IsNPC() then return ent:GetNPCState() ~= NPC_STATE_DEAD end
    if ent:IsNextBot() then return ent:Health() > 0 end
    return false
end

-- Retour à l'apparence normale
local Arreter

-- Fin en douceur (durée écoulée ou relance) : le golem se détruit dans une particule, ne peut plus attaquer, puis on
-- reprend l'apparence normale DELAI_FIN secondes plus tard, cachée par la particule. Mort / réapparition : Arreter direct.
local function Detruire(ply, avecRecharge)
    local st = etat[ply]
    if not st or st.finEnCours then return end
    st.finEnCours = true
    st.veutAtk = false
    st.frappeA = nil

    ParticleEffect(FX_FIN, ply:GetPos(), angle_zero)
    ply:EmitSound("physics/wood/wood_furniture_break" .. math.random(1, 2) .. ".wav", 95, 55)
    timer.Simple(DELAI_FIN, function()
        if IsValid(ply) and etat[ply] == st then Arreter(ply, avecRecharge) end
    end)
end

Arreter = function(ply, avecRecharge)
    local st = etat[ply]
    etat[ply] = nil
    enMudra[ply] = nil
    if not IsValid(ply) then return end

    ply:SetNW2Bool("NA_Golem", false)
    ply:SetNW2Int("NA_GolemAtk", 0)
    ply:SetNW2Float("NA_GolemAtkFin", 0)
    if not st then return end

    ply:SetModelScale(1, 0)
    if st.modele then ply:SetModel(st.modele) end
    if st.couleur then ply:SetColor(st.couleur) end
    if NA_AppliquerApparence then NA_AppliquerApparence(ply) end   -- tête et cheveux de nouveau posés (sv_playerskin.lua)

    local arme = ply:GetActiveWeapon()
    if IsValid(arme) then arme:SetNoDraw(false) end

    if avecRecharge then
        local recharge = Niv(ply, "recharge", RECHARGE)
        pret[ply] = CurTime() + recharge
        if NA_CD then NA_CD.Set(ply, "mokuton_golem", recharge) end   -- recharge visible dans la barre
    end
end

-- Transformation (après les mudras)
local function Transformer(ply)
    enMudra[ply] = nil
    if not IsValid(ply) or not ply:Alive() then return end

    etat[ply] = {
        modele  = ply:GetModel(),
        couleur = ply:GetColor(),
        fin     = CurTime() + Niv(ply, "duree", DUREE),
        libre   = 0,      -- moment où la prochaine attaque est possible
        dernier = 0,      -- fin de la dernière attaque (pour le combo)
        combo   = 0,      -- attaque en cours du combo (1 à 3)
    }

    ply:SetModel(NA_GOLEM.MODELE)
    ply:SetModelScale(NA_GOLEM.ECHELLE, 0)
    ply:SetColor(color_white)                           -- pas la teinte de peau du personnage
    if NA_AppliquerApparence then NA_AppliquerApparence(ply) end   -- retire la tête et les cheveux (pas de squelette humain)
    ply:SetNW2String("NA_GolemType", "mokuton")   -- modèle / animations / hull du golem (mokuton_golem_sh.lua)
    ply:SetNW2Bool("NA_Golem", true)
    ParticleEffect(FX_DEBUT, ply:GetPos(), angle_zero)   -- la particule cache le changement de modèle

    local arme = ply:GetActiveWeapon()
    if IsValid(arme) then arme:SetNoDraw(true) end
    ply:EmitSound("physics/wood/wood_furniture_break1.wav", 90, 60)
end

net.Receive("mokuton_golem_cast", function(_, ply)
    if not IsValid(ply) or not ply:Alive() then return end

    -- déjà golem : relancer redonne tout de suite l'apparence normale
    if etat[ply] then
        Detruire(ply, true)
        return
    end

    if not NA_Debloquee(ply, "mokuton_golem") then return end   -- technique pas encore débloquée (F6)
    if enMudra[ply] or ply:GetNW2Bool("NA_Hobi", false) or ply:GetNW2Bool("NA_Souterrain", false) then return end
    if (pret[ply] or 0) > CurTime() then return end

    local cout = Niv(ply, "chakra", CHAKRA_COUT)
    local chakra = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
    if cout > 0 then
        if chakra < cout then
            ply:PrintMessage(HUD_PRINTCENTER, "Pas assez de chakra")
            return
        end
        ply:SetNW2Float("NA_Chakra", chakra - cout)
    end

    if NA_StopChakraRun then NA_StopChakraRun(ply) end   -- lancer une technique coupe la course de chakra

    enMudra[ply] = true
    local mudra = Niv(ply, "duree_mudra", DUREE_MUDRA)
    NA_AnimJutsu(ply, ANIM_MUDRA)   -- animation + pas de coups pendant (_na_mudra.lua)
    ply:EmitSound("base/mudra_sound_geams.wav", 75, 100)
    if NA_Mudra then NA_Mudra(ply, mudra) end   -- pas de coups pendant les mudras (_na_mudra.lua)
    timer.Simple(mudra, function() Transformer(ply) end)
end)

-- Clic gauche (envoyé par le client : autorun/mokuton/mokuton_golem_sh.lua) : une attaque du combo
net.Receive("mokuton_golem_atk", function(_, ply)
    local st = etat[ply]
    if st then st.veutAtk = true end
end)

-- Attaque du golem : combo 1 -> 2 -> 3, une par clic gauche
local function Attaquer(ply, st)
    local now = CurTime()
    if now < st.libre then return end   -- l'attaque précédente n'est pas finie

    -- le combo continue si on enchaîne assez vite, sinon on repart de la première attaque
    st.combo = (now - st.dernier <= ENCHAINE and st.combo < 3) and st.combo + 1 or 1

    local id = ply:LookupSequence("nr_golem_atk" .. st.combo)
    -- durée RÉELLE de l'attaque : celle de l'animation divisée par sa vitesse (NA_GOLEM.VITESSE_ANIM, dans mokuton_golem_sh.lua)
    local duree = ((id and id >= 0) and ply:SequenceDuration(id) or 1) / NA_GOLEM.VITESSE_ANIM
    st.libre   = now + duree
    st.dernier = now + duree
    st.frappeA = now + duree * MOMENT_COUP
    st.attaque = st.combo

    ply:SetNW2Int("NA_GolemAtk", st.combo)
    ply:SetNW2Float("NA_GolemAtkDebut", now)
    ply:SetNW2Float("NA_GolemAtkFin", now + duree)
    ply:EmitSound("physics/wood/wood_plank_impact_hard" .. math.random(1, 3) .. ".wav", 80, 70)
end

-- Le coup part : dégâts + projection devant le golem
local function Frapper(ply, st)
    local dir = Angle(0, ply:EyeAngles().y, 0):Forward()
    local centre = ply:GetPos() + dir * PORTEE_ATK + Vector(0, 0, 60)
    local degats = Niv(ply, "degats", DEGATS) * (MULT_ATK[st.attaque] or 1)

    for _, ent in ipairs(ents.FindInSphere(centre, Niv(ply, "rayon", RAYON_ATK))) do
        if not EstCible(ent, ply) then continue end

        local dmg = DamageInfo()
        dmg:SetDamage(degats)
        dmg:SetAttacker(ply)
        dmg:SetInflictor(ply)
        dmg:SetDamageType(DMG_CLUB)
        dmg:SetDamagePosition(ent:WorldSpaceCenter())
        ent:TakeDamageInfo(dmg)

        local vel = dir * RECUL + Vector(0, 0, SOULEVE)
        if ent.loco then
            ent.loco:SetVelocity(ent.loco:GetVelocity() + vel)   -- NextBot
        else
            ent:SetVelocity(vel)
        end
    end

    ply:EmitSound("physics/wood/wood_furniture_break" .. math.random(1, 2) .. ".wav", 85, 80)

    -- particule d'impact AU SOL, là où le coup tombe : la même que le dragon (solve_doton_golem_impact, coupée au bout
    -- d'1 s par les clients : message "mokuton_dragon_impact_fx", client/mokuton/mokuton_dragon_cl.lua)
    local sol = util.TraceLine({ start = centre + Vector(0, 0, 40), endpos = centre - Vector(0, 0, 400), mask = MASK_SOLID_BRUSHONLY })
    net.Start("mokuton_dragon_impact_fx")
        net.WriteVector(sol.Hit and sol.HitPos or centre)
    net.Broadcast()
    if GetConVar("developer"):GetInt() > 0 then debugoverlay.Sphere(centre, Niv(ply, "rayon", RAYON_ATK), 1, Color(60, 255, 60, 30), true) end
end

hook.Add("Think", "MokutonGolem_Boucle", function()
    if next(etat) == nil then return end
    local now = CurTime()

    for ply, st in pairs(etat) do
        if not IsValid(ply) or not ply:Alive() then
            Arreter(ply, false)
            continue
        end
        if st.finEnCours then continue end   -- destruction en cours : plus d'attaque
        if now >= st.fin then
            Detruire(ply, true)
            continue
        end

        if st.veutAtk then
            st.veutAtk = false
            Attaquer(ply, st)
        end
        if st.frappeA and now >= st.frappeA then
            st.frappeA = nil
            Frapper(ply, st)
        end
    end
end)

-- résistance : sous forme de golem, tous les dégâts reçus sont réduits de REDUCTION %
hook.Add("EntityTakeDamage", "MokutonGolem_Resistance", function(cible, dmg)
    if not cible:IsPlayer() or not etat[cible] then return end
    dmg:ScaleDamage(1 - math.Clamp(Niv(cible, "reduction", REDUCTION), 0, 100) / 100)
end)

-- pas de changement d'arme pendant la transformation (l'arme est cachée)
hook.Add("PlayerSwitchWeapon", "MokutonGolem_PasDArme", function(ply)
    if etat[ply] then return true end
end)

-- mort, réapparition, départ : retour à la normale (la réapparition remet aussi son modèle : sv_playerskin.lua)
hook.Add("PlayerDeath", "MokutonGolem_Mort", function(ply) Arreter(ply, false) end)
hook.Add("PlayerSpawn", "MokutonGolem_Spawn", function(ply)
    if etat[ply] or ply:GetNW2Bool("NA_Golem", false) then Arreter(ply, false) end
end)
hook.Add("PlayerDisconnected", "MokutonGolem_Nettoyage", function(ply)
    etat[ply] = nil
    enMudra[ply] = nil
    pret[ply] = nil
end)
