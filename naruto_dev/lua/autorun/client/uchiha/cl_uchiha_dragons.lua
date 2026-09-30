--========================================================
-- Uchiha : Dragons de feu (CLIENT)
-- Zone de particules au sol (katon_explo_big) d'où sortent des dragons de feu.
--========================================================

local NET_FIRE = "naruto_dev_uchih3"
local NET_ZONE = "naruto_dev_uchih3_zone"

local PCF     = "particles/atg_reworkpvp.pcf"
local PCF_DRAGON = "particles/argano3.pcf"
local FX_DRAGON = "nr_Sharingan_flame_dragon"   -- particules de base du dragon (comme dans l'addon)
local FX_ZONE = "katon_explo_big"
local MODEL   = "models/clan/konoha/uchiha/nr_sharingan_flame_dragon.mdl"

local KEY = KEY_COMMA

-- le modèle est long selon son axe X (de -63 à +36) : on le dresse vers le haut.
-- Si les dragons sortent la queue en premier, mets TETE_INVERSEE à true.
local TETE_INVERSEE = false
local ECHELLE       = 1       -- taille des dragons
local HAUTEUR       = 550     -- de combien ils montent dans les airs
local FADE_DEBUT    = 0.8     -- le fondu ne commence qu'à cette part de la vie du dragon (0 à 1)
local DUREE_DRAGON  = 1.5     -- durée d'un dragon (jaillit du sol puis monte et disparaît)
local NB_DRAGONS    = 3       -- dragons par seconde et par 100 unités de rayon
local RAFRAICHIR_FX = 1.0     -- l'explosion au sol est rejouée toutes les X secondes

local function Charger()
    game.AddParticles(PCF)
    game.AddParticles(PCF_DRAGON)
    PrecacheParticleSystem(FX_ZONE)
    PrecacheParticleSystem(FX_DRAGON)
end
Charger()   -- aussi au rechargement du fichier (lua_openscript_cl)

hook.Add("InitPostEntity", "uchih3_precache", function()
    Charger()
    PrecacheParticleSystem(FX_ZONE)
    util.PrecacheModel(MODEL)
end)

-- touche
local last = false
hook.Add("Think", "uchih3_key", function()
    local lp = LocalPlayer()
    if vgui.GetKeyboardFocus() or gui.IsGameUIVisible() or not IsValid(lp) or lp:IsTyping() or not lp:Alive() then
        last = false
        return
    end
    local pressed = input.IsKeyDown(KEY)
    if pressed and not last and NA_TouchesDirectes() then
        NA_Lancer("katon_dragons")
    end
    last = pressed
end)

NA_Cast = NA_Cast or {}
NA_Cast.katon_dragons = function()
    Jutsu.Play("nrp_ninjutsu_defend_dragonflamebombs_start")
    net.Start("Jutsu_PlaySound")
    net.SendToServer()

    timer.Simple(0.5, function()
        Jutsu.Play("nrp_ninjutsu_defend_dragonflamebombs_end")
    end)

    net.Start(NET_FIRE)
    net.SendToServer()
end

--========================================================
-- Zones et dragons (optimisé : modèles réutilisés, nombre plafonné, rien si trop loin)
--========================================================
local MAX_DRAGONS = 14      -- dragons visibles en même temps (tous les joueurs confondus)
local DIST_MAX    = 3500    -- au-delà, pas de dragons ni de particules (économie)
local FX_GARDES   = 2       -- explosions de zone gardées en même temps (les plus anciennes se terminent seules)

local zones   = {}
local dragons = {}   -- dragons en vol
local libres  = {}   -- modèles disponibles (réutilisés au lieu d'être recréés)

local tmpPos = Vector()
local tmpCol = Color(255, 255, 255, 255)

net.Receive(NET_ZONE, function()
    local pos, duree, rayon = net.ReadVector(), net.ReadFloat(), net.ReadFloat()
    zones[#zones + 1] = { pos = pos, fin = CurTime() + duree, rayon = rayon, fx = 0, dragon = 0, effets = {} }
end)

local function PrendreModele()
    local mdl = table.remove(libres)
    if IsValid(mdl) then return mdl end

    mdl = ClientsideModel(MODEL)
    if not IsValid(mdl) then return end
    mdl:Spawn()
    mdl:SetModelScale(ECHELLE, 0)
    mdl:SetRenderMode(RENDERMODE_TRANSALPHA)
    mdl:DrawShadow(false)
    return mdl
end

local function RendreModele(mdl)
    if not IsValid(mdl) then return end
    mdl:StopParticles()
    mdl:SetNoDraw(true)
    libres[#libres + 1] = mdl
end

local function NouveauDragon(z)
    if #dragons >= MAX_DRAGONS then return end

    local r = math.sqrt(math.Rand(0.05, 1)) * z.rayon * 0.9
    local a = math.Rand(0, 360)
    local pos = z.pos + Vector(math.cos(math.rad(a)) * r, math.sin(math.rad(a)) * r, 0)

    local mdl = PrendreModele()
    if not mdl then return end
    mdl:SetNoDraw(false)
    mdl:SetAngles(Angle(TETE_INVERSEE and 90 or -90, a, 0))   -- pile à la verticale
    mdl:SetPos(pos)

    -- particules de base du dragon, collées sur lui
    local att = mdl:LookupAttachment("effect_1")
    if att and att > 0 then
        ParticleEffectAttach(FX_DRAGON, PATTACH_POINT_FOLLOW, mdl, att)
    else
        ParticleEffectAttach(FX_DRAGON, PATTACH_ABSORIGIN_FOLLOW, mdl, 0)
    end

    dragons[#dragons + 1] = { mdl = mdl, x = pos.x, y = pos.y, z = pos.z, debut = CurTime(), duree = DUREE_DRAGON }
end

hook.Add("Think", "uchih3_zones", function()
    if #zones == 0 and #dragons == 0 then return end
    local now = CurTime()
    local lp  = LocalPlayer()
    local oeil = IsValid(lp) and lp:GetPos() or nil
    local maxDist2 = DIST_MAX * DIST_MAX

    for i = #zones, 1, -1 do
        local z = zones[i]
        if now >= z.fin then
            -- fin de la technique : on coupe toutes les particules de la zone d'un coup
            for _, fx in ipairs(z.effets) do
                if IsValid(fx) then fx:StopEmissionAndDestroyImmediately() end
            end
            table.remove(zones, i)
        elseif oeil and oeil:DistToSqr(z.pos) <= maxDist2 then
            if now >= z.fx then
                z.fx = now + RAFRAICHIR_FX
                local fx = CreateParticleSystemNoEntity(FX_ZONE, z.pos, angle_zero)
                if fx then
                    local e = z.effets
                    e[#e + 1] = fx
                    -- les plus anciennes finissent naturellement (plus de cumul d'effets lourds)
                    if #e > FX_GARDES then
                        local vieux = table.remove(e, 1)
                        if IsValid(vieux) then vieux:StopEmission() end
                    end
                end
            end
            if now >= z.dragon then
                z.dragon = now + 1 / (NB_DRAGONS * z.rayon / 100)
                NouveauDragon(z)
            end
        end
    end

    for i = #dragons, 1, -1 do
        local d = dragons[i]
        local t = (now - d.debut) / d.duree
        if t >= 1 or not IsValid(d.mdl) then
            RendreModele(d.mdl)
            table.remove(dragons, i)
        else
            -- droit vers le haut à vitesse constante, fondu à la fin
            tmpPos:SetUnpacked(d.x, d.y, d.z - 80 + t * HAUTEUR)
            d.mdl:SetPos(tmpPos)
            tmpCol.a = t <= FADE_DEBUT and 255 or math.Clamp((1 - t) * 255 / (1 - FADE_DEBUT), 0, 255)
            d.mdl:SetColor(tmpCol)
        end
    end
end)
