--========================================================
-- Dôme de feu (entité, SERVEUR + CLIENT)
--
-- Zone de flammes posée au sol pendant quelques secondes : blesse et brûle
-- tout ce qui est dedans, sauf celui qui l'a lancée.
-- Le feu (fire_dome_charge) est créé par chaque client à la réception de
-- l'entité : tout le monde le voit, et il disparaît avec l'entité.
--
-- Les valeurs viennent de la technique (sv_katon_dome.lua) au lancement.
--========================================================

AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "base_anim"
ENT.PrintName = "Dôme de feu"
ENT.Spawnable = false

ENT.Model = "models/props_junk/PopCan01a.mdl"   -- invisible, seul le feu se voit
ENT.FX    = "fire_dome_charge"                  -- particles/1izoxsolvenr.pcf

-- Valeurs par défaut (remplacées au lancement)
ENT.Duree         = 5
ENT.Rayon         = 300     -- à régler sur la taille du dôme dans le .pcf
ENT.Degats        = 6
ENT.Intervalle    = 0.5
ENT.BrulureDuree  = 4       -- 0 = pas de brûlure
ENT.BrulureDps    = 4

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

        self:EmitSound("ambient/fire/ignite.wav", 80, 90)
    end

    local function EstCible(ent, lanceur)
        if not IsValid(ent) or ent == lanceur then return false end
        if ent:IsPlayer() then return ent:Alive() end
        if ent:IsNPC() or ent:IsNextBot() then return ent:Health() > 0 end
        return false
    end

    function ENT:Blesser()
        local centre = self:GetPos()
        local rayon = self:GetRayon()
        local lanceur = self:GetOwner()
        local now = CurTime()

        for _, ent in ipairs(ents.FindInSphere(centre, rayon)) do
            if not EstCible(ent, lanceur) then continue end

            -- zone au sol : rien sous le sol de la zone
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

        if now >= self.ProchainTick then
            self.ProchainTick = now + self.Intervalle
            self:Blesser()
        end

        self:NextThink(now + 0.1)
        return true
    end
end

if CLIENT then
    function ENT:Initialize()
        -- le feu déborde largement du petit modèle : zone d'affichage à sa taille
        local r = math.max(self:GetRayon(), 64)
        self:SetRenderBounds(Vector(-r, -r, -32), Vector(r, r, r))
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
