--========================================================
-- Doton : Golem de roche (SERVEUR) - rang S
--
-- Comme le Golem Mokuton : après des mudras, le joueur DEVIENT le golem (models/nature/doton/lv_golem_dot.mdl) pendant DUREE
-- secondes :
--   - animations lv_idle1 / walk (autorun/mokuton/mokuton_golem_sh.lua, type "doton") ;
--   - clic gauche : attaque lv_attack1, qui blesse et projette devant lui ;
--   - plus de jutsu ni de dash pendant la transformation (NW2Bool "NA_Golem", lu par _na_registre.lua / sh_dash.lua...) ;
--   - résistance : les dégâts reçus sont réduits de REDUCTION % ;
--   - à la fin (durée écoulée, E, ou relancer la technique) : animation lv_death1, puis le golem se détruit dans une particule.
-- Le serveur décide de tout : mudras, recharge, chakra, dégâts.
--
-- Réseau : "doton_golem_cast" et "doton_golem_atk" (client -> serveur)
--========================================================

if not SERVER then return end

util.AddNetworkString("doton_golem_cast")
util.AddNetworkString("doton_golem_atk")

--========================================================
-- RÉGLAGES -> valeurs par niveau : _na_niveaux_techniques.lua (taille, modèle, animations, boîte : mokuton_golem_sh.lua)
--========================================================
local DUREE        = 30     -- secondes sous forme de golem
local RECHARGE     = 45     -- secondes avant de pouvoir relancer (depuis la FIN de la transformation)
local CHAKRA_COUT  = 70
local CHAKRA_MAX   = NA_CHAKRA_MAX or 100
local REDUCTION    = 50     -- % de dégâts en moins tant que tu es golem
local DUREE_MUDRA  = 0.6

local FX_DEBUT     = "solve_doton_golem_start"   -- quand tu deviens golem (particles/solve_doton.pcf)
local FX_FIN       = "solve_doton_golem_end"     -- quand le golem se détruit, après son animation de mort
local DETRUIRE_AVANT = 0.4  -- secondes avant la fin de lv_death1 où le golem se détruit (particule)
local DELAI_FIN    = 0.4    -- secondes entre la particule de destruction et le retour à ton apparence
local ANIM_MUDRA   = "nrp_ninjutsu_defend_dragonflamebombs_start"

local DEGATS       = 90     -- dégâts de l'attaque
local PORTEE_ATK   = 200    -- distance devant lui du centre de la zone qui frappe
local RAYON_ATK    = 200    -- rayon de la zone qui frappe (developer 1 pour la voir)
local MOMENT_COUP  = 0.3    -- le coup part à cette fraction de l'animation (0 = début, 1 = fin)
local RECUL        = 600    -- projection dans le sens du coup
local SOULEVE      = 250    -- projection vers le haut
--========================================================

local ID = "doton_golem"
local function Niv(ply, stat, base) return NA_Stat(ply, ID, stat, base) end
-- le type "doton" (modèle, animations...) est défini dans mokuton/mokuton_golem_sh.lua, chargé après ce fichier (ordre alphabétique) : on le lit à l'usage
local function TYPE() return NA_GOLEM.TYPES.doton end

for _, ext in ipairs({ "mdl", "vvd", "dx80.vtx", "dx90.vtx" }) do
    resource.AddFile("models/nature/doton/lv_golem_dot." .. ext)
end
resource.AddFile("materials/models/loeve/lv_golem_dot/lv_golem_dot.vmt")
resource.AddFile("materials/models/loeve/lv_golem_dot/lv_golem_dot.vtf")
resource.AddFile("materials/models/loeve/normal.vtf")
resource.AddFile("materials/models/loeve/toon.vmt")
resource.AddFile("materials/models/loeve/toon.vtf")
resource.AddFile("particles/solve_doton.pcf")
game.AddParticles("particles/solve_doton.pcf")
PrecacheParticleSystem(FX_DEBUT)
PrecacheParticleSystem(FX_FIN)
util.PrecacheModel("models/nature/doton/lv_golem_dot.mdl")

local etat    = {}   -- joueur -> état tant qu'il est golem
local pret    = {}
local enMudra = {}

local function EstCible(ent, lanceur)
    if not IsValid(ent) or ent == lanceur then return false end
    if ent:IsPlayer() then return ent:Alive() end
    if ent:IsNPC() then return ent:GetNPCState() ~= NPC_STATE_DEAD end
    if ent:IsNextBot() then return ent:Health() > 0 end
    return false
end

local Arreter

