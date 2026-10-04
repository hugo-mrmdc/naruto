--========================================================
-- Shoton : Cristal (entité, SERVEUR + CLIENT)
-- Posée sur la cible étourdie (sv_shoton_cristal.lua) : un cristal (models/shoton/solve_crystal01_kg_geams.mdl)
-- l'enferme. Posé quand la particule du lanceur (cl_shoton_cristal.lua) atteint la cible.
-- Disparaît au bout de DureeVie, ou si la cible ou le lanceur meurt.
--========================================================

AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "base_anim"
ENT.PrintName = "Cristal Shoton"
ENT.Spawnable = false

ENT.DureeVie = 3
ENT.DureePousse = 0.35   -- secondes pour que le cristal grossisse jusqu'à sa taille
ENT.Marge    = 2.2 -- le cristal fait Marge x la taille de la cible (hauteur) : ajuster si trop gros / petit

if SERVER then
    -- bas du cristal posé sur le sol sous la cible, centré dessus : il grossit depuis le sol
    function ENT:Poser()
        local cible, s = self.Cible, self:GetModelScale()
        if not IsValid(cible) then return end
        self:SetPos(cible:GetPos() - Vector(self.Centre.x * s, self.Centre.y * s, self.Mins.z * s))
    end

    function ENT:Initialize()
        self:SetModel("models/shoton/solve_crystal01_kg_geams.mdl")
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_NONE)
        self:DrawShadow(false)

        -- taille adaptée à la cible, centré sur elle
        local cible = self.Cible
        local mins, maxs = self:GetModelBounds()
        local hauteur = math.max(maxs.z - mins.z, 1)
        local ech = IsValid(cible) and (cible:OBBMaxs().z - cible:OBBMins().z) * self.Marge / hauteur or 1
        -- apparition progressive : le cristal grossit jusqu'à sa taille (recentré à chaque image dans Think)
        self.Mins, self.Centre = mins, (mins + maxs) / 2
        self.FinPousse = CurTime() + self.DureePousse
        self:SetModelScale(0.01, 0)
        self:SetModelScale(ech, self.DureePousse)
        self:Poser()

        self.MortA = CurTime() + self.DureeVie
    end

    function ENT:Think()
        self:NextThink(CurTime())
        local owner, cible = self:GetOwner(), self.Cible
        if CurTime() < self.FinPousse then self:Poser() end
        if CurTime() > self.MortA or not IsValid(cible) or cible:Health() <= 0
            or not IsValid(owner) or (owner:IsPlayer() and not owner:Alive()) then
            self:Remove()
            return true
        end
        return true
    end

    -- le cristal se brise : mêmes particules qu'à sa création (cl_shoton_cristal.lua)
    function ENT:OnRemove()
        local cible = self.Cible
        net.Start("shoton_cristal_brise")
            -- au sol, sous la cible
            local centre = IsValid(cible) and cible:WorldSpaceCenter() or self:WorldSpaceCenter()
            local sol = util.TraceLine({ start = centre, endpos = centre - Vector(0, 0, 400), mask = MASK_SOLID_BRUSHONLY })
            net.WriteVector(sol.Hit and sol.HitPos or centre)
        net.Broadcast()
    end
end

if CLIENT then
    function ENT:Draw() self:DrawModel() end
end
