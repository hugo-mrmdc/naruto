-- Fichier de test temporaire (à supprimer) : lancer en jeu avec  lua_openscript_cl na_dbg_anim.lua
for _, m in ipairs({
    "models/player/wiltos/anim_dynamic_pointer.mdl",
    "models/player/wiltos/anim_base.mdl",
    "models/player/wiltos/anim_base_male.mdl",
    "models/m_anm.mdl",
    "models/tenue/senju/senju_a.mdl",
}) do
    local c = ClientsideModel(m)
    if IsValid(c) then
        print(m, "seq:", c:GetSequenceCount(), "fsc_taiju_idle:", c:LookupSequence("fsc_taiju_idle"),
            "NRGlobes:", c:LookupSequence("CustomMan_Attack_NRGlobes_Cmb01"), "nrp_base_dashstep_behind:", c:LookupSequence("nrp_base_dashstep_behind"))
        c:Remove()
    else
        print(m, "ClientsideModel invalide")
    end
end
