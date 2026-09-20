--========================================================
-- Fuma : Shuriken Céleste (entité, SERVEUR + CLIENT)
--
-- Tombe droit sur le sol en tournant. À l'impact : grosse fumée
-- (big_smoke_base, particles/bigfumee.pcf), dégâts de zone et projection.
-- Créé par sv_fumaciel.lua.
--========================================================

AddCSLuaFile()

ENT.Type        = "anim"
ENT.Base        = "base_anim"
ENT.PrintName   = "Shuriken Céleste"
ENT.Spawnable   = false
ENT.RenderGroup = RENDERGROUP_OPAQUE

ENT.Modele      = "models/fumaSpell/orga_props_shuriken.mdl"   -- ~107 unités de large, à plat
ENT.FX_IMPACT   = "big_smoke_base"        -- particles/bigfumee.pcf (fumée continue : on l'arrête après)
ENT.DUREE_FUMEE = 5                       -- secondes d'émission de la fumée, puis elle s'arrête
ENT.ROTATION    = 900                     -- degrés / seconde
ENT.ORIENTATION = "vertical"              -- "vertical" = le shuriken tombe sur la tranche
                                          -- "plat"     = à plat, face au sol
ENT.SON_CHUTE   = "fuma/swing1.wav"
ENT.SON_IMPACT  = "bakuton/solve_bakuton_explosion.wav"

-- Valeurs par défaut (remplacées au lancement)
ENT.Vitesse = 2200
ENT.Echelle = 3.5
ENT.Degats  = 70
ENT.Rayon   = 260
ENT.Poussee = 450

if SERVER then
    local function EstCible(ent, lanceur)
        if not IsValid(ent) or ent == lanceur then return false end
        if ent:IsPlayer() then return ent:Alive() end
        if ent:IsNPC() then return ent:GetNPCState() ~= NPC_STATE_DEAD end
        if ent:IsNextBot() then return ent:Health() > 0 end
        return false
    end

    function ENT:Initialize()
        self:SetModel(self.Modele)
        self:SetModelScale(self.Echelle, 0)
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_NONE)
        self:DrawShadow(false)
        self.Precedent = CurTime()
        self:EmitSound(self.SON_CHUTE, 90, 70)
    end

    function ENT:Impact(pos)
        -- attachée à l'entité (et pas posée au sol) : on peut l'arrêter ensuite,
        -- sinon la fumée, qui est continue, ne s'arrêterait jamais
        ParticleEffectAttach(self.FX_IMPACT, PATTACH_ABSORIGIN_FOLLOW, self, 0)
        sound.Play(self.SON_IMPACT, pos, 100, 100)
        util.ScreenShake(pos, 12, 8, 1.2, self.Rayon * 2)

        local owner = self:GetOwner()
        for _, ent in ipairs(ents.FindInSphere(pos, self.Rayon)) do
            if not EstCible(ent, owner) then continue end

            local attenuation = 1 - math.Clamp(ent:GetPos():Distance(pos) / self.Rayon, 0, 1)
            local dmg = DamageInfo()
            dmg:SetDamage(self.Degats * attenuation)
            dmg:SetAttacker(IsValid(owner) and owner or self)
            dmg:SetInflictor(self)
            dmg:SetDamageType(DMG_SLASH)
            dmg:SetDamagePosition(ent:WorldSpaceCenter())
            ent:TakeDamageInfo(dmg)

            if self.Poussee > 0 and ent:IsPlayer() then
                local dir = (ent:GetPos() - pos):GetNormalized()
                ent:SetVelocity(dir * self.Poussee * attenuation + Vector(0, 0, 250))
            end
        end

        if GetConVar("developer"):GetInt() > 0 then
            debugoverlay.Sphere(pos, self.Rayon, 3, Color(255, 100, 0, 30), true)
        end

        -- la fumée est continue : on garde un point d'émission le temps voulu
        self:SetNoDraw(true)
        self.Fini = true
        timer.Simple(self.DUREE_FUMEE, function()
            if IsValid(self) then
                self:StopParticles()
                self:Remove()
            end
        end)
    end

    function ENT:Think()
        if self.Fini then return end

        local now = CurTime()
        local dt = now - self.Precedent
        self.Precedent = now

        local depart = self:GetPos()
        local arrivee = depart - Vector(0, 0, self.Vitesse * dt)
        local demi = 55 * self.Echelle / 2

        local tr = util.TraceLine({ start = depart, endpos = arrivee - Vector(0, 0, demi), mask = MASK_SOLID })
        if tr.Hit then
            self:SetPos(tr.HitPos)
            self:Impact(tr.HitPos)
            return
        end

        self:SetPos(arrivee)
        self:NextThink(now)
        return true
    end
end

if CLIENT then
    function ENT:Initialize()
        self:SetRenderBounds(Vector(-700, -700, -700), Vector(700, 700, 700))   -- le shuriken est très grand
    end

    function ENT:Draw()
        local spin = (CurTime() * self.ROTATION) % 360
        local ang
        if self.ORIENTATION == "plat" then
            ang = Angle(0, spin, 0)                 -- à plat, il tourne autour de l'axe vertical
        else
            ang = Angle(-90, self:GetAngles().y, 0) -- sur la tranche, comme une roue
            ang:RotateAroundAxis(ang:Up(), spin)
        end
        self:SetAngles(ang)
        self:DrawModel()
    end
end
