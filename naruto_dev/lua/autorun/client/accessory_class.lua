-- ========================================
-- accessory_class.lua - CÔTÉ CLIENT
-- Classe pour gérer les accessoires
-- ========================================

Accessory = {}
Accessory.__index = Accessory

function Accessory:new(owner, modelPath, boneName, posOffset, angOffset, scale)
    local obj = setmetatable({}, self)

    obj.Owner = owner
    obj.ModelPath = modelPath
    obj.BoneName = boneName or "ValveBiped.Bip01_Head1"
    obj.PosOffset = posOffset or Vector(0, 0, 0)
    obj.AngOffset = angOffset or Angle(0, 0, 0)
    obj.Scale = scale or 1

    obj.Model = ClientsideModel(obj.ModelPath, RENDERGROUP_OPAQUE)
    if IsValid(obj.Model) then
        obj.Model:SetNoDraw(true)
    end

    print("[ACCESSORY] Créé: " .. modelPath)

    return obj
end

function Accessory:IsValid()
    return IsValid(self.Owner) and IsValid(self.Model)
end

function Accessory:Draw()
    if self.Owner:GetNWBool("IsInvisible", false) then return end
    if not self:IsValid() then return end

    self.Owner:SetupBones()

    local boneID = self.Owner:LookupBone(self.BoneName)
    if not boneID then 
        boneID = self.Owner:LookupBone("ValveBiped.Bip01_Head1")
        if not boneID then return end
    end

    local boneMatrix = self.Owner:GetBoneMatrix(boneID)
    if not boneMatrix then return end
    
    local pos = boneMatrix:GetTranslation()
    local ang = boneMatrix:GetAngles()

    ang = Angle(ang.p, ang.y, ang.r)

    ang:RotateAroundAxis(ang:Right(),   self.AngOffset.p)
    ang:RotateAroundAxis(ang:Up(),      self.AngOffset.y)
    ang:RotateAroundAxis(ang:Forward(), self.AngOffset.r)

    pos = pos
        + ang:Forward() * self.PosOffset.x
        + ang:Right()   * self.PosOffset.y
        + ang:Up()      * self.PosOffset.z

    self.Model:SetPos(pos)
    self.Model:SetAngles(ang)
    self.Model:SetModelScale(self.Scale or 1, 0)

    -- Sauvegarder l'état du rendu
    local oldR, oldG, oldB = render.GetColorModulation()
    local oldBlend = render.GetBlend()
    
    -- Appliquer éclairage neutre
    render.SuppressEngineLighting(true)
    render.SetLightingOrigin(pos)
    render.ResetModelLighting(1, 1, 1)
    render.SetColorModulation(1, 1, 1)
    render.SetBlend(1)
    
    self.Model:DrawModel()
    
    -- Restaurer
    render.SuppressEngineLighting(false)
    render.SetColorModulation(oldR, oldG, oldB)
    render.SetBlend(oldBlend)
    render.SetLightingOrigin(vector_origin)
end

function Accessory:Remove()
    if IsValid(self.Model) then
        self.Model:Remove()
    end
end

print("[CLIENT] Classe Accessory chargée")