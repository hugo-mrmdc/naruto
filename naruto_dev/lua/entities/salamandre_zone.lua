--========================================================
-- Dôme de brume de la salamandre (entité, SERVEUR + CLIENT)
--
-- Zone toxique posée au sol pendant quelques secondes : blesse et empoisonne
-- tout ce qui est dedans, sauf celui qui l'a lancée.
-- La brume (godio_fumee_sala) est créée par chaque client à la réception de
-- l'entité : tout le monde la voit, et elle disparaît avec l'entité.
--
-- Les valeurs viennent de la technique (sv_dome_salamandre.lua) au lancement.
--========================================================

AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "base_anim"
ENT.PrintName = "Dôme de brume"
ENT.Spawnable = false

ENT.Model = "models/props_junk/PopCan01a.mdl"   -- invisible, seule la brume se voit
ENT.FX    = "godio_fumee_sala"                  -- particles/godio_salamandre.pcf

-- Valeurs par défaut (remplacées au lancement)
ENT.Duree         = 5
ENT.Rayon         = 500     -- = rayon du dôme de fumée dans le .pcf
ENT.Degats        = 5
ENT.Intervalle    = 0.5
ENT.PoisonDuree   = 3       -- 0 = pas de poison

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

        self:EmitSound("naruto_sound/jutsu/senju/senju2.wav", 75, 70)
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

        for _, ent in ipairs(ents.FindInSphere(centre, rayon)) do
            if not EstCible(ent, lanceur) then continue end

            -- dôme : rien sous le sol de la zone
            if ent:WorldSpaceCenter().z < centre.z - 32 then continue end

            local dmg = DamageInfo()
            dmg:SetDamage(self.Degats)
            dmg:SetAttacker(IsValid(lanceur) and lanceur or self)
            dmg:SetInflictor(self)
            dmg:SetDamageType(DMG_ACID)
            dmg:SetDamagePosition(ent:WorldSpaceCenter())
            ent:TakeDamageInfo(dmg)

            -- le poison de la salamandre (sv_poison_projectile.lua), s'il est chargé
            if self.PoisonDuree > 0 and SalamandrePoison and SalamandrePoison.Apply then
                SalamandrePoison.Apply(ent, lanceur, self.PoisonDuree)
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
        -- la brume déborde largement du petit modèle : zone d'affichage à sa taille
        local r = math.max(self:GetRayon(), 64)
        self:SetRenderBounds(Vector(-r, -r, -32), Vector(r, r, r))
    end

    -- La brume est (re)créée ici plutôt qu'à l'Initialize : plus fiable, et
    -- relancée si l'entité sort puis revient dans le champ du joueur.
    function ENT:Think()
        if not (self.Particule and self.Particule:IsValid()) then
            self.Particule = CreateParticleSystem(self, self.FX, PATTACH_ABSORIGIN_FOLLOW, 0)
        end
        self:SetNextClientThink(CurTime() + 0.25)
        return true
    end

    function ENT:Draw()
        -- rien : seule la brume est visible
    end

    function ENT:OnRemove()
        if self.Particule and self.Particule:IsValid() then self.Particule:StopEmission() end
        self:StopParticles()
    end
end
