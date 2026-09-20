--========================================================
-- Kaguya : épée d'os qui sort du sol (entité, SERVEUR + CLIENT)
--
-- Elle jaillit du sol, blesse ce qui est autour d'elle, reste plantée un moment,
-- puis s'enfonce et disparaît. Créée en série (une vague) par sv_kaguya_danse.lua.
--
-- Le modèle kim_sword est particulier : son maillage est loin de son point
-- d'origine et sa lame est en diagonale. Tout est donc calculé à la création :
-- l'entité reçoit l'orientation qui met la lame à la verticale, et la position
-- qui pose sa base sur le sol. Ensuite, elle ne fait que monter puis descendre.
--========================================================

AddCSLuaFile()

ENT.Type        = "anim"
ENT.Base        = "base_anim"
ENT.PrintName   = "Épée d'os"
ENT.Spawnable   = false
ENT.RenderGroup = RENDERGROUP_OPAQUE

ENT.Modele  = "models/clan/ame/kaguya/kim_sword.mdl"
-- Mesurés sur les sommets du modèle
ENT.MilieuMaillage = Vector(-32.6, -27.2, 35.3)    -- milieu du maillage
-- du manche vers la POINTE : la pointe du maillage est du côté -Y (mesuré),
-- c'est pour ça que les lames sortaient à l'envers
ENT.AxeLame        = Vector(-0.275, -0.961, -0.016)
ENT.LONGUEUR       = 75                            -- longueur de la lame

-- Correction d'orientation des lames, si elles ne sortent pas bien droites.
-- Réglage en jeu : kaguya_lame_orienter <tangage> <lacet> <roulis> [hauteur]
NA_LameCorrection = NA_LameCorrection or Angle(0, 0, 0)
NA_LameHauteur    = NA_LameHauteur or 0    -- décalage vertical en plus

ENT.SORTIE   = 0.15   -- secondes pour sortir du sol
ENT.RETRAIT  = 0.35   -- secondes pour s'enfoncer à la fin
ENT.PROFOND  = 85     -- de combien elle est enfoncée avant de sortir

-- Valeurs par défaut (remplacées au lancement)
ENT.Duree    = 1.6
ENT.Degats   = 25
ENT.Rayon    = 70
ENT.Echelle  = 1
ENT.Lacet    = 0      -- orientation autour de l'axe vertical

function ENT:SetupDataTables()
    self:NetworkVar("Float", 0, "Debut")
    self:NetworkVar("Float", 1, "DureeVie")
end

-- Hauteur de la lame au temps t : elle sort, reste, puis s'enfonce
function ENT:Hauteur(t)
    local fin = self:GetDureeVie()
    if fin <= 0 then fin = self.Duree end   -- valeur pas encore reçue du serveur
    if t < self.SORTIE then
        return -self.PROFOND * (1 - t / self.SORTIE)
    elseif t > fin - self.RETRAIT then
        return -self.PROFOND * math.Clamp((t - (fin - self.RETRAIT)) / self.RETRAIT, 0, 1)
    end
    return 0
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
        self:SetModel(self.Modele)
        self:SetModelScale(self.Echelle, 0)
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_NONE)
        self:DrawShadow(false)

        -- 1. orientation : la lame à la verticale, tournée de Lacet
        local vertical = Matrix()
        vertical:SetAngles(Angle(-90, self.Lacet, 0))   -- l'axe X du modèle vers le haut
        local lame = Matrix()
        lame:SetAngles(self.AxeLame:Angle())
        lame:Invert()
        vertical:Mul(lame)
        local ang = vertical:GetAngles()
        self:SetAngles(ang)

        -- 2. position : le maillage est loin du point d'origine, on place donc
        -- l'entité pour que le milieu de la lame soit à mi-hauteur au-dessus du sol
        local sol = self:GetPos()
        local decale = LocalToWorld(self.MilieuMaillage * self.Echelle, angle_zero, vector_origin, ang)
        self:SetPos(sol + Vector(0, 0, self.LONGUEUR * self.Echelle / 2) - decale)

        self:SetDebut(CurTime())
        self:SetDureeVie(self.Duree)
        self:EmitSound("physics/body/body_medium_break" .. math.random(2, 3) .. ".wav", 80, math.random(90, 110), 0.8)

        -- dégâts une seule fois, quand la lame est sortie
        local centre = sol + Vector(0, 0, 40)
        timer.Simple(self.SORTIE, function()
            if not IsValid(self) then return end
            local owner = self:GetOwner()

            for _, ent in ipairs(ents.FindInSphere(centre, self.Rayon)) do
                if not EstCible(ent, owner) then continue end

                local dmg = DamageInfo()
                dmg:SetDamage(self.Degats)
                dmg:SetAttacker(IsValid(owner) and owner or self)
                dmg:SetInflictor(self)
                dmg:SetDamageType(DMG_SLASH)
                dmg:SetDamagePosition(ent:WorldSpaceCenter())
                ent:TakeDamageInfo(dmg)

                if ent:IsPlayer() then ent:SetVelocity(Vector(0, 0, 180)) end
            end

            if GetConVar("developer"):GetInt() > 0 then
                debugoverlay.Sphere(centre, self.Rayon, 1, Color(255, 240, 210, 25), true)
            end
        end)

        timer.Simple(self.Duree, function()
            if IsValid(self) then self:Remove() end
        end)
    end
