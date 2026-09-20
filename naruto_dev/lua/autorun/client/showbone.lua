concommand.Add("show_bones", function()
    local ent = LocalPlayer():GetEyeTrace().Entity
    
    if not IsValid(ent) then
        print("Regarde une entité!")
        return
    end
    
    print("")
    print("=== BONES DE: " .. ent:GetModel() .. " ===")
    print("Nombre de bones: " .. ent:GetBoneCount())
    print("")
    
    for i = 0, ent:GetBoneCount() - 1 do
        local name = ent:GetBoneName(i)
        local parent = ent:GetBoneParent(i)
        print(i .. ": " .. name .. " (parent: " .. parent .. ")")
    end
    
    print("")
    print("=================================")
end)
