--========================================================
-- Tornade de feu (entité, SERVEUR + CLIENT)
--
-- Tornade de flammes posée au sol : elle ATTIRE vers son centre tout ce qui est
-- dans son rayon, le blesse et le brûle, sauf celui qui l'a lancée.
-- Le feu (solve_katon_tornado_floor) est créé par chaque client à la réception
-- de l'entité : tout le monde le voit, et il disparaît avec l'entité.
--
-- Les valeurs viennent de la technique (sv_katon_tornade.lua) au lancement.
--========================================================

AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "base_anim"
ENT.PrintName = "Tornade de feu"
ENT.Spawnable = false

ENT.Model = "models/props_junk/PopCan01a.mdl"   -- invisible, seul le feu se voit
ENT.FX    = "solve_katon_tornado_floor"         -- particles/solve_new_katon.pcf

-- Valeurs par défaut (remplacées au lancement)
ENT.Duree         = 5
ENT.Rayon         = 350
ENT.Degats        = 5
ENT.Intervalle    = 0.5
ENT.BrulureDuree  = 4       -- 0 = pas de brûlure
ENT.BrulureDps    = 4
ENT.Attraction    = 600     -- vitesse d'aspiration vers le centre (unités/s)

function ENT:SetupDataTables()
    self:NetworkVar("Float", 0, "Rayon")
    self:NetworkVar("Float", 1, "Fin")
end

if SERVER then
    function ENT:Initialize()
        self:SetModel(self.Model)
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_NONE)
        self:DrawShadow(false)

        self:SetRayon(self.Rayon)
        self:SetFin(CurTime() + self.Duree)
        self.ProchainTick = CurTime()
        self.Brule = {}   -- cible -> fin de la brûlure qu'on lui a mise (pas de brûlure empilée à chaque tick)

        self:EmitSound("geams/solve_jutsu/katon/solve_katon_arena_start.wav", 80, 80)
    end

    local function EstCible(ent, lanceur)
        if not IsValid(ent) or ent == lanceur then return false end
        if ent:IsPlayer() then return ent:Alive() end
        if ent:IsNPC() or ent:IsNextBot() then return ent:Health() > 0 end
        return false
    end

    -- aspire la cible vers le centre (appelé souvent : le mouvement reste fluide)
    function ENT:Attirer(ent, dt)
        local centre = self:GetPos()
        local delta = centre - ent:GetPos()
        delta.z = 0
        local dist = delta:Length()
        if dist < 40 then return end   -- au cœur de la tornade : on ne le secoue plus

        local dir = delta / dist
        -- plus on est près du bord, plus l'aspiration est forte
        local force = self.Attraction * (0.5 + 0.5 * math.min(dist / self:GetRayon(), 1))

        local vel = ent:GetVelocity()
        local voulu = dir * force
        -- on ajoute juste ce qui manque pour atteindre la vitesse voulue vers le centre
        local manque = voulu - Vector(vel.x, vel.y, 0)
        local boost = manque * math.min(dt * 6, 1)
        boost.z = ent:IsOnGround() and 40 or 0   -- décolle du sol pour ne pas frotter

        -- aucune projection de la cible (pas de transfert de force)
    end

    function ENT:Blesser()
        local lanceur = self:GetOwner()
        local now = CurTime()
        local centre = self:GetPos()

        for _, ent in ipairs(ents.FindInSphere(centre, self:GetRayon())) do
            if not EstCible(ent, lanceur) then continue end
            if ent:WorldSpaceCenter().z < centre.z - 32 then continue end

            local dmg = DamageInfo()
            dmg:SetDamage(self.Degats)
            dmg:SetAttacker(IsValid(lanceur) and lanceur or self)
            dmg:SetInflictor(self)
            dmg:SetDamageType(DMG_BURN)
            dmg:SetDamagePosition(ent:WorldSpaceCenter())
            ent:TakeDamageInfo(dmg)

            -- brûlure (NA_Bruler : sv_bouledefeut.lua), remise seulement quand la précédente est finie
            if self.BrulureDuree > 0 and NA_Bruler and (self.Brule[ent] or 0) <= now then
                self.Brule[ent] = now + self.BrulureDuree
                NA_Bruler(ent, lanceur, self.BrulureDuree, self.BrulureDps)
            end
        end
    end

    function ENT:Think()
        local now = CurTime()

        if now >= self:GetFin() then
            self:Remove()
            return
        end

        local dt = now - (self.DernierThink or now - 0.05)
        self.DernierThink = now

        local lanceur = self:GetOwner()
        local centre = self:GetPos()
        local r = self:GetRayon()
        for _, ent in ipairs(ents.FindInSphere(centre, r)) do
            if EstCible(ent, lanceur) and ent:WorldSpaceCenter().z >= centre.z - 32 then
                self:Attirer(ent, dt)
            end
        end

        if now >= self.ProchainTick then
            self.ProchainTick = now + self.Intervalle
            self:Blesser()
        end

        self:NextThink(now + 0.05)
        return true
    end
end

if CLIENT then
    function ENT:Initialize()
        -- le feu déborde largement du petit modèle : zone d'affichage à sa taille
        local r = math.max(self:GetRayon(), 64)
        self:SetRenderBounds(Vector(-r, -r, -32), Vector(r, r, r * 1.5))
    end

    -- Le feu est (re)créé ici plutôt qu'à l'Initialize : plus fiable, et
    -- relancé si l'entité sort puis revient dans le champ du joueur.
    function ENT:Think()
        if not (self.Particule and self.Particule:IsValid()) then
            self.Particule = CreateParticleSystem(self, self.FX, PATTACH_ABSORIGIN_FOLLOW, 0)
        end
        self:SetNextClientThink(CurTime() + 0.25)
        return true
    end

    function ENT:Draw()
        -- rien : seul le feu est visible
    end

    function ENT:OnRemove()
        if self.Particule and self.Particule:IsValid() then self.Particule:StopEmission() end
        self:StopParticles()
    end
end