end

if CLIENT then
    -- La lame est dessinée par un modèle à nous, mis à jour à chaque image, et
    -- pas par le rendu de l'entité : il ne se déclenchait pas (rien ne sortait
    -- du sol alors que les repères de debug, eux, s'affichaient).
    function ENT:Initialize()
        self:SetRenderBounds(Vector(-200, -200, -200), Vector(200, 200, 200))
        self.Apparition = CurTime()   -- le client compte le temps lui-même

        self.Lame = ClientsideModel(self.Modele, RENDERGROUP_OPAQUE)
        if IsValid(self.Lame) then
            self.Lame:SetNoDraw(true)
            self.Lame:SetModelScale(self.Echelle, 0)
        end

        if GetConVar("developer"):GetInt() > 0 then
            MsgC(Color(150, 220, 150), "[Danse des os] lame créée à " .. tostring(self:GetPos())
                .. (IsValid(self.Lame) and " (modele ok)\n" or " (MODELE INTROUVABLE)\n"))
        end
    end

    function ENT:Draw() end   -- rien : tout est dessiné ci-dessous

    hook.Add("PostDrawOpaqueRenderables", "NA_DanseOs_Lames", function(profondeur, ciel)
        if ciel then return end

        for _, e in ipairs(ents.FindByClass("kaguya_os_pointe")) do
            local m = e.Lame
            if not IsValid(m) then continue end

            local t = CurTime() - (e.Apparition or CurTime())
            m:SetPos(e:GetPos() + Vector(0, 0, e:Hauteur(t) + NA_LameHauteur))

            local ang = Angle(e:GetAngles())
            local c = NA_LameCorrection
            ang:RotateAroundAxis(ang:Right(), c.p)
            ang:RotateAroundAxis(ang:Up(), c.y)
            ang:RotateAroundAxis(ang:Forward(), c.r)
            m:SetAngles(ang)

            -- éclairage pris à hauteur de la lame : au ras du sol, le jeu
            -- échantillonne l'intérieur du décor et la lame ressort toute noire
            render.SetLightingOrigin(e:GetPos() + Vector(0, 0, 40))
            m:DrawModel()
            render.SetLightingOrigin(vector_origin)
        end
    end)

    function ENT:OnRemove()
        if IsValid(self.Lame) then self.Lame:Remove() end
    end
end

if CLIENT then
    -- Réglage en direct : kaguya_lame_orienter <tangage> <lacet> <roulis> [hauteur]
    concommand.Add("kaguya_lame_orienter", function(_, _, args)
        local p2, y2, r2, h = tonumber(args[1]), tonumber(args[2]), tonumber(args[3]), tonumber(args[4])
        NA_LameCorrection = Angle(p2 or NA_LameCorrection.p, y2 or NA_LameCorrection.y, r2 or NA_LameCorrection.r)
        NA_LameHauteur = h or NA_LameHauteur
        local c = NA_LameCorrection
        MsgC(Color(120, 220, 120), string.format(
            "[Danse des os] correction = Angle(%g, %g, %g) | hauteur = %g", c.p, c.y, c.r, NA_LameHauteur), "\n")
    end, nil, "Oriente les lames : tangage lacet roulis [hauteur]")
end
