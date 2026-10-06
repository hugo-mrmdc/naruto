--========================================================
-- Faux joueur d'entraînement (entité nextbot, SERVEUR + CLIENT)
--
-- Un "joueur" immobile avec un modèle de joueur et de la vie, pour tester
-- les combos et les techniques. Il est touché par tout ce qui touche un
-- joueur : poings / armes (naruto_arme_base.lua), jutsus, étourdissement,
-- aspiration du vortex, chiffres de dégâts (sv_degats_affiches.lua).
--   - bouge un peu quand il est touché ;
--   - revient à fond s'il n'est pas frappé pendant REGEN_DELAI secondes ;
--   - à 0 PV : il tombe (ragdoll) puis réapparaît au même endroit.
--
-- Apparition / suppression : fakeplayers_spawn / fakeplayers_clear
-- (lua/autorun/server/fake_players_sv.lua)
--========================================================

AddCSLuaFile()

ENT.Base      = "base_nextbot"
ENT.Type      = "nextbot"
ENT.PrintName = "Faux joueur"
ENT.Category  = "Naruto"
ENT.Spawnable = false

--========================================================
-- RÉGLAGES
--========================================================
ENT.Modele        = "models/player/kleiner.mdl"
ENT.VieMax        = 500    -- vie du faux joueur
ENT.RegenDelai    = 4      -- secondes sans coup avant de revenir à fond (0 = jamais)
ENT.Reapparition  = 3      -- secondes avant de réapparaître après la mort
--========================================================

function ENT:SetupDataTables()
    self:NetworkVar("Int", 0, "Vie")
    self:NetworkVar("Int", 1, "VieMaxi")
end

