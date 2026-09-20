--========================================================
-- Fuma : les quatre shurikens du Jugement des Quatre Lames (entité, SERVEUR + CLIENT)
--
-- Quatre shurikens apparaissent au-dessus de la cible, un de chaque côté (avant,
-- droite, arrière, gauche), tournent sur place, puis foncent sur elle l'un après
-- l'autre. Le déroulé dépend seulement du temps : le client anime les shurikens
-- tout seul, le serveur inflige les dégâts aux mêmes instants.
-- Créée par sv_fumajugement.lua.
--========================================================

AddCSLuaFile()

ENT.Type        = "anim"
ENT.Base        = "base_anim"
ENT.PrintName   = "Quatre Lames"
ENT.Spawnable   = false
ENT.RenderGroup = RENDERGROUP_OPAQUE

--========================================================
-- RÉGLAGES DE L'ANIMATION (communs serveur / client)
--========================================================
ENT.Modele      = "models/fumaSpell/orga_props_shuriken.mdl"   -- ~107 unités de large
ENT.Echelle     = 0.45
ENT.Rayon       = 85      -- distance horizontale de chaque shuriken à la cible
ENT.Hauteur     = 95      -- hauteur au-dessus du centre de la cible
ENT.Apparition  = 0.55    -- secondes de rotation sur place avant la première plongée
ENT.Ecart       = 0.12    -- secondes entre deux plongées
ENT.Plongee     = 0.18    -- durée d'une plongée
ENT.RotationVit = 1440    -- degrés / seconde de rotation des shurikens
ENT.FX_APPARITION = "smoke_orugi2"   -- particles/atg_orugi_particle.pcf, une par shuriken
ENT.SON_APPARITION = "fuma/swing1.wav"
ENT.SON_IMPACT     = "fuma/kunai_throw_2_v2.wav"
--========================================================

ENT.Degats = 20   -- remplacé au lancement

function ENT:SetupDataTables()
    self:NetworkVar("Entity", 0, "Cible")
    self:NetworkVar("Float", 0, "Debut")
end

-- Position (et avancement de la plongée) du shuriken i (1 à 4) à l'instant t
function ENT:EtatLame(i, t)
    local cible = self:GetCible()
    if not IsValid(cible) then return end
    local centre = cible:WorldSpaceCenter()

    local lacet = (i - 1) * 90
    local haut = centre + Angle(0, lacet, 0):Forward() * self.Rayon + Vector(0, 0, self.Hauteur)

    local debutPlongee = self.Apparition + (i - 1) * self.Ecart
    if t < debutPlongee then return haut, 0, centre end

    local f = math.Clamp((t - debutPlongee) / self.Plongee, 0, 1)
    return LerpVector(f * f, haut, centre), f, centre   -- accélère en plongeant
end

function ENT:DureeTotale()
    return self.Apparition + 3 * self.Ecart + self.Plongee + 0.1
end

if SERVER then
    function ENT:Initialize()
        self:SetModel("models/props_junk/PopCan01a.mdl")
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_NONE)
        self:DrawShadow(false)
        self:SetDebut(CurTime())
        self.Touches = {}

        local cible = self:GetCible()
        if IsValid(cible) then
            for i = 1, 4 do
                local pos = self:EtatLame(i, 0)
                if pos then ParticleEffect(self.FX_APPARITION, pos, angle_zero) end
            end
            cible:EmitSound(self.SON_APPARITION, 75, 90)
        end
    end

    function ENT:Think()
        local cible = self:GetCible()
        local t = CurTime() - self:GetDebut()
        if not IsValid(cible) or t > self:DureeTotale() then self:Remove() return end

        -- chaque shuriken qui arrive sur la cible inflige ses dégâts une fois
        for i = 1, 4 do
            if not self.Touches[i] then
                local _, f, centre = self:EtatLame(i, t)
                if f and f >= 1 then
                    self.Touches[i] = true
                    local owner = self:GetOwner()
                    local dmg = DamageInfo()
                    dmg:SetDamage(self.Degats)
                    dmg:SetAttacker(IsValid(owner) and owner or self)
                    dmg:SetInflictor(self)
                    dmg:SetDamageType(DMG_SLASH)
                    dmg:SetDamagePosition(centre)
                    cible:TakeDamageInfo(dmg)
                    cible:EmitSound(self.SON_IMPACT, 75, math.random(95, 110))

                    -- premier shuriken qui touche : le fil se détache
                    if NA_FumaRetirerFil then NA_FumaRetirerFil(cible) end
                end
            end
        end

        self:NextThink(CurTime())
        return true
    end
end

if CLIENT then
    function ENT:Initialize()
        self:SetRenderBounds(Vector(-300, -300, -300), Vector(300, 300, 300))
        self.Lames = {}
    end

    function ENT:Draw()
        local t = CurTime() - self:GetDebut()
        for i = 1, 4 do
            local pos, f, centre = self:EtatLame(i, t)
            local m = self.Lames[i]
            if pos and f < 1 then
                if not IsValid(m) then
                    m = ClientsideModel(self.Modele, RENDERGROUP_OPAQUE)
                    if IsValid(m) then
                        m:SetNoDraw(true)
                        m:SetModelScale(self.Echelle, 0)
                    end
                    self.Lames[i] = m
                end
                if IsValid(m) then
                    -- lame à plat quand elle tourne sur place, pointée vers la cible en plongeant
                    local ang
                    if f > 0 then
                        ang = (centre - pos):Angle()
                    else
                        ang = Angle(0, (i - 1) * 90 + 180, 0)
                    end
                    ang:RotateAroundAxis(ang:Up(), (CurTime() * self.RotationVit + i * 45) % 360)
                    m:SetPos(pos)
                    m:SetAngles(ang)
                    m:DrawModel()
                end
            elseif IsValid(m) then
                m:Remove()
                self.Lames[i] = nil
            end
        end
    end

    function ENT:OnRemove()
        for _, m in pairs(self.Lames or {}) do if IsValid(m) then m:Remove() end end
    end
end
