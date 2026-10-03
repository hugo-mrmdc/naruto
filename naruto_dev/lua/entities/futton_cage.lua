--========================================================
-- Futton : Cage de vapeur (entité, SERVEUR + CLIENT)
-- Zone cylindrique posée là où le lanceur regarde (sv_futton_cage.lua). Particule futtontornade
-- (particles/futtontornade.pcf). Tous ceux qui sont dedans au moment de la pose ne peuvent plus en sortir ;
-- personne d'autre ne peut y entrer. Seul le lanceur passe librement.
--========================================================

AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "base_anim"
ENT.PrintName = "Cage de vapeur"
ENT.Spawnable = false

ENT.Rayon    = 300
ENT.Hauteur  = 400    -- hauteur du cylindre au-dessus du centre
ENT.DureeVie = 8
ENT.Degats   = 5    -- dégâts par tick aux ennemis piégés
ENT.Intervalle = 0.5
ENT.FX       = "futtonxornade"   -- copie agrandie de futtontornade (particles/futtontornade_grand.pcf)
ENT.DecalageFX = 100   -- unités dont la particule est descendue (sous le sol) pour la baisser sans toucher au pcf

if SERVER then
    local function EstCible(ent, owner) return NA_InkutonEstCible and NA_InkutonEstCible(ent, owner) end   -- sv_inkuton_singes.lua

    function ENT:Initialize()
        self:SetModel("models/props_junk/PopCan01a.mdl")
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_NONE)
        self:SetNoDraw(true)
        self:DrawShadow(false)
        self.MortA = CurTime() + self.DureeVie
        self.Dedans = {}   -- [ent] = true : pris au piège à la pose

        -- ceux qui sont dans la zone à la pose
        local c = self:GetPos()
        for _, ent in ipairs(ents.FindInSphere(c, self.Rayon + self.Hauteur)) do
            if EstCible(ent, self:GetOwner()) and self:DansCylindre(ent:GetPos()) then self.Dedans[ent] = true end
        end
    end

    -- distance horizontale au centre ; nil si hors de la hauteur du cylindre
    function ENT:Distance(pos)
        local c = self:GetPos()
        if pos.z < c.z - 80 or pos.z > c.z + self.Hauteur then return nil end
        return Vector(pos.x - c.x, pos.y - c.y, 0):Length()
    end

    function ENT:DansCylindre(pos)
        local d = self:Distance(pos)
        return d ~= nil and d <= self.Rayon
    end

    -- remet "ent" sur le cercle de rayon "r" (côté où il se trouve) et annule sa vitesse vers l'extérieur / l'intérieur
    local function Repousser(self, ent, r, vers_interieur)
        local c, p = self:GetPos(), ent:GetPos()
        local dir = Vector(p.x - c.x, p.y - c.y, 0)
        if dir:LengthSqr() < 1 then dir = Vector(1, 0, 0) end
        dir:Normalize()
        ent:SetPos(Vector(c.x + dir.x * r, c.y + dir.y * r, p.z))
        local v = ent:GetVelocity()
        local radiale = v:Dot(dir)
        -- piégé : on retire la part de vitesse qui sort ; dehors : celle qui entre
        if (vers_interieur and radiale > 0) or (not vers_interieur and radiale < 0) then
            local nv = v - dir * radiale
            ent:SetVelocity(ent:IsPlayer() and (nv - v) or nv)   -- joueur : SetVelocity AJOUTE ; PNJ : il remplace
        end
    end

    function ENT:Think()
        self:NextThink(CurTime())
        local owner = self:GetOwner()
        if CurTime() > self.MortA or not IsValid(owner) or (owner:IsPlayer() and not owner:Alive()) then
            self:Remove()
            return true
        end

        local marge = 25
        -- dégâts sur la durée à ceux qui sont dans la cage
        local tick = CurTime() >= (self.ProchainTick or 0)
        if tick then self.ProchainTick = CurTime() + self.Intervalle end
        for _, ent in ipairs(ents.FindInSphere(self:GetPos(), self.Rayon + self.Hauteur + 100)) do
            if EstCible(ent, owner) then
                local d = self:Distance(ent:GetPos())
                if d then
                    if tick and d <= self.Rayon then
                        local dmg = DamageInfo()
                        dmg:SetDamage(self.Degats)
                        dmg:SetAttacker(owner)
                        dmg:SetInflictor(self)
                        dmg:SetDamageType(DMG_BURN)
                        dmg:SetDamagePosition(ent:WorldSpaceCenter())
                        ent:TakeDamageInfo(dmg)
                    end
                    if self.Dedans[ent] then
                        if d > self.Rayon - marge then Repousser(self, ent, self.Rayon - marge, true) end   -- ne sort pas
                    elseif d < self.Rayon + marge then
                        Repousser(self, ent, self.Rayon + marge, false)                                      -- n'entre pas
                    end
                end
            end
        end

        if CurTime() >= (self.ProchainDebug or 0) and GetConVar("developer"):GetInt() > 0 then
            self.ProchainDebug = CurTime() + 0.1
            debugoverlay.Cross(self:GetPos(), 20, 0.1, Color(255, 120, 60), true)
            local prec
            for i = 0, 24 do
                local a = math.rad(i / 24 * 360)
                local p = self:GetPos() + Vector(math.cos(a), math.sin(a), 0) * self.Rayon
                if prec then
                    debugoverlay.Line(prec, p, 0.1, Color(255, 120, 60), true)
                    debugoverlay.Line(prec + Vector(0, 0, self.Hauteur), p + Vector(0, 0, self.Hauteur), 0.1, Color(255, 120, 60), true)
                end
                prec = p
            end
        end
        return true
    end
end

if CLIENT then
    function ENT:Think()
        if self.Fx == nil or (self.Fx and not IsValid(self.Fx)) then
            self.Fx = CreateParticleSystem(self, self.FX, PATTACH_ABSORIGIN_FOLLOW, 0, Vector(0, 0, -self.DecalageFX)) or false
        end
        self:SetNextClientThink(CurTime() + 0.5)
        return true
    end

    function ENT:Draw() end

    function ENT:OnRemove()
        if IsValid(self.Fx) then self.Fx:StopEmission() end
    end
end
