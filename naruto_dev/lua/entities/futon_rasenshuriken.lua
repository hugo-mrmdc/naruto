--========================================================
-- Futon : Rasenshuriken (entité, SERVEUR + CLIENT)
--
-- Projectile invisible qui porte la particule rasenshuri_pat. Il avance droit devant lui ; au premier contact (mur, joueur,
-- PNJ) ou au bout de sa durée de vie : explosion ([1]Rasenshuriken_Explosion_event_test, jouée chez tout le monde par
-- cl_futon_rasenshuriken.lua), dégâts de zone (les mêmes partout dans le rayon) et projection. Les valeurs viennent de sv_futon_rasenshuriken.lua.
--========================================================

AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "base_anim"
ENT.PrintName = "Rasenshuriken"
ENT.Spawnable = false

ENT.Dir     = Vector(1, 0, 0)
ENT.Vitesse = 1400
ENT.Vie     = 3
ENT.Degats  = 120
ENT.Rayon   = 350
ENT.Poussee = 500
ENT.Souleve = 300
ENT.Hitbox  = 30   -- demi-largeur de la zone qui touche en vol

local FX_BOULE = "rasenshuri_pat"

if SERVER then
    local function EstCible(ent, lanceur) return NA_InkutonEstCible and NA_InkutonEstCible(ent, lanceur) end   -- sv_inkuton_singes.lua

    function ENT:Initialize()
        self:SetModel("models/hunter/misc/sphere025x025.mdl")
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_NONE)
        self:DrawShadow(false)
        self.Mort = CurTime() + self.Vie
        self:SetAngles(self.Dir:Angle())   -- la particule suit l'orientation de l'entité : elle part dans la direction visée
    end

    function ENT:Think()
        local now = CurTime()
        if now >= self.Mort then self:Explose(self:GetPos()) return end

        local dt = now - (self.Dernier or now - engine.TickInterval())
        self.Dernier = now

        local lanceur = self:GetOwner()
        local depart = self:GetPos()
        local arrivee = depart + self.Dir * self.Vitesse * dt
        local h = self.Hitbox

        local tr = util.TraceHull({
            start = depart, endpos = arrivee,
            mins = Vector(-h, -h, -h), maxs = Vector(h, h, h),
            filter = function(e) return e ~= self and e ~= lanceur and (e:IsWorld() or EstCible(e, lanceur)) end,
            mask = MASK_SHOT_HULL,
        })
        if tr.Hit then self:Explose(tr.HitPos, tr.HitNormal) return end

        self:SetAngles(self.Dir:Angle())
        self:SetPos(arrivee)
        self:NextThink(now)
        return true
    end

    function ENT:Explose(pos, normale)
        local lanceur = self:GetOwner()

        net.Start("futon_rasen_fx")
            net.WriteVector(pos)
            net.WriteVector(normale or Vector(0, 0, 1))   -- l'explosion s'oriente selon la surface touchée
        net.Broadcast()
        sound.Play("naruto_sound/jutsu/futon/futon11.wav", pos, 100, 100, 1)

        for _, ent in ipairs(ents.FindInSphere(pos, self.Rayon)) do
            if ent == lanceur or not EstCible(ent, lanceur) then continue end

            local pied = ent:WorldSpaceCenter()
            local coef = 1   -- pas de réduction selon la distance : plein dégât et pleine projection partout dans le rayon

            local dmg = DamageInfo()
            dmg:SetDamage(self.Degats * coef)
            dmg:SetAttacker(IsValid(lanceur) and lanceur or self)
            dmg:SetInflictor(self)
            dmg:SetDamageType(DMG_BLAST)
            dmg:SetDamagePosition(pos)
            ent:TakeDamageInfo(dmg)

            -- projection : à l'opposé de l'explosion, plus un soulèvement
            local dir = pied - pos
            dir.z = 0
            if dir:LengthSqr() < 1 then dir = self.Dir end
            dir:Normalize()
            -- aucune projection de la cible (pas de transfert de force)
        end

        self:Remove()
    end
else
    game.AddParticles("particles/patlick_atgparticules.pcf")
    PrecacheParticleSystem(FX_BOULE)

    function ENT:Initialize()
        self:SetNoDraw(true)   -- seule la particule se voit
        self.Fx = CreateParticleSystem(self, FX_BOULE, PATTACH_ABSORIGIN_FOLLOW, 0)
    end

    -- la particule disparaît tout de suite quand le projectile touche / disparaît (StopEmission(false, true) = fin immédiate)
    function ENT:OnRemove()
        if self.Fx and self.Fx:IsValid() then self.Fx:StopEmission(false, true) end
        self:StopParticles()
    end
end