-- Retour à l'apparence normale
Arreter = function(ply, avecRecharge)
    local st = etat[ply]
    etat[ply] = nil
    enMudra[ply] = nil
    if not IsValid(ply) then return end

    ply:SetNW2Bool("NA_Golem", false)
    ply:SetNW2Int("NA_GolemAtk", 0)
    ply:SetNW2Float("NA_GolemAtkFin", 0)
    ply:SetNW2Float("NA_GolemMortFin", 0)
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
        if NA_CD then NA_CD.Set(ply, ID, recharge) end   -- recharge visible dans la barre
    end
end

-- Fin en douceur (durée écoulée ou relance) : animation de mort, puis la particule de destruction, puis l'apparence normale.
-- Mort / réapparition du joueur : Arreter direct.
local function Detruire(ply)
    local st = etat[ply]
    if not st or st.finEnCours then return end
    st.finEnCours = true
    st.veutAtk = false
    st.frappeA = nil
    ply:SetNW2Int("NA_GolemAtk", 0)
    ply:SetNW2Float("NA_GolemAtkFin", 0)

    -- animation de mort (lv_death1) : durée réelle de la séquence, jouée une fois (lue par mokuton_golem_sh.lua)
    local id = TYPE().mort and ply:LookupSequence(TYPE().mort)
    local duree = (id and id >= 0) and ply:SequenceDuration(id) or 3
    local now = CurTime()
    ply:SetNW2Float("NA_GolemMortDebut", now)
    ply:SetNW2Float("NA_GolemMortFin", now + duree)
    ply:EmitSound("naruto_sound/jutsu/doton/earth11.wav", 90, 60)

    -- le golem se détruit DETRUIRE_AVANT secondes avant la fin de l'animation de mort
    timer.Simple(math.max(duree - DETRUIRE_AVANT, 0), function()
        if not IsValid(ply) or etat[ply] ~= st then return end
        ParticleEffect(FX_FIN, ply:GetPos(), angle_zero)
        ply:EmitSound("naruto_sound/jutsu/doton/earth12.wav", 95, 55)
        timer.Simple(DELAI_FIN, function()
            if IsValid(ply) and etat[ply] == st then Arreter(ply, true) end
        end)
    end)
end

-- Transformation (après les mudras)
local function Transformer(ply)
    enMudra[ply] = nil
    if not IsValid(ply) or not ply:Alive() then return end

    etat[ply] = {
        modele  = ply:GetModel(),
        couleur = ply:GetColor(),
        fin     = CurTime() + Niv(ply, "duree", DUREE),
        libre   = 0,   -- moment où la prochaine attaque est possible
    }

    ply:SetModel(TYPE().modele)
    ply:SetModelScale(Niv(ply, "echelle", TYPE().echelle), 0)
    ply:SetColor(color_white)                                       -- pas la teinte de peau du personnage
    if NA_AppliquerApparence then NA_AppliquerApparence(ply) end    -- retire la tête et les cheveux (pas de squelette humain)
    ply:SetNW2String("NA_GolemType", "doton")                       -- modèle / animations / boîte du golem (mokuton_golem_sh.lua)
    ply:SetNW2Float("NA_GolemMortFin", 0)
    ply:SetNW2Bool("NA_Golem", true)
    ParticleEffect(FX_DEBUT, ply:GetPos(), angle_zero)              -- la particule cache le changement de modèle

    local arme = ply:GetActiveWeapon()
    if IsValid(arme) then arme:SetNoDraw(true) end
    ply:EmitSound("naruto_sound/jutsu/doton/earth11.wav", 90, 60)
end

net.Receive("doton_golem_cast", function(_, ply)
    if not IsValid(ply) or not ply:Alive() then return end

    -- déjà golem : relancer le détruit (animation de mort puis retour à la normale)
    if etat[ply] then
        Detruire(ply)
        return
    end

    if not NA_Debloquee(ply, ID) then return end   -- technique pas encore débloquée (F6)
    if enMudra[ply] or ply:GetNW2Bool("NA_Golem", false) or ply:GetNW2Bool("NA_Hobi", false) or ply:GetNW2Bool("NA_Souterrain", false) then return end
    if (pret[ply] or 0) > CurTime() then return end

    local cout = Niv(ply, "chakra", CHAKRA_COUT)
    local chakra = ply:GetNW2Float("NA_Chakra", CHAKRA_MAX)
    if cout > 0 then
        if chakra < cout then
            -- (pas de message)
            return
        end
        ply:SetNW2Float("NA_Chakra", chakra - cout)
    end

    if NA_StopChakraRun then NA_StopChakraRun(ply) end   -- lancer une technique coupe la course de chakra

    enMudra[ply] = true
    local mudra = Niv(ply, "duree_mudra", DUREE_MUDRA)
    NA_AnimJutsu(ply, ANIM_MUDRA)
    ply:EmitSound("base/mudra_sound_geams.wav", 75, 100)
    if NA_Mudra then NA_Mudra(ply, mudra) end
    timer.Simple(mudra, function() Transformer(ply) end)
end)