if SERVER then
    function ENT:Initialize()
        self:SetModel(self.Modele)
        self:SetHealth(self.VieMax)
        self:SetMaxHealth(self.VieMax)
        self:SetVie(self.VieMax)
        self:SetVieMaxi(self.VieMax)
        self:SetCollisionBounds(Vector(-16, -16, 0), Vector(16, 16, 72))
        self:SetSolid(SOLID_BBOX)

        self.DernierCoup = 0
    end

    -- reste sur place, en attente ; joue l'animation d'étourdissement partagée
    -- (act_stunning) tant que le NW2Bool "NA_Etourdi" est actif (posé par
    -- NA_Etourdir, le cube Jinton, la prison aqueuse... : cf. sv_jinton_cube.lua
    -- pour que le cube le pose bien aussi sur ce nextbot).
    function ENT:RunBehaviour()
        while true do
            if self:GetNW2Bool("NA_Etourdi", false) then
                -- une technique peut imposer sa propre animation (NW2String "NA_EtourdiAnim")
                local perso = self:GetNW2String("NA_EtourdiAnim", "")
                local seq = perso ~= "" and self:LookupSequence(perso) or -1
                if seq < 0 then seq = self:LookupSequence("act_stunning") end
                if seq and seq >= 0 then
                    if self:GetSequence() ~= seq and not self.AnimStunFinie then
                        self:ResetSequence(seq)
                        self.DebutAnimStun = CurTime()
                    end
                    if not self:GetNW2Bool("NA_EtourdiUneFois", false) then
                        self.DebutAnimStun = nil
                        self:SetPlaybackRate(1)
                    end
                else
                    self:StartActivity(ACT_HL2MP_IDLE)
                end
            else
                self.AnimStunFinie = nil
                if self.DebutAnimStun then self.DebutAnimStun = nil self:SetPlaybackRate(1) end
                self:StartActivity(ACT_HL2MP_IDLE)
            end
            coroutine.wait(0.2)
        end
    end

    function ENT:OnInjured(dmg)
        self.DernierCoup = CurTime()

        -- petit sursaut quand il est touché
        local seq = self:LookupSequence("flinch_stomach_01")
        if seq and seq > 0 then self:AddGestureSequence(seq, true) end
    end

    function ENT:OnKilled(dmg)
        hook.Call("OnNPCKilled", GAMEMODE, self, dmg:GetAttacker(), dmg:GetInflictor())

        -- réapparition au même endroit, avec les mêmes réglages
        local pos, ang = self:GetPos(), self:GetAngles()
        local modele, vie = self.Modele, self.VieMax
        local delai = self.Reapparition
        local generation = NA_FauxJoueurs and NA_FauxJoueurs.Generation
        timer.Simple(delai, function()
            -- pas de réapparition si fakeplayers_clear a été lancé entre-temps
            if NA_FauxJoueurs and NA_FauxJoueurs.Creer and NA_FauxJoueurs.Generation == generation then
                NA_FauxJoueurs.Creer(pos, ang, modele, vie)
            end
        end)

        self:BecomeRagdoll(dmg)
    end

    --========================================================
    -- Projection / attraction
    -- Un nextbot freine et se recolle au sol tout seul : toute technique qui le
    -- pousse ou l'attire (ent:SetVelocity, ou ent.loco:SetVelocity) le ferait
    -- rester sur place. On lui retire donc le freinage tant qu'il est en
    -- mouvement, on le décolle du sol quand il monte, et on applique nous-mêmes
    -- un frottement au sol.
    --========================================================
    local FROTTEMENT = 6     -- frottement au sol pendant une projection (1/s)
    local VITESSE_MIN = 40   -- en dessous, il est considéré à l'arrêt

    local function Decoller(self)
        self:SetGroundEntity(NULL)
        self:SetPos(self:GetPos() + Vector(0, 0, 8))
    end

    -- Appelée par toutes les techniques (SetVelocity d'un joueur AJOUTE de la vitesse)
    function ENT:SetVelocity(v)
        if not self.loco then return end
        if v:IsZero() then
            self.loco:SetVelocity(vector_origin)
            return
        end
        if v.z > 30 then Decoller(self) end
        if not self.Freinage then self.Freinage = self.loco:GetDeceleration() end
        self.loco:SetDeceleration(0)
        self.loco:SetVelocity(self.loco:GetVelocity() + v)
    end

    function ENT:SuivreMouvement()
        if not self.loco then return end
        local v = self.loco:GetVelocity()
        local vh = Vector(v.x, v.y, 0)
        local vitesse = vh:Length()
        local enAir = not self:IsOnGround()

        -- poussé directement via loco:SetVelocity (sans passer par SetVelocity ci-dessus)
        if not self.Freinage and (vitesse > 150 or v.z > 30) then
            self.Freinage = self.loco:GetDeceleration()
            self.loco:SetDeceleration(0)
        end
        if v.z > 30 and not enAir then Decoller(self) end

        if self.Freinage then
            if vitesse < VITESSE_MIN and not enAir then
                self.loco:SetDeceleration(self.Freinage)   -- arrêté : il retrouve son freinage normal
                self.Freinage = nil
            elseif not enAir then
                local k = math.max(1 - FROTTEMENT * FrameTime(), 0)
                self.loco:SetVelocity(Vector(v.x * k, v.y * k, v.z))
            end
        end
    end

    function ENT:Think()
        self:SuivreMouvement()

        -- animation de stun "jouée une fois" : avancée à la main puis figée sur la dernière image
        if self.DebutAnimStun then
            local duree = self:SequenceDuration()
            local cycle = duree > 0 and (CurTime() - self.DebutAnimStun) / duree or 1
            if cycle >= 1 then
                -- terminée : on rend la main à l'animation normale (pas de figeage)
                self.DebutAnimStun = nil
                self.AnimStunFinie = true
                self:SetPlaybackRate(1)
                self:StartActivity(ACT_HL2MP_IDLE)
            else
                self:SetCycle(cycle)
                self:SetPlaybackRate(0)
            end
        end

        -- retour à fond après REGEN_DELAI secondes sans coup
        if self.RegenDelai > 0 and self:Health() < self.VieMax and CurTime() - self.DernierCoup > self.RegenDelai then
            self:SetHealth(self.VieMax)
        end

        -- vie envoyée aux clients (barre au-dessus de la tête)
        local vie = math.max(self:Health(), 0)
        if self:GetVie() ~= vie then self:SetVie(vie) end

        self:NextThink(CurTime())   -- chaque tick : le mouvement doit être suivi de près
        return true
    end
end

if CLIENT then
    -- nom et barre de vie au-dessus de la tête
    function ENT:Draw()
        self:DrawModel()

        local ply = LocalPlayer()
        if not IsValid(ply) or ply:GetPos():DistToSqr(self:GetPos()) > 1000 * 1000 then return end

        local pos = self:GetPos() + Vector(0, 0, self:OBBMaxs().z + 12)
        local ang = Angle(0, ply:EyeAngles().y - 90, 90)

        local maxi = math.max(self:GetVieMaxi(), 1)
        local frac = math.Clamp(self:GetVie() / maxi, 0, 1)

        cam.Start3D2D(pos, ang, 0.1)
            draw.SimpleTextOutlined("Faux joueur", "DermaLarge", 0, -30, color_white,
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, color_black)
            surface.SetDrawColor(0, 0, 0, 200)
            surface.DrawRect(-150, 0, 300, 24)
            surface.SetDrawColor(200, 40, 40, 255)
            surface.DrawRect(-148, 2, 296 * frac, 20)
            draw.SimpleTextOutlined(self:GetVie() .. " / " .. maxi, "DermaDefaultBold", 0, 12, color_white,
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
        cam.End3D2D()
    end
end
