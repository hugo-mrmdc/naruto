--========================================================
-- Tornade de sable (entité, SERVEUR + CLIENT)
--
-- Avance TOUT DROIT (à plat, collée au sol) jusqu'à un mur ou la fin de sa
-- durée de vie. Tout ennemi qu'elle traverse est blessé UNE fois et projeté en l'air.
-- Particule [1]_sand_tornado (particles/atg_faris.pcf), attachée à l'entité et
-- créée par chaque client : elle reste toujours au même endroit de la tornade
-- (entité droite : le tourbillon monte selon son axe Z).
--
-- Les valeurs viennent de la technique (sv_jiton_tornade.lua) au lancement.
--========================================================

AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "base_anim"
ENT.PrintName = "Tornade de sable"
ENT.Spawnable = false

ENT.Model = "models/props_junk/PopCan01a.mdl"   -- invisible, seules les particules se voient
ENT.FX    = "[1]_sand_tornado"

-- Valeurs par défaut (remplacées au lancement)
ENT.Vitesse    = 600   -- unités / seconde
ENT.DureeVie   = 2.5   -- secondes (distance = vitesse x durée)
ENT.Rayon      = 110   -- zone qui blesse (~ taille de la particule, developer 1 pour la voir)
ENT.Hauteur    = 220   -- hauteur de la zone au-dessus du sol
ENT.Degats     = 25    -- dégâts, une seule fois par ennemi
ENT.Projection = 350   -- vitesse verticale donnée à l'ennemi touché

function ENT:SetupDataTables()
    self:NetworkVar("Float", 0, "Rayon")
end

if SERVER then
    function ENT:Initialize()
        self:SetModel(self.Model)
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_NONE)
        self:DrawShadow(false)
        self:SetAngles(angle_zero)   -- les particules montent selon l'axe Z de l'entité

        self:SetRayon(self.Rayon)
        self.Direction = self.Direction or self:GetForward()
        self.Direction.z = 0
        self.Direction:Normalize()
        self.MortA = CurTime() + self.DureeVie
        self.Dernier = CurTime()
        self.Touches = {}

        self:EmitSound("ambient/wind/wind_snippet4.wav", 80, 80)
    end

    local function EstCible(ent, lanceur)
        if not IsValid(ent) or ent == lanceur then return false end
        if ent:IsPlayer() then return ent:Alive() end
        if ent:IsNPC() then return ent:GetNPCState() ~= NPC_STATE_DEAD end
        if ent:IsNextBot() then return ent:Health() > 0 end
        return false
    end

    function ENT:Blesser()
        local lanceur = self:GetOwner()
        local pos = self:GetPos()

        for _, ent in ipairs(ents.FindInSphere(pos + Vector(0, 0, self.Hauteur / 2), self.Rayon + self.Hauteur / 2)) do
            if self.Touches[ent] or not EstCible(ent, lanceur) then continue end

            -- cylindre : assez près à l'horizontale, entre le sol et le haut de la tornade
            local p = ent:GetPos()
            local ecart = Vector(p.x - pos.x, p.y - pos.y, 0):Length()
            if ecart > self.Rayon or p.z + ent:OBBMaxs().z < pos.z or p.z > pos.z + self.Hauteur then continue end

            self.Touches[ent] = true

            local dmg = DamageInfo()
            dmg:SetDamage(self.Degats)
            dmg:SetAttacker(IsValid(lanceur) and lanceur or self)
            dmg:SetInflictor(self)
            dmg:SetDamageType(DMG_CRUSH)
            dmg:SetDamagePosition(ent:WorldSpaceCenter())
            ent:TakeDamageInfo(dmg)

            ent:SetVelocity(Vector(0, 0, self.Projection) + self.Direction * 150)
            ent:EmitSound("player/footsteps/sand2.wav", 75, math.random(90, 110), 0.8)
        end

        if GetConVar("developer"):GetInt() > 0 then
            debugoverlay.Sphere(pos + Vector(0, 0, self.Hauteur / 2), self.Rayon, 0.1, Color(220, 180, 90, 20), true)
        end
    end

    function ENT:Think()
        local now = CurTime()
        local dt = now - self.Dernier
        self.Dernier = now

        if now >= self.MortA then
            self:Remove()
            return
        end

        -- pas en avant, arrêté par les murs
        local depart = self:GetPos() + Vector(0, 0, 40)
        local mur = Vector(30, 30, 30)
        local tr = util.TraceHull({
            start = depart,
            endpos = depart + self.Direction * self.Vitesse * dt,
            mins = -mur, maxs = mur, mask = MASK_SOLID_BRUSHONLY,
        })
        if tr.Hit then self:Remove() return end

        -- collée au sol
        local sol = util.TraceLine({
            start = tr.HitPos, endpos = tr.HitPos - Vector(0, 0, 240), mask = MASK_SOLID_BRUSHONLY,
        })
        if not sol.Hit then self:Remove() return end   -- plus de sol (vide) : elle se dissipe
        self:SetPos(sol.HitPos)

        self:Blesser()

        self:NextThink(now)
        return true
    end

    function ENT:OnRemove()
        self:StopSound("ambient/wind/wind_snippet4.wav")
    end
end

if CLIENT then
    function ENT:Initialize()
        local r = math.max(self:GetRayon(), 128)
        self:SetRenderBounds(Vector(-r, -r, -32), Vector(r, r, 800))
    end

    -- (re)créée ici plutôt qu'à l'Initialize : l'entité n'est pas toujours prête à sa
    -- création côté client, et l'effet doit être relancé si elle revient dans le champ
    function ENT:Think()
        if not (self.Particule and self.Particule:IsValid()) then
            self.Particule = CreateParticleSystem(self, self.FX, PATTACH_ABSORIGIN_FOLLOW, 0)
        end
        self:SetNextClientThink(CurTime() + 0.1)
        return true
    end

    function ENT:Draw()
        -- rien : seules les particules sont visibles
    end

    function ENT:OnRemove()
        if self.Particule and self.Particule:IsValid() then self.Particule:StopEmission() end
        self:StopParticles()
    end
end
