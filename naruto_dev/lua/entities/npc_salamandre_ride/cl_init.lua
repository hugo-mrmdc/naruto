-- cl_init.lua
-- Place dans garrysmod/lua/entities/npc_salamandre_ride/cl_init.lua

include("shared.lua")

function ENT:Draw()
    self:DrawModel()
end

-- Hook pour forcer l'animation du joueur monté
hook.Add("CalcMainActivity", "SalamandreRiderAnim", function(ply, vel)
    -- Chercher si le joueur est sur une salamandre
    local parent = ply:GetParent()
    if IsValid(parent) and parent:GetClass() == "npc_salamandre_ride" then
        local seq = ply:LookupSequence("nrp_lobby_shikamaru_etc_team_type1_wait_loop")
        if seq and seq > 0 then
            return ACT_INVALID, seq
        end
    end
end)

-- Alternative avec UpdateAnimation
hook.Add("UpdateAnimation", "SalamandreRiderAnimUpdate", function(ply, vel, maxSeqGroundSpeed)
    local parent = ply:GetParent()
    if IsValid(parent) and parent:GetClass() == "npc_salamandre_ride" then
        local seq = ply:LookupSequence("nrp_lobby_shikamaru_etc_team_type1_wait_loop")
        if seq and seq > 0 then
            ply:SetSequence(seq)
            ply:SetPlaybackRate(1)
            return true
        end
    end
end)