-- Commande: mdl_anims <chemin_modele.mdl>
-- Exemple: mdl_anims models/suiton/shark_solve_geams.mdl

local function PrintSequences(modelPath)
    if not modelPath or modelPath == "" then
        print("[mdl_anims] Utilisation: mdl_anims models/xxx/yyy.mdl")
        return
    end

    if not string.EndsWith(string.lower(modelPath), ".mdl") then
        modelPath = modelPath .. ".mdl"
    end

    local m = ClientsideModel(modelPath, RENDERGROUP_OTHER)
    if not IsValid(m) then
        print("[mdl_anims] MODELE INTROUVABLE: " .. modelPath)
        return
    end

    m:SetNoDraw(true)

    local count = m:GetSequenceCount() or 0
    print("======================================")
    print("[mdl_anims] Model: " .. modelPath)
    print("[mdl_anims] Sequences: " .. count)

    for i = 0, math.max(count - 1, 0) do
        local name = m:GetSequenceName(i)
        print(string.format("%3d  %s", i, tostring(name)))
    end

    print("======================================")
    m:Remove()
end

concommand.Add("mdl_anims", function(_, _, args)
    PrintSequences(args and args[1] or "")
end)

-- Petit bonus: afficher aussi les bones
concommand.Add("mdl_bones", function(_, _, args)
    local modelPath = args and args[1] or ""
    if modelPath == "" then
        print("[mdl_bones] Utilisation: mdl_bones models/xxx/yyy.mdl")
        return
    end
    if not string.EndsWith(string.lower(modelPath), ".mdl") then
        modelPath = modelPath .. ".mdl"
    end

    local m = ClientsideModel(modelPath, RENDERGROUP_OTHER)
    if not IsValid(m) then
        print("[mdl_bones] MODELE INTROUVABLE: " .. modelPath)
        return
    end

    m:SetNoDraw(true)

    local bc = m:GetBoneCount() or 0
    print("======================================")
    print("[mdl_bones] Model: " .. modelPath)
    print("[mdl_bones] Bones: " .. bc)

    for i = 0, math.max(bc - 1, 0) do
        print(i, m:GetBoneName(i))
    end

    print("======================================")
    m:Remove()
end)
