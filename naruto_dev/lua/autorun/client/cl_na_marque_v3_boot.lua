if SERVER then return end

print("[MarquePatch] BOOT V7 OK")

concommand.Add("na_marque_v3_loaded", function()
    print("[MarquePatch] V7 autorun chargé OK")
    print("[MarquePatch] na_marque_diag existe:", concommand.GetTable()["na_marque_diag"] ~= nil)
    print("[MarquePatch] na_marque_peau_preview existe:", concommand.GetTable()["na_marque_peau_preview"] ~= nil)
    print("[MarquePatch] NA_GetTeteRendue existe:", isfunction(NA_GetTeteRendue))
end)
