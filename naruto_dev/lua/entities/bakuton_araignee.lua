--========================================================
-- Bakuton : Mine explosive (entité, SERVEUR + CLIENT)
-- Posée directement en cercle au sol autour de la cible (modèle atg_mine_bakuton) : la première étourdit la
-- cible (comme le cube Jinton), puis toutes les mines explosent quand l'étourdissement se termine
-- (particules de Shibuki).
--========================================================

AddCSLuaFile()

game.AddParticles("particles/bigboom.pcf")
PrecacheParticleSystem("ExplosionCore_MidAir")

ENT.Type      = "anim"
ENT.Base      = "base_anim"
ENT.PrintName = "Mine explosive"
ENT.Spawnable = false

-- Valeurs par défaut ; la technique les remplace au lancement (sv_bakuton_araignees.lua)
ENT.Degats      = 15     -- à l'explosion, sur la cible seulement
ENT.Duree       = 2      -- durée du stun
ENT.Index, ENT.Total = 1, 1   -- place de la mine parmi celles posées (répartition en cercle)
ENT.RayonMines  = 70     -- rayon du cercle de mines autour de la cible (en plus de sa largeur)
ENT.EchelleMine = 1      -- ajuster si les mines sont trop grosses / petites
ENT.ModeleMine  = "models/bakuton/atg_mine_bakuton.mdl"
ENT.Son         = "bakuton/solve_bakuton_explosion.wav"

if SERVER then
    function ENT:Initialize()
        self:SetModel(self.ModeleMine)
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_NONE)
        self:DrawShadow(false)
        self:SetModelScale(self.EchelleMine, 0)
        local id = self:LookupSequence("idle")
        if id >= 0 then self:ResetSequence(id) end

        -- place de la mine : cercle régulier autour de la cible, posé au sol
        local cible = self.Cible
        local rayon = self.RayonMines
        if IsValid(cible) then rayon = rayon + math.max(cible:OBBMaxs().x, cible:OBBMaxs().y) end
        self.Decalage = Angle(0, 360 * (self.Index - 1) / self.Total, 0):Forward() * rayon
        self:Placer()

        -- la première mine étourdit ; les suivantes durent jusqu'à la même fin
        if IsValid(cible) and (cible.BakutonStunFin or 0) <= CurTime() then
            cible.BakutonStunFin = CurTime() + self.Duree
            if NA_Etourdir then NA_Etourdir(cible, self.Duree) end   -- sv_etourdissement.lua
        end
    end

    -- au sol, à sa place autour de la cible
    function ENT:Placer()
        local pos = self.Cible:GetPos() + self.Decalage
        local sol = util.TraceLine({ start = pos + Vector(0, 0, 60), endpos = pos - Vector(0, 0, 200), mask = MASK_SOLID_BRUSHONLY })
        self:SetPos(sol.Hit and sol.HitPos or pos)
    end

    function ENT:Exploser()
        if self.Fini then return end
        self.Fini = true
        local cible, owner = self.Cible, self:GetOwner()
        local pos = self:GetPos()
        ParticleEffect("ExplosionCore_MidAir", pos, angle_zero)
        sound.Play(self.Son, pos, 75, math.random(95, 110), 1)
        if IsValid(cible) then
            local dmg = DamageInfo()
            dmg:SetDamage(self.Degats)
            dmg:SetAttacker(IsValid(owner) and owner or self)
            dmg:SetInflictor(self)
            dmg:SetDamageType(DMG_BLAST)
            dmg:SetDamagePosition(pos)
            cible:TakeDamageInfo(dmg)
        end
        self:Remove()
    end

    function ENT:Think()
        self:NextThink(CurTime())
        if self.Fini then return true end
        local cible = self.Cible
        if not IsValid(cible) or (cible:IsPlayer() and not cible:Alive()) or (cible:IsNPC() and cible:Health() <= 0) then
            self:Remove() return true
        end
        if CurTime() >= (cible.BakutonStunFin or 0) then self:Exploser() return true end
        self:Placer()   -- suit la cible
        return true
    end
end

if CLIENT then
    function ENT:Draw() self:DrawModel() end
end
