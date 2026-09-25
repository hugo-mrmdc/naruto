--========================================================
-- Souffle katon (CLIENT)
--
-- Envoie l'appui au serveur (sv_katon_souffle.lua, qui décide de tout) et
-- affiche le jet de flammes devant le lanceur, dans la direction de son regard.
--
-- Animation : jouée comme celle des boules de feu (gesture, comme Jutsu.Play /
-- jutsu_anim_cl.lua) mais sans "autokill" : elle boucle sans coupure tout le souffle.
--========================================================

local FX  = "izox_katon_dragon_souffle"                      -- particles/1izoxsolvenr.pcf
local SEQ = "nrp_ninjutsu_attack_d53nj2_handseal_loop"        -- animation pendant le souffle

game.AddParticles("particles/1izoxsolvenr.pcf")
PrecacheParticleSystem(FX)

-- Lancement (barre de techniques : pas de touche directe).
-- La recharge est vérifiée par NA_Lancer avec la vraie valeur du serveur.
NA_Cast = NA_Cast or {}
NA_Cast.katon_souffle = function()
    net.Start("katon_souffle")
    net.SendToServer()
end

-- Un souffle par lanceur : particule + animation
local souffles = {}   -- joueur -> { fx, fin, seq }

-- la séquence joue-t-elle encore sur une des couches d'animation du joueur ?
local function EnCours(ply, seq)
    for i = 0, 13 do
        if ply:GetLayerSequence(i) == seq and ply:GetLayerWeight(i) > 0 then return true end
    end
    return false
end

local function Fin(ply)
    local s = souffles[ply]
    if not s then return end
    if IsValid(s.fx) then s.fx:StopEmission() end
    if IsValid(ply) then
        ply:AnimResetGestureSlot(GESTURE_SLOT_CUSTOM)
        ply.NA_SouffleActif = nil
    end
    souffles[ply] = nil
end

net.Receive("katon_souffle_fx", function()
    local ply   = net.ReadEntity()
    local duree = net.ReadFloat()
    if not IsValid(ply) then return end

    Fin(ply)
    if duree <= 0 then return end

    local seq = ply:LookupSequence(SEQ)
    if (not seq or seq < 0) and ply == LocalPlayer() then
        MsgC(Color(255, 80, 80), "[Souffle] animation introuvable sur ", ply:GetModel(), " : ", SEQ, "\n")
    end

    souffles[ply] = {
        fx = CreateParticleSystemNoEntity(FX, ply:EyePos(), ply:EyeAngles()),
        fin = CurTime() + duree,
        seq = (seq and seq >= 0) and seq or nil,
    }
    -- pendant le souffle, le corps reste dans l'axe de la caméra (la course de chakra ne le tourne plus,
    -- cl_sprint_chakra.lua) : le jet de flammes et le personnage regardent au même endroit
    ply.NA_SouffleActif = true
end)

hook.Add("Think", "katon_souffle_fx", function()
    for ply, s in pairs(souffles) do
        if not IsValid(ply) or not IsValid(s.fx) or not ply:Alive() or CurTime() > s.fin + 0.2 then
            Fin(ply)
        else
            local ang = ply:EyeAngles()
            s.fx:SetControlPoint(0, ply:EyePos() + ang:Forward() * 18 - ang:Up() * 6)
            s.fx:SetControlPointOrientation(0, ang:Forward(), ang:Right(), ang:Up())

            -- l'animation est lancée UNE fois, sans "autokill" : elle boucle toute seule sans coupure.
            -- Elle n'est relancée que si elle a disparu (on cherche sa séquence dans les couches) ET
            -- qu'une autre animation de jutsu (mudras d'une autre technique) n'est pas en cours :
            -- on la laisse finir, puis le souffle reprend sa pose.
            if s.seq and CurTime() >= (s.prochain or 0) and CurTime() >= (ply.NA_AnimFin or 0)
                and not EnCours(ply, s.seq) then
                s.prochain = CurTime() + 0.3
                ply:AddVCDSequenceToGestureSlot(GESTURE_SLOT_CUSTOM, s.seq, 0, false)
            end
        end
    end
end)
