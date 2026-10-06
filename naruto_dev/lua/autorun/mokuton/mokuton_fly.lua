hook.Add("PlayerSpawnedProp", "MokutonDragonAutoFly", function(ply, model, ent)
    if not IsValid(ent) then return end

    -- Chemin EXACT du modèle
    if string.lower(model) ~= "models/mokuton/mokutondragon1.mdl" then return end

    local pos = ent:GetPos()
    local ang = ent:GetAngles()
    ent:Remove()

    -- On recrée en prop_dynamic (supporte les anims)
    local dyn = ents.Create("prop_dynamic")
    if not IsValid(dyn) then return end

    dyn:SetModel("models/mokuton/mokutondragon1.mdl")
    dyn:SetPos(pos)
    dyn:SetAngles(ang)
    dyn:Spawn()

    -- Lance l’animation
    dyn:ResetSequence("fly")
    dyn:SetPlaybackRate(1)
    dyn:SetCycle(0)
end)


-- Vol du dragon de bois (SHARED) : exécuté par le serveur ET prédit par le client du cavalier.
-- Le serveur met le joueur en MOVETYPE_FLY (mokuton_dragon_sv.lua) ; ici on ne fait que donner la vitesse à chaque
-- commande. Le moteur gère les murs. Le dragon est dessiné par le client à partir de la position du cavalier.
local PITCH_MAX    = 60
local FLY_UP_SPEED = 700   -- même valeur que FLY_UP_SPEED de mokuton_dragon_sv.lua

hook.Add("SetupMove", "MokutonDragon_Vol", function(ply, mv, cmd)
    if not ply:GetNWBool("MokutonRide", false) then return end

    if ply:GetNWBool("MokutonFige", false) then
        mv:SetVelocity(vector_origin)
        return
    end

    local eye = mv:GetAngles()
    local dir = Angle(math.Clamp(eye.p, -PITCH_MAX, PITCH_MAX), eye.y, 0):Forward()
    local vel = dir * ply:GetNWFloat("MokutonVit", 1200)

    if mv:KeyDown(IN_JUMP) then vel.z = vel.z + FLY_UP_SPEED end
    if mv:KeyDown(IN_DUCK) then vel.z = vel.z - FLY_UP_SPEED end

    -- Au sol, la vitesse vers le bas se heurtait au sol et le moteur freinait tout (le dragon n'avançait plus) :
    -- on retire la composante vers le bas et on décolle le joueur du sol pour qu'il glisse dessus.
    if ply:OnGround() then
        if vel.z < 0 then vel.z = 0 end
        vel.z = vel.z + 60
        mv:SetOrigin(mv:GetOrigin() + Vector(0, 0, 1))
        ply:SetGroundEntity(NULL)
    end

    mv:SetVelocity(vel)
end)
