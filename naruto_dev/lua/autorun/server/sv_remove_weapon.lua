-- Empêche les armes de base au spawn
hook.Add("PlayerLoadout", "NA_NoDefaultWeapons", function(ply)
    return true
end)

-- Empêche le give / spawn d’armes via menu
hook.Add("PlayerGiveSWEP", "NA_BlockGiveSWEP", function(ply, class)
   -- return false
end)

hook.Add("PlayerSpawnSWEP", "NA_BlockSpawnSWEP", function(ply, class)
     --return false
end)
hook.Add("PlayerSwitchFlashlight", "DisableFlashlightCompletely", function(ply, enabled)
    return false
end)
