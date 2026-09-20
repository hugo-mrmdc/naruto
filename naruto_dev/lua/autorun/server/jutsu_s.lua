util.AddNetworkString("Jutsu_PlaySound")

net.Receive("Jutsu_PlaySound", function(_, ply)
    if not IsValid(ply) then return end

    ply:EmitSound(
        "base/mudra_sound_geams.wav", -- ✅ CORRECT
        75,
        100
    )
end)
