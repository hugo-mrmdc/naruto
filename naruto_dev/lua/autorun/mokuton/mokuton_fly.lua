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