-- Clic gauche (envoyé par le client : mokuton_golem_sh.lua, message du type "doton") : une attaque
net.Receive("doton_golem_atk", function(_, ply)
    local st = etat[ply]
    if st then st.veutAtk = true end
end)

local function Attaquer(ply, st)
    local now = CurTime()
    if now < st.libre then return end   -- l'attaque précédente n'est pas finie

    local id = ply:LookupSequence(TYPE().atk[1])
    -- durée RÉELLE : celle de l'animation divisée par sa vitesse
    local duree = ((id and id >= 0) and ply:SequenceDuration(id) or 1.5) / TYPE().vitesse_anim
    st.libre   = now + duree
    st.frappeA = now + duree * MOMENT_COUP

    ply:SetNW2Int("NA_GolemAtk", 1)
    ply:SetNW2Float("NA_GolemAtkDebut", now)
    ply:SetNW2Float("NA_GolemAtkFin", now + duree)
    ply:EmitSound("naruto_sound/jutsu/doton/earth10.wav", 80, 70)
end

-- Le coup part : dégâts + projection devant le golem
local function Frapper(ply)
    local dir = Angle(0, ply:EyeAngles().y, 0):Forward()
    local centre = ply:GetPos() + dir * PORTEE_ATK + Vector(0, 0, 60)
    local degats = Niv(ply, "degats", DEGATS)
    local rayon = Niv(ply, "rayon", RAYON_ATK)

    for _, ent in ipairs(ents.FindInSphere(centre, rayon)) do
        if not EstCible(ent, ply) then continue end

        local dmg = DamageInfo()
        dmg:SetDamage(degats)
        dmg:SetAttacker(ply)
        dmg:SetInflictor(ply)
        dmg:SetDamageType(DMG_CLUB)
        dmg:SetDamagePosition(ent:WorldSpaceCenter())
        ent:TakeDamageInfo(dmg)

        local vel = dir * RECUL + Vector(0, 0, SOULEVE)
        -- aucune projection de la cible (pas de transfert de force)
    end

    ply:EmitSound("naruto_sound/jutsu/doton/earth12.wav", 85, 80)

    -- particule d'impact AU SOL, là où le coup tombe (même message que le Golem Mokuton : mokuton_dragon_impact_fx)
    local sol = util.TraceLine({ start = centre + Vector(0, 0, 40), endpos = centre - Vector(0, 0, 400), mask = MASK_SOLID_BRUSHONLY })
    net.Start("mokuton_dragon_impact_fx")
        net.WriteVector(sol.Hit and sol.HitPos or centre)
    net.Broadcast()
    if GetConVar("developer"):GetInt() > 0 then debugoverlay.Sphere(centre, rayon, 1, Color(190, 140, 80, 30), true) end
end

hook.Add("Think", "DotonGolem_Boucle", function()
    if next(etat) == nil then return end
    local now = CurTime()

    for ply, st in pairs(etat) do
        if not IsValid(ply) or not ply:Alive() then
            Arreter(ply, false)
            continue
        end
        if st.finEnCours then continue end   -- destruction en cours : plus d'attaque
        if now >= st.fin then
            Detruire(ply)
            continue
        end

        if st.veutAtk then
            st.veutAtk = false
            Attaquer(ply, st)
        end
        if st.frappeA and now >= st.frappeA then
            st.frappeA = nil
            Frapper(ply)
        end
    end
end)

-- résistance : sous forme de golem, tous les dégâts reçus sont réduits de REDUCTION %
hook.Add("EntityTakeDamage", "DotonGolem_Resistance", function(cible, dmg)
    if not cible:IsPlayer() or not etat[cible] then return end
    dmg:ScaleDamage(1 - math.Clamp(Niv(cible, "reduction", REDUCTION), 0, 100) / 100)
end)

-- pas de changement d'arme pendant la transformation (l'arme est cachée)
hook.Add("PlayerSwitchWeapon", "DotonGolem_PasDArme", function(ply)
    if etat[ply] then return true end
end)

-- E : tue le golem (animation de mort, puis il se détruit 0,1 s avant la fin de cette animation)
hook.Add("KeyPress", "DotonGolem_ToucheE", function(ply, key)
    if key == IN_USE and etat[ply] then Detruire(ply) end
end)

hook.Add("PlayerDeath", "DotonGolem_Mort", function(ply) Arreter(ply, false) end)
hook.Add("PlayerSpawn", "DotonGolem_Spawn", function(ply)
    if etat[ply] then Arreter(ply, false) end
end)
hook.Add("PlayerDisconnected", "DotonGolem_Nettoyage", function(ply)
    etat[ply] = nil
    enMudra[ply] = nil
    pret[ply] = nil
end)
