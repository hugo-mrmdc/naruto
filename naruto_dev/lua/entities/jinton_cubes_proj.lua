--========================================================
-- Jinton : cube qui grandit (entité, SERVEUR + CLIENT)
--
-- Apparaît petit à l'endroit visé par le lanceur (ou à la portée max), puis GRANDIT sur place.
-- Quand il a fini de grandir, il frappe : tout joueur / PNJ dans son volume prend de gros dégâts,
-- avec l'impact au sol. Il reste un instant puis disparaît.
--
-- Les valeurs viennent de la technique (sv_jinton_cubes.lua) au lancement.
-- Le SERVEUR décide (position, dégâts, durée) ; l'animation (croissance + montée pour ne pas être dans le sol)
-- est calculée par le CLIENT à chaque image, avec de l'adoucissement : c'est ce qui la rend fluide.
--========================================================

AddCSLuaFile()

ENT.Type        = "anim"
ENT.Base        = "base_anim"
ENT.PrintName   = "Cube Jinton"
ENT.Spawnable   = false
ENT.RenderGroup = RENDERGROUP_BOTH

ENT.Model     = "models/justu/jinton/cubeonokisolve.mdl"
ENT.FX        = "solve_geams_01_j"   -- particles/solve_jinton_geams.pcf, quand le cube apparaît
ENT.SonImpact = "solve_naruto_base/jutsu/jinton/damage_cube_explosion.wav"
ENT.SonDebut  = "solve_naruto_base/jutsu/jinton/damage_cube_start.wav"
ENT.SonSol    = "naruto_sound/jutsu/senju/senju1.wav"   -- impact au sol : le même son que le golem Mokuton

-- Valeurs par défaut (remplacées au lancement)
ENT.Degats       = 45
ENT.Taille       = 0.5    -- échelle au départ (1 = taille du modèle, 72 unités de côté)
ENT.TailleMax    = 3.2    -- échelle une fois grand
ENT.DureeGrossit = 0.32   -- secondes pour grandir
ENT.DemiModele   = 35.8   -- demi-côté du modèle à l'échelle 1 (cubeonokisolve.mdl)
ENT.DureeColle   = 0.7    -- secondes restant une fois grand avant de disparaître

function ENT:SetupDataTables()
    self:NetworkVar("Float", 0, "Debut")        -- CurTime() de l'apparition (0 = pas encore)
    self:NetworkVar("Float", 1, "TailleBase")   -- échelle au départ
    self:NetworkVar("Float", 2, "TailleFin")    -- échelle finale
    self:NetworkVar("Float", 3, "SolZ")         -- hauteur du sol sous le cube
    self:NetworkVar("Vector", 0, "Depart")      -- où le cube est apparu
    self:NetworkVar("Vector", 1, "Arrivee")     -- son centre une fois grand (même endroit, juste plus haut)
end

