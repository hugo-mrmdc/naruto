--========================================================
-- Bakuton : Oiseaux explosifs (SERVEUR)
-- La technique active un mode : un petit oiseau flotte derrière toi à gauche. Chaque CLIC GAUCHE l'envoie
-- (anim Fly) ; au contact il explose (mêmes particules que Shibuki) et le suivant apparaît. Quand les
-- "nombre" oiseaux sont lancés, le mode s'arrête et le cooldown démarre.
--
-- Réseau : "bakuton_oiseaux_cast" (client -> serveur)
--========================================================

util.AddNetworkString("bakuton_oiseaux_cast")

--========================================================
-- RÉGLAGES (valeurs par niveau : _na_niveaux_techniques.lua)
--========================================================
local NOMBRE      = 3      -- oiseaux à lancer (un seul visible à la fois)
local INTERVALLE  = 0.6    -- secondes minimum entre deux tirs
local RETOUR      = 0.5    -- secondes avant que le suivant apparaisse
local RECHARGE    = 15     -- cooldown, démarre quand tous les oiseaux sont lancés
local CHAKRA_COUT = 30
local CHAKRA_MAX  = NA_CHAKRA_MAX or 100
--========================================================

local ID = "bakuton_oiseaux"
local function Niv(ply, stat, base) return NA_Stat(ply, ID, stat, base) end

for _, ext in ipairs({ "mdl", "vvd", "phy", "dx80.vtx", "dx90.vtx" }) do
    resource.AddFile("models/bakuton/bid_deidara_solve." .. ext)
end
for _, f in ipairs({ "bid_deidara.vmt", "bid_deidara.vtf", "lightwarpshader.vtf" }) do
    resource.AddFile("materials/models/bid_deidara/" .. f)
end

local etat = {}   -- [ply] = { oiseau = ent, restants = n, prochain = CurTime, toucheClic = bool }
local pret = {}   -- [ply] = CurTime à partir duquel on peut relancer la technique

local function Apparaitre(ply)
    local st = etat[ply]
    if not st or IsValid(st.oiseau) or not IsValid(ply) or not ply:Alive() then return end
    local ent = ents.Create("bakuton_oiseau")
    if not IsValid(ent) then return end
    ent:SetPos(ply:GetPos() + Vector(0, 0, 60))
    ent:SetOwner(ply)
    ent.Degats  = Niv(ply, "degats", 40)
    ent.Rayon   = Niv(ply, "rayon", 130)
    ent.Vitesse = Niv(ply, "vitesse", 1000)
    ent:Spawn()
    st.oiseau = ent
end

-- fin du mode (plus d'oiseaux, ou technique relancée) ; mort / déconnexion : pas de recharge
local function Arreter(ply, recharge)
    local st = etat[ply]
    if not st then return end
    if IsValid(st.oiseau) then st.oiseau:Remove() end   -- un oiseau déjà tiré n'est plus dans l'état
    etat[ply] = nil
    if not IsValid(ply) then return end
    ply:SetNW2Bool("NA_Oiseaux", false)
    if recharge then
        local r = Niv(ply, "recharge", RECHARGE)
        pret[ply] = CurTime() + r
        if NA_CD then NA_CD.Set(ply, ID, r) end
    end
end

local function Tirer(ply)
    local st = etat[ply]
    if not st or not ply:Alive() or CurTime() < st.prochain or not IsValid(st.oiseau) then return end

    st.prochain = CurTime() + Niv(ply, "intervalle", INTERVALLE)
    local ent = st.oiseau
    local oeil = ply:EyePos()
    local vise = util.TraceLine({ start = oeil, endpos = oeil + ply:GetAimVector() * 3000, filter = ply }).HitPos
    ent:Tirer((vise - ent:GetPos()):GetNormalized())
    st.oiseau = nil
    st.restants = st.restants - 1

    if st.restants <= 0 then
        Arreter(ply, true)   -- tous lancés : le cooldown démarre
    else
        timer.Simple(Niv(ply, "retour", RETOUR), function() Apparaitre(ply) end)
    end
end

net.Receive("bakuton_oiseaux_cast", function(_, ply)
    if not IsValid(ply) or not ply:Alive() then return end
    if not NA_Debloquee(ply, ID) then return end
    if etat[ply] then Arreter(ply, true) return end
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

    etat[ply] = { restants = Niv(ply, "nombre", NOMBRE), prochain = 0, toucheClic = ply:KeyDown(IN_ATTACK) }
    ply:SetNW2Bool("NA_Oiseaux", true)
    Apparaitre(ply)
end)

-- Lu à chaque commande : un clic court est vu aussi. Un tir par appui (détection du front).
hook.Add("StartCommand", "BakutonOiseaux_Clic", function(ply, cmd)
    local st = etat[ply]
    if not st then return end
    local clic = cmd:KeyDown(IN_ATTACK)
    if clic and not st.toucheClic then Tirer(ply) end
    st.toucheClic = clic
end)

hook.Add("PlayerDeath", "BakutonOiseaux_Mort", function(ply) Arreter(ply) end)
hook.Add("PlayerDisconnected", "BakutonOiseaux_Nettoyage", function(ply) Arreter(ply) pret[ply] = nil end)
