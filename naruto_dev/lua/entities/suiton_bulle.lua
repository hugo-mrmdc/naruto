--========================================================
-- Bulle d'eau (entité projectile, SERVEUR + CLIENT)
--
-- Une des nombreuses bulles de la technique "Bulles" : elle avance en ligne droite et explose au
-- premier joueur / PNJ (dégâts), mur ou décor touché, ou en fin de vie (même explosion que la
-- boule d'eau : jet_eau_hit_pat, atg_particules2.pcf). Le serveur teste sa trajectoire à
-- chaque tick (TraceHull) ; l'affichage est la particule atg_bulle_eau, créée par chaque client.
--
-- Les valeurs viennent de la technique (sv_suiton_bulle.lua) au lancement.
--========================================================

AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "base_anim"
ENT.PrintName = "Bulle d'eau"
ENT.Spawnable = false

ENT.Model = "models/props_junk/PopCan01a.mdl"   -- invisible, seule la particule se voit
ENT.FX    = "atg_bulle_eau"                     -- particles/atg_particules.pcf
ENT.FX_IMPACT = "jet_eau_hit_pat"               -- particles/atg_particules2.pcf (chargé par sv_ / cl_suiton_bulle.lua)

-- Valeurs par défaut (remplacées au lancement)
ENT.Vitesse  = 550
ENT.Degats   = 8
ENT.DureeVie = 3
ENT.Rayon    = 26     -- demi-taille de la zone qui touche
ENT.Onde     = 0     -- amplitude de l'ondulation latérale (unités par seconde)
ENT.Montee   = 0      -- dérive vers le haut (unités par seconde) : la bulle flotte

if SERVER then
    local DEBUG_CVAR = CreateConVar("na_bulle_hitbox", "0", FCVAR_NONE, "1 = affiche la hitbox des bulles d'eau")

    function ENT:Initialize()
        self:SetModel(self.Model)
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_NONE)
        self:DrawShadow(false)

        self.MortA = CurTime() + self.DureeVie
        self.Dir = self.Direction or self:GetForward()
        self.Droite = self.Dir:Angle():Right()
        self.Phase = math.Rand(0, math.pi * 2)
        self.Frequence = math.Rand(3, 6)
        self.Ignorees = { self, self:GetOwner() }   -- la bulle et son lanceur ne l'arrêtent pas
    end

    local function EstVivant(ent)
        return IsValid(ent) and (ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot())
    end

    -- Une cible vivante touchée : dégâts (l'explosion suit)
    function ENT:Toucher(hit, pos)
        local owner = self:GetOwner()
        local dmg = DamageInfo()
        dmg:SetDamage(self.Degats)
        dmg:SetAttacker(IsValid(owner) and owner or self)
        dmg:SetInflictor(self)
        dmg:SetDamageType(DMG_GENERIC)
        dmg:SetDamagePosition(pos)
        hit:TakeDamageInfo(dmg)
    end

    -- Impact ou fin de vie : la bulle explose (comme la boule d'eau) et disparaît
    function ENT:Exploser(pos, normale)
        if self.Fini then return end
        self.Fini = true

        ParticleEffect(self.FX_IMPACT, pos, normale:Angle())
        self:EmitSound("naruto_sound/jutsu/senju/senju2.wav", 70, math.random(110, 140))
        self:Remove()
    end

    function ENT:Think()
        if self.Fini then return end

        local now = CurTime()
        if now > self.MortA then
            self:Exploser(self:GetPos(), Vector(0, 0, 1))   -- fin de vie : elle explose là où elle est arrivée
            return
        end

        -- avance en ondulant : direction + oscillation latérale + légère montée
        local dt = FrameTime()
        local lateral = self.Droite * math.sin(now * self.Frequence + self.Phase) * self.Onde
        local vel = self.Dir * self.Vitesse + lateral + Vector(0, 0, self.Montee)

        local from = self:GetPos()
        local to = from + vel * dt
        local r = self.Rayon

        if DEBUG_CVAR:GetBool() then   -- na_bulle_hitbox 1 : boîte de collision de la bulle (cyan = trajet, rouge = impact)
            debugoverlay.Box(from, Vector(-r, -r, -r), Vector(r, r, r), 0.15, Color(0, 200, 255, 30))
        end

        local tr = util.TraceHull({
            start = from,
            endpos = to,
            mins = Vector(-r, -r, -r),
            maxs = Vector(r, r, r),
            filter = self.Ignorees,
            mask = MASK_SHOT,
        })

        if tr.Hit then
            if DEBUG_CVAR:GetBool() then
                debugoverlay.Box(tr.HitPos, Vector(-r, -r, -r), Vector(r, r, r), 2, Color(255, 60, 60, 60))
            end
            if EstVivant(tr.Entity) then self:Toucher(tr.Entity, tr.HitPos) end
            self:SetPos(tr.HitPos)
            self:Exploser(tr.HitPos, tr.HitNormal)
            return
        end

        self:SetPos(to)
        self:NextThink(now)
        return true
    end
end

if CLIENT then
    -- La particule est (re)créée ici plutôt qu'à l'Initialize : plus fiable, et relancée si
    -- l'entité sort puis revient dans le champ du joueur.
    function ENT:Think()
        if not (self.Particule and self.Particule:IsValid()) then
            self.Particule = CreateParticleSystem(self, self.FX, PATTACH_ABSORIGIN_FOLLOW, 0)
        end
        self:SetNextClientThink(CurTime() + 0.25)
        return true
    end

    function ENT:Draw()
        -- rien : seule la particule est visible
    end

    function ENT:OnRemove()
        -- (false, true) : détruit aussi les particules déjà émises. Sans ça la bulle resterait
        -- affichée jusqu'à la fin de sa vie dans le .pcf (30 s) après la disparition de l'entité.
        if self.Particule and self.Particule:IsValid() then self.Particule:StopEmission(false, true) end
        self:StopParticles()
    end
end
