--========================================================
-- Roue de papier (CLIENT)
-- Lancement depuis la barre de techniques. Les roues et leurs particules sont
-- gérées par l'entité kami_paper_wheel (lua/entities).
--========================================================

game.AddParticles("particles/solve_kami_geams.pcf")
PrecacheParticleSystem("kami_03_solve_geams_bone")
PrecacheParticleSystem("kami_03_solve_geams_trace_v2")
PrecacheParticleSystem("kami_03_solve_geams_add_trail")

-- Lancement (appelé par la barre de techniques)
NA_Cast = NA_Cast or {}
NA_Cast.kami_roue = function()
    -- animation de mudras si le système d'animation est chargé
    if Jutsu and Jutsu.Play then
        Jutsu.Play("nrp_ninjutsu_defend_dragonflamebombs_start")
    end

    net.Start("kami_roue_cast")
    net.SendToServer()
end

----------------------------------------------------------
-- Particules dans les mains pendant l'animation
-- (kami_02_solve_geams_weapon : un système par main, dont le point de contrôle
-- 0 est recalé sur l'os de la main à chaque image)
----------------------------------------------------------
PrecacheParticleSystem("kami_02_solve_geams_weapon")

local FX_MAINS = "kami_02_solve_geams_weapon"
local mains = {}   -- joueur -> { fx = { droite, gauche }, os = { droite, gauche }, fin = heure }

-- Cherche l'os d'une main (modèles ValveBiped, Bip01 ou autres noms courants)
local function TrouverOs(ply, droite)
    local noms = droite
        and { "ValveBiped.Bip01_R_Hand", "Bip01 R Hand", "Bip01_R_Hand", "R Hand", "RightHand" }
        or  { "ValveBiped.Bip01_L_Hand", "Bip01 L Hand", "Bip01_L_Hand", "L Hand", "LeftHand" }
    for _, n in ipairs(noms) do
        local id = ply:LookupBone(n)
        if id then return id end
    end
    for i = 0, ply:GetBoneCount() - 1 do
        local n = (ply:GetBoneName(i) or ""):lower()
        if n:find("hand", 1, true) and not n:find("finger", 1, true) then
            local est_droite = n:find("r_hand", 1, true) or n:find("hand_r", 1, true) or n:find("right", 1, true) or n:find(" r ", 1, true)
            if (droite and est_droite) or (not droite and not est_droite) then return i end
        end
    end
end

local function ArreterMains(ply)
    local m = mains[ply]
    if not m then return end
    for _, fx in ipairs(m.fx) do
        if IsValid(fx) then fx:StopEmission() end
    end
    mains[ply] = nil
end

net.Receive("kami_roue_mains", function()
    local ply = net.ReadEntity()
    local duree = net.ReadFloat()
    if not IsValid(ply) then return end

    ArreterMains(ply)

    local pos = ply:GetPos()
    mains[ply] = {
        fx  = {
            CreateParticleSystemNoEntity(FX_MAINS, pos),
            CreateParticleSystemNoEntity(FX_MAINS, pos),
        },
        os  = { TrouverOs(ply, true), TrouverOs(ply, false) },
        fin = CurTime() + duree,
    }
end)

hook.Add("Think", "KamiRoue_Mains", function()
    for ply, m in pairs(mains) do
        if not IsValid(ply) or not ply:Alive() or CurTime() > m.fin then
            ArreterMains(ply)
        else
            ply:SetupBones()
            for i = 1, 2 do
                local fx, os = m.fx[i], m.os[i]
                if IsValid(fx) then
                    local mat = os and ply:GetBoneMatrix(os)
                    fx:SetControlPoint(0, mat and mat:GetTranslation() or ply:GetPos() + Vector(0, 0, 40))
                end
            end
        end
    end
end)

----------------------------------------------------------
-- Impact (kami_02_solve_geams_impact_hit) : jouée à chaque touche et contre un mur
----------------------------------------------------------
for _, nom in ipairs({ "", "_add", "_add_1", "_add_3", "_add_4", "_add_6", "_add_blood", "_add_blood_02" }) do
    PrecacheParticleSystem("kami_02_solve_geams_impact_hit" .. nom)
end

net.Receive("kami_roue_impact", function()
    ParticleEffect("kami_02_solve_geams_impact_hit", net.ReadVector(), Angle(0, 0, 0))
end)
