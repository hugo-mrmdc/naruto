if SERVER then

    hook.Add("InitPostEntity", "ATG_CreateFallbackSpawn", function()
        if game.GetMap() ~= "rp_atg_v3" then return end

        local existing = ents.FindByClass("info_player_start")

        if #existing > 0 then
            print("[SpawnFix] La map possède déjà un info_player_start.")
            return
        end

        local spawn = ents.Create("info_player_start")

        if not IsValid(spawn) then
            print("[SpawnFix] Impossible de créer le spawn.")
            return
        end

        -- Position temporaire
        spawn:SetPos(Vector(0, 0, 100))
        spawn:SetAngles(Angle(0, 0, 0))
        spawn:Spawn()

        print("[SpawnFix] Spawn créé à 0 0 100.")
    end)


    hook.Add("PlayerSelectSpawn", "ATG_SelectFallbackSpawn", function(ply)
        if game.GetMap() ~= "rp_atg_v3" then return end

        local spawns = ents.FindByClass("info_player_start")

        if #spawns > 0 then
            return spawns[math.random(#spawns)]
        end
    end)

end