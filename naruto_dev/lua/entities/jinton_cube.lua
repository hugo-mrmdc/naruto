--========================================================
-- Jinton : Cube de confinement (entité, SERVEUR + CLIENT)
--
-- Enferme sa cible : elle est immobilisée et prend des dégâts à chaque tick,
-- avec la particule solve_geams_01_j (particles/solve_jinton_geams.pcf).
-- Les valeurs viennent de la technique (sv_jinton_cube.lua) au lancement.
--========================================================

AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "base_anim"
ENT.PrintName = "Cube de confinement"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH

ENT.Model      = "models/justu/jinton/cubeonoki2.mdl"   -- cube de ~72 unités, centré
ENT.FX         = "solve_geams_01_j"
ENT.SonDebut   = "jutsu/jinton/damage_cube_start.wav"       -- quand le cube se pose sur la cible
ENT.SonTick    = "jutsu/jinton/damage_cube_explosion.wav"   -- à chaque tick de dégâts

-- Valeurs par défaut (remplacées au lancement)
ENT.Duree      = 4
ENT.Degats     = 8
ENT.Intervalle = 0.5
ENT.Echelle    = 1.1
ENT.TypeDegats = DMG_GENERIC    -- mort normale : le corps tombe en ragdoll  -- une cible tuée par le cube se désintègre

function ENT:SetupDataTables()
    self:NetworkVar("Entity", 0, "Cible")
    self:NetworkVar("Float", 0, "Fin")
end

if SERVER then
    ----------------------------------------------------------
    -- Stun : immobilise joueurs et PNJ, et les libère à la fin
    ----------------------------------------------------------
    -- PNJ : on ne les "gèle" pas (SCHED_NPC_FREEZE / MOVETYPE_NONE les empêchaient
    -- de mourir : ils restaient debout à 0 PV). On les maintient sur place à chaque
    -- Think et on annule ce qu'ils étaient en train de faire.
    local function Immobiliser(ent, cube)
        if ent:IsPlayer() then
            ent:Freeze(true)
            ent:SetVelocity(-ent:GetVelocity())
            ent:SetNW2Bool("NA_Etourdi", true)
        else
            cube.PositionTenue = ent:GetPos()
            if ent:IsNPC() then
                ent:ClearSchedule()
                ent:StopMoving()
            end
        end
    end

    local function Maintenir(ent, cube)
        if ent:IsPlayer() then
            ent:SetVelocity(-ent:GetVelocity())
        elseif cube.PositionTenue then
            ent:SetPos(cube.PositionTenue)
            ent:SetVelocity(vector_origin)
            if ent:IsNPC() then ent:StopMoving() end
        end
    end

    local function Liberer(ent)
        if not IsValid(ent) then return end
        -- un autre cube tient encore la cible : on la laisse immobilisée
        for _, cube in ipairs(ents.FindByClass("jinton_cube")) do
            if cube.Actif and cube:GetCible() == ent then return end
        end
        -- un autre étourdissement est encore en cours (sv_etourdissement.lua)
        if NA_EstEtourdi and NA_EstEtourdi(ent) then return end

        if ent:IsPlayer() then
            ent:Freeze(false)
            ent:SetNW2Bool("NA_Etourdi", false)
            if ent:GetMoveType() == MOVETYPE_NONE then ent:SetMoveType(MOVETYPE_WALK) end
        end
    end

    function ENT:Initialize()
        self:SetModel(self.Model)
        self:SetModelScale(self.Echelle, 0)
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_NONE)
        self:DrawShadow(false)

        self:SetFin(CurTime() + self.Duree)
        self.ProchainTick = CurTime() + 0.1
        self.Actif = true

        local cible = self:GetCible()
        if IsValid(cible) then
            self:SetPos(cible:WorldSpaceCenter())
            Immobiliser(cible, self)
        end

        self:EmitSound(self.SonDebut, 80, 100)
    end

    function ENT:Tick(cible)
        local centre = cible:WorldSpaceCenter()
        ParticleEffect(self.FX, centre, Angle(0, 0, 0))
        self:EmitSound(self.SonTick, 75, math.random(96, 104))

        local owner = self:GetOwner()
        local dmg = DamageInfo()
        dmg:SetDamage(self.Degats)
        dmg:SetAttacker(IsValid(owner) and owner or self)
        dmg:SetInflictor(self)
        dmg:SetDamageType(self.TypeDegats)
        dmg:SetDamagePosition(centre)
        cible:TakeDamageInfo(dmg)
    end

    function ENT:Think()
        local now = CurTime()
        local cible = self:GetCible()

        local vivante = IsValid(cible)
        if vivante then
            if cible:IsPlayer() then vivante = cible:Alive()
            elseif cible:IsNPC() then vivante = cible:GetNPCState() ~= NPC_STATE_DEAD
            else vivante = cible:Health() > 0 end
        end
        if not vivante or now >= self:GetFin() then
            self:Remove()
            return
        end

        -- le cube maintient sa cible en place et reste sur elle
        Maintenir(cible, self)
        self:SetPos(cible:WorldSpaceCenter())

        if now >= self.ProchainTick then
            self.ProchainTick = now + self.Intervalle
            self:Tick(cible)
        end

        self:NextThink(now + 0.05)
        return true
    end

    function ENT:OnRemove()
        self.Actif = false
        Liberer(self:GetCible())
    end

    -- la cible meurt ou se déconnecte : on la libère tout de suite
    hook.Add("PlayerDeath", "JintonCube_Mort", function(ply)
        for _, cube in ipairs(ents.FindByClass("jinton_cube")) do
            if cube:GetCible() == ply then cube:Remove() end
        end
        ply:Freeze(false)
        ply:SetNW2Bool("NA_Etourdi", false)
    end)
end

if CLIENT then
    function ENT:Initialize()
        self:SetRenderBounds(Vector(-48, -48, -48), Vector(48, 48, 48))
    end

    function ENT:Draw()
        -- léger rebond à l'apparition
        local age = CurTime() - (self.NA_Debut or CurTime())
        self.NA_Debut = self.NA_Debut or CurTime()
        local s = math.min(age / 0.15, 1)
        local m = Matrix()
        m:Scale(Vector(1, 1, 1) * (0.6 + 0.4 * s))
        self:EnableMatrix("RenderMultiply", m)
        self:DrawModel()
    end
end