if SERVER then
    local function EstCible(ent, lanceur)
        if not IsValid(ent) or ent == lanceur then return false end
        if ent:IsPlayer() then return ent:Alive() end
        if ent:IsNPC() then return ent:GetNPCState() ~= NPC_STATE_DEAD end
        if ent:IsNextBot() then return ent:Health() > 0 end
        return false
    end

    function ENT:Initialize()
        self:SetModel(self.Model)
        self:SetModelScale(self.Taille, 0)
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_NONE)
        self:SetAngles(Angle(0, self:GetAngles().y, 0))   -- orienté comme le lanceur, ne tourne pas
        self:DrawShadow(false)

        -- il apparaît là où il a été placé, puis monte juste assez pour ne pas s'enfoncer dans le sol en grandissant
        local pos = self:GetPos()
        local sol = util.TraceLine({ start = pos, endpos = pos - Vector(0, 0, 600), mask = MASK_SOLID_BRUSHONLY })
        local solZ = sol.Hit and sol.HitPos.z or (pos.z - self.DemiModele * self.TailleMax)
        local arrivee = Vector(pos.x, pos.y, math.max(pos.z, solZ + self.DemiModele * self.TailleMax))

        self.Debut = CurTime()
        self.Fin = self.Debut + self.DureeGrossit + self.DureeColle
        self:SetTailleBase(self.Taille)
        self:SetTailleFin(self.TailleMax)
        self:SetDepart(pos)
        self:SetArrivee(arrivee)
        self:SetSolZ(solZ)
        self:SetDebut(self.Debut)
        self:SetPos(arrivee)   -- le serveur reste à la position finale

        self:EmitSound(self.SonDebut, 75, 120)
        ParticleEffectAttach(self.FX, PATTACH_ABSORIGIN_FOLLOW, self, 0)
    end

    -- Fin de la croissance : dégâts à tout ce qui est dans le cube + impact au sol
    function ENT:Frapper()
        local owner = self:GetOwner()
        local c = self:GetPos()
        local h = Vector(1, 1, 1) * (self.DemiModele * self.TailleMax)   -- volume du cube une fois grand

        for _, e in ipairs(ents.FindInBox(c - h, c + h)) do
            if EstCible(e, owner) then
                local dmg = DamageInfo()
                dmg:SetDamage(self.Degats)
                dmg:SetAttacker(IsValid(owner) and owner or self)
                dmg:SetInflictor(self)
                dmg:SetDamageType(DMG_GENERIC)
                dmg:SetDamagePosition(e:WorldSpaceCenter())
                e:TakeDamageInfo(dmg)
            end
        end

        self:EmitSound(self.SonImpact, 80, 110)

        -- impact au sol, sous le cube
        local tr = util.TraceLine({ start = c, endpos = c - Vector(0, 0, 400), mask = MASK_SOLID_BRUSHONLY })
        if tr.Hit then
            net.Start("jinton_cubes_sol")
                net.WriteVector(tr.HitPos)
            net.Broadcast()
            sound.Play(self.SonSol, tr.HitPos, 85, 80, 1)
        end
    end

    function ENT:Think()
        local now = CurTime()
        local owner = self:GetOwner()
        if not IsValid(owner) or now > self.Fin then self:Remove() return end

        if not self.Frappe and now - self.Debut >= self.DureeGrossit then
            self.Frappe = true
            self:Frapper()
        end

        self:NextThink(CurTime())
        return true
    end
end

if CLIENT then
    function ENT:Initialize()
        self:SetRenderBounds(Vector(-300, -300, -300), Vector(300, 300, 300))
    end

    -- adoucissements : démarrage vif puis arrêt en douceur ; léger dépassement à la fin de la croissance
    local function SortieDouce(k) return 1 - (1 - k) ^ 3 end
    local function SortieRebond(k)
        local c1, c3 = 1.4, 2.4
        return 1 + c3 * (k - 1) ^ 3 + c1 * (k - 1) ^ 2
    end

    function ENT:Draw()
        local debut = self:GetDebut()
        if debut > 0 then
            local base, fin = self:GetTailleBase(), self:GetTailleFin()
            local t = CurTime() - debut
            -- grandit sur place ; ne monte que pour rester au-dessus du sol
            local k = math.Clamp(t / self.DureeGrossit, 0, 1)
            local pos = LerpVector(SortieDouce(k), self:GetDepart(), self:GetArrivee())
            local echelle = base + (fin - base) * SortieRebond(k)
            local bas = self:GetSolZ() + self.DemiModele * echelle   -- jamais dans le sol
            if pos.z < bas then pos.z = bas end
            self:SetRenderOrigin(pos)
            local m = Matrix()
            m:Scale(Vector(1, 1, 1) * (echelle / base))   -- l'échelle du modèle est déjà "base"
            self:EnableMatrix("RenderMultiply", m)
        else
            self:SetRenderOrigin(nil)
            self:DisableMatrix("RenderMultiply")
        end
        self:DrawModel()
    end
end
