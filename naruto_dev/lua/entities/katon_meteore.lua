--========================================================
-- Katon : Météore (entité, SERVEUR + CLIENT)
--
-- Le modèle atg_katon_meteor tombe du ciel (lâché par sv_katon_meteore.lua) en accélérant, tout droit vers le bas. Quand il touche
-- le sol (ou un mur, ou un ennemi en travers) : explosion (particule solve_katon_chute_celeste_explo, jouée chez tout le monde
-- par cl_katon_meteore.lua), dégâts de zone (les mêmes partout dans le rayon) et brûlure.
-- Le modèle fait 418 de large et 355 de haut à l'échelle 1, son origine est en BAS : le bas du météore touche le sol à l'impact.
--========================================================

AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "base_anim"
ENT.PrintName = "Météore"
ENT.Spawnable = false

ENT.Model         = "models/nature/katon/atg_katon_meteor.mdl"
ENT.Degats        = 400
ENT.Rayon         = 600
ENT.Echelle       = 1       -- taille du modèle (1 = taille d'origine)
ENT.VitesseDepart = 600
ENT.Gravite       = 2400    -- accélération de chute (unités/s²)
ENT.VitesseMax    = 3500
ENT.DureeVie      = 10
ENT.BrulureDuree  = 4
ENT.BrulureDps    = 6

if SERVER then
    local function EstCible(ent, owner) return NA_InkutonEstCible and NA_InkutonEstCible(ent, owner) end   -- sv_inkuton_singes.lua

    function ENT:Initialize()
        self:SetModel(self.Model)
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_NONE)
        self:DrawShadow(false)
        self:SetModelScale(self.Echelle, 0)
        self.Vitesse = self.VitesseDepart
        self.MortA = CurTime() + self.DureeVie
        self:EmitSound("geams/solve_jutsu/katon/solve_katon_fire_tornado_start.wav", 95, 60, 1)
    end

    function ENT:Exploser(pos)
        pos = pos or self:GetPos()
        local owner = self:GetOwner()
        self:StopSound("geams/solve_jutsu/katon/solve_katon_fire_tornado_start.wav")

        net.Start("katon_meteore_fx")
            net.WriteVector(pos)
        net.Broadcast()
        sound.Play("geams/solve_jutsu/katon/solve_katon_fireball_01.wav", pos, 140, 80, 1)
        sound.Play("geams/solve_jutsu/katon/solve_katon_arena_start.wav", pos, 120, 60, 1)
        util.ScreenShake(pos, 15, 30, 1.5, self.Rayon * 3)

        for _, ent in ipairs(ents.FindInSphere(pos + Vector(0, 0, 60), self.Rayon)) do
            if not EstCible(ent, owner) then continue end

            local dmg = DamageInfo()
            dmg:SetDamage(self.Degats)   -- pas de réduction selon la distance
            dmg:SetAttacker(IsValid(owner) and owner or self)
            dmg:SetInflictor(self)
            dmg:SetDamageType(DMG_BURN)
            dmg:SetDamagePosition(pos)
            dmg:SetDamageForce((ent:WorldSpaceCenter() - pos):GetNormalized() * 30000 + Vector(0, 0, 8000))
            ent:TakeDamageInfo(dmg)
            if self.BrulureDuree > 0 and NA_Bruler then NA_Bruler(ent, owner, self.BrulureDuree, self.BrulureDps) end   -- sv_bouledefeut.lua
        end
        self:Remove()
    end

    function ENT:Think()
        self:NextThink(CurTime())
        if CurTime() > self.MortA then self:Exploser() return true end

        local dt = FrameTime()
        self.Vitesse = math.min(self.Vitesse + self.Gravite * dt, self.VitesseMax)
        local from = self:GetPos()
        local to = from - Vector(0, 0, self.Vitesse * dt)

        -- impact : sol, mur, ou un joueur / PNJ en travers (le lanceur est ignoré)
        local r = 150 * self.Echelle
        local tr = util.TraceHull({
            start = from, endpos = to - Vector(0, 0, 10),
            mins = Vector(-r, -r, 0), maxs = Vector(r, r, 20),
            filter = { self, self:GetOwner() }, mask = MASK_SOLID,
        })
        if tr.Hit then self:Exploser(tr.HitPos) return true end

        self:SetPos(to)
        return true
    end
end

if CLIENT then
    game.AddParticles("particles/solve_new_katon.pcf")

    -- éclairage fixe : sinon le modèle devient noir à l'ombre
    function ENT:Draw()
        render.SuppressEngineLighting(true)
        render.ResetModelLighting(1, 0.9, 0.8)
        self:DrawModel()
        render.SuppressEngineLighting(false)
    end
end
