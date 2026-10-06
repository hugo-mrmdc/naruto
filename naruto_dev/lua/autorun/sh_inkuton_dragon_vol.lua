-- Vol du dragon d'encre (SHARED) : exécuté par le serveur ET prédit par le client du cavalier.
-- Le serveur met le joueur en MOVETYPE_FLY (sv_inkuton_dragon.lua) ; ici on ne fait que donner la vitesse à chaque
-- commande. Le moteur gère les murs. Le dragon est dessiné par le client à partir de la position du cavalier.
local PITCH_MAX    = 60
local FLY_UP_SPEED = 700   -- même valeur que FLY_UP_SPEED de sv_inkuton_dragon.lua

hook.Add("SetupMove", "InkutonDragon_Vol", function(ply, mv, cmd)
    if not ply:GetNWBool("InkutonRide", false) then return end

    if ply:GetNWBool("InkutonFige", false) then
        mv:SetVelocity(vector_origin)
        return
    end

    local eye = mv:GetAngles()
    local dir = Angle(math.Clamp(eye.p, -PITCH_MAX, PITCH_MAX), eye.y, 0):Forward()
    local vel = dir * ply:GetNWFloat("InkutonVit", 1200)

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
