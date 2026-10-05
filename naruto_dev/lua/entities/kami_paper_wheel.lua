--========================================================
-- Roue de papier (entité, SERVEUR + CLIENT)
-- Roule au sol dans une direction fixe, suit le relief, s'arrête contre un
-- mur et blesse ceux qu'elle écrase. La particule kami_03_solve_geams_bone
-- (solve_kami_geams.pcf) est attachée à la roue : elle projette du papier
-- depuis la surface du modèle.
--
-- Créée deux par deux par la technique (sv_kami_roue.lua).
--========================================================

AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "base_anim"
ENT.PrintName = "Roue de papier"
ENT.Spawnable = false

ENT.Model     = "models/clan/ame/kami/roue_kami_geams.mdl"
ENT.FX_NOM    = "kami_03_solve_geams_bone"

--[[
    Géométrie du modèle (mesurée dans le .mdl) : une roue de ~145 u de diamètre
    et ~61 u de large ; l'axe de la roue est l'axe X du modèle, l'origine est
    au centre. Elle roule donc le long de son axe +Y (la GAUCHE du modèle).
]]
ENT.RayonBase = 71.5
ENT.Largeur = 0.8   -- largeur sur l'axe X ; le diamètre reste inchangé
-- Centre au niveau du sol : la moitié inférieure de la roue
-- reste enterrée, à l'aller comme au retour.
ENT.HauteurSolFraction = 0

-- Valeurs par défaut ; la technique les remplace au lancement (sv_kami_roue.lua)
ENT.Direction    = Vector(1, 0, 0)
ENT.Decalage     = Vector(0, 0, 0)   -- écart latéral par rapport au lanceur, gardé au retour
ENT.Vitesse      = 650
ENT.DureeVie     = 1.6     -- secondes d'ALLER ; ensuite la roue revient vers le lanceur
ENT.DureeRetour  = 4       -- secondes maximum pour revenir
ENT.Echelle      = 1
ENT.Degats       = 30
ENT.Intervalle   = 0.6     -- secondes avant de pouvoir blesser de nouveau la même cible
ENT.Poussee      = 350
ENT.Soulevement  = 200

--[[
    Debug : "kami_roue_debug 1" dans la console (ou "developer 1") affiche
      - l'UNIQUE hitbox commune aux deux roues (cyan) et ses couloirs de traces (jaune),
      - les hitbox des joueurs / PNJ proches (rouge = tête, vert = corps),
      - les points de contact (magenta, 4 s).
]]
local cvDebug = CreateConVar("kami_roue_debug", "0", { FCVAR_REPLICATED, FCVAR_ARCHIVE },
    "Affiche les hitbox de la Roue de papier (0/1)")
local cvDeveloper = GetConVar("developer")

local function DebugActif()
    return cvDebug:GetBool() or (cvDeveloper and cvDeveloper:GetInt() > 0)
end

function ENT:SetupDataTables()
    self:NetworkVar("Float", 0, "Rayon")   -- rayon réel, échelle comprise
    self:NetworkVar("Entity", 0, "Partenaire")   -- l'autre roue de la paire
end

local COINS = {}
for _, x in ipairs({ 0, 1 }) do
    for _, y in ipairs({ 0, 1 }) do
        for _, z in ipairs({ 0, 1 }) do COINS[#COINS + 1] = Vector(x, y, z) end
    end
end

-- points d'une boîte (coins + centre), en repère local
local function PointsBoite(mins, maxs)
    local pts = { (mins + maxs) * 0.5 }
    for _, c in ipairs(COINS) do
        pts[#pts + 1] = Vector(
            Lerp(c.x, mins.x, maxs.x), Lerp(c.y, mins.y, maxs.y), Lerp(c.z, mins.z, maxs.z))
    end
    return pts
end

local function Dans(p, mins, maxs)
    return p.x >= mins.x and p.x <= maxs.x
        and p.y >= mins.y and p.y <= maxs.y
        and p.z >= mins.z and p.z <= maxs.z
end


--[[
    UNE SEULE hitbox pour les DEUX roues : la boîte qui englobe les deux (et
    l'espace entre elles), exprimée dans le repère de cette roue. Une seule roue
    de la paire s'en sert pour les dégâts (la plus ancienne encore là : voir
    EstChef) ; si l'autre disparaît, la boîte se réduit à la roue restante.
]]
local function BoiteRoue(ent)
    local mins, maxs = ent:GetHitBoxBounds(0, 0)
    if not mins then mins, maxs = Vector(-30.7, -73.4, -72.7), Vector(30.5, 71.9, 70.2) end
    local e = ent:GetModelScale()
    return Vector(mins.x * ent.Largeur, mins.y, mins.z) * e,
        Vector(maxs.x * ent.Largeur, maxs.y, maxs.z) * e
end

function ENT:EstChef()
    local autre = self:GetPartenaire()
    return not (IsValid(autre) and autre:EntIndex() < self:EntIndex())
end

function ENT:BoiteGroupe()
    local mins, maxs = BoiteRoue(self)
    local autre = self:GetPartenaire()
    if IsValid(autre) then
        local amins, amaxs = BoiteRoue(autre)
        for _, pt in ipairs(PointsBoite(amins, amaxs)) do
            local monde = LocalToWorld(pt, Angle(), autre:GetPos(), autre:GetAngles())
            local p = WorldToLocal(monde, Angle(), self:GetPos(), self:GetAngles())
            mins = Vector(math.min(mins.x, p.x), math.min(mins.y, p.y), math.min(mins.z, p.z))
            maxs = Vector(math.max(maxs.x, p.x), math.max(maxs.y, p.y), math.max(maxs.z, p.z))
        end
    end
    return mins, maxs
end

-- Ce que la roue traverse : les vivants (ils sont blessés, pas bloquants) et les autres roues
local function Traversable(ent)
    return not (ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot() or ent:GetClass() == "kami_paper_wheel")
end

if SERVER then
    function ENT:Initialize()
        self:SetModel(self.Model)
        self:SetModelScale(self.Echelle, 0)
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_NONE)
        self:SetRayon(self.RayonBase * self.Echelle)

        -- l'axe de la roue (X du modèle) est perpendiculaire à la direction : Y modèle = direction
        self:SetAngles(Angle(0, self.Direction:Angle().y - 90, 0))

        self.Touches = self.Touches or {}      -- partagé entre les deux roues (voir technique)
        self.MortA = CurTime() + self.DureeVie
        self.Retour = false
        self.Dernier = CurTime()
    end

    util.AddNetworkString("kami_roue_dbg")

    -- Particule d'impact au sol (jouée par les clients : cl_kami_roue.lua)
    local function ImpactSol(pos)
        net.Start("kami_roue_impact")
            net.WriteVector(pos)
        net.Broadcast()
    end

    local function EstCible(ent, lanceur)
        if not IsValid(ent) or ent == lanceur then return false end
        if ent:IsPlayer() then return ent:Alive() end
        if ent:IsNPC() or ent:IsNextBot() then return ent:Health() > 0 end
        return false
    end

    --[[
        Touche par HITBOX, de deux façons complémentaires :

        1) VOLUME contre VOLUME : la hitbox du modèle de la roue (boîte orientée,
           mise à l'échelle) est comparée à CHAQUE hitbox du joueur / PNJ (bras,
           jambes, torse, tête...). Il y a contact dès qu'un coin de l'une est
           dans l'autre.
        2) TRACES : des traces MASK_SHOT quadrillent la roue sur le trajet du tick
           (utile à grande vitesse, quand la roue traverse une hitbox fine en un
           seul tick). Un mur ou un objet coupe la trace.
    ]]
    -- Premier point de contact entre la hitbox de la roue et celles de la cible
    function ENT:ContactHitbox(ent, roueMins, roueMaxs, roueAng)
        local rouePos = self:GetPos()
        local set = ent:GetHitboxSet() or 0
        for i = 0, (ent:GetHitBoxCount(set) or 0) - 1 do
            local os = ent:GetHitBoxBone(i, set)
            local mins, maxs = ent:GetHitBoxBounds(i, set)
            -- GetBonePosition (partagé) : SetupBones / GetBoneMatrix n'existent que côté client
            local pos, ang
            if os and mins then pos, ang = ent:GetBonePosition(os) end
            if pos then

                -- coins de la hitbox de la cible dans la roue
                for _, pt in ipairs(PointsBoite(mins, maxs)) do
                    local monde = LocalToWorld(pt, Angle(), pos, ang)
                    if Dans(WorldToLocal(monde, Angle(), rouePos, roueAng), roueMins, roueMaxs) then
                        return monde
                    end
                end

                -- coins de la roue dans la hitbox de la cible
                for _, pt in ipairs(PointsBoite(roueMins, roueMaxs)) do
                    local monde = LocalToWorld(pt, Angle(), rouePos, roueAng)
                    if Dans(WorldToLocal(monde, Angle(), pos, ang), mins, maxs) then
                        return monde
                    end
                end
            end
        end
    end

    -- Dégâts + projection + impact (une fois par cible et par intervalle)
    function ENT:Toucher(ent, lanceur, ou)
        local now = CurTime()
        if (self.Touches[ent] or 0) > now then return end
        self.Touches[ent] = now + self.Intervalle

        local dmg = DamageInfo()
        dmg:SetDamage(self.Degats)
        dmg:SetAttacker(IsValid(lanceur) and lanceur or self)
        dmg:SetInflictor(self)
        dmg:SetDamageType(DMG_CLUB)
        dmg:SetDamagePosition(ou)
        ent:TakeDamageInfo(dmg)

        if DebugActif() then   -- point de contact affiché chez les clients
            net.Start("kami_roue_dbg")
                net.WriteVector(ou)
            net.Broadcast()
        end

        ImpactSol(ent:GetPos())   -- au pied de la cible touchée

        -- la roue envoie la cible devant elle
        ent:SetVelocity(self.Direction * self.Poussee + Vector(0, 0, self.Soulevement))
        ent:EmitSound("geams/solve_jutsu/meiton/solve_meiton_give_chakra.wav", 70, 100)
    end

    function ENT:Blesser(lanceur, depuis, vers)
        if not self:EstChef() then return end   -- la hitbox commune est gérée par l'autre roue

        local now = CurTime()
        local rayon = self:GetRayon()
        local dir = self.Direction

        -- 1) hitbox commune des deux roues contre hitbox des cibles proches
        local roueMins, roueMaxs = self:BoiteGroupe()
        local roueAng = self:GetAngles()
        for _, ent in ipairs(ents.FindInSphere(vers, roueMaxs:Distance(roueMins) * 0.5 + 150)) do
            if EstCible(ent, lanceur) and (self.Touches[ent] or 0) <= now then
                local ou = self:ContactHitbox(ent, roueMins, roueMaxs, roueAng)
                if ou then self:Toucher(ent, lanceur, ou) end
            end
        end

        -- 2) traces sur le trajet du tick : 5 couloirs sur toute la largeur du groupe x 4 en hauteur
        local axe = roueAng:Forward()          -- axe des roues = largeur du groupe
        local debut = depuis - dir * rayon
        local fin = vers + dir * rayon

        local function Bloquant(e)
            return e ~= lanceur and e:GetClass() ~= "kami_paper_wheel"
        end

        for i = 0, 4 do
            for _, h in ipairs({ -0.9, -0.3, 0.3, 0.9 }) do
                local off = axe * Lerp(i / 4, roueMins.x, roueMaxs.x) + Vector(0, 0, rayon * h)
                local tr = util.TraceLine({
                    start = debut + off,
                    endpos = fin + off,
                    mask = MASK_SHOT,
                    filter = Bloquant,
                })
                if tr.Hit and EstCible(tr.Entity, lanceur) then
                    self:Toucher(tr.Entity, lanceur, tr.HitPos)
                end
            end
        end
    end

    -- Fin de l'aller : la roue repart en sens inverse, droit vers le lanceur
    function ENT:Retourner()
        self.Retour = true
        self.MortA = CurTime() + self.DureeRetour
        for k in pairs(self.Touches) do self.Touches[k] = nil end   -- elle peut re-toucher au retour
    end

    function ENT:Think()
        local now = CurTime()
        local lanceur = self:GetOwner()

        if now > self.MortA then
            if self.Retour then
                self:Remove()
            else
                self:Retourner()
            end
            self:NextThink(now)   -- sans ça, le Think ne repart pas et la roue reste figée
            return true
        end

        local dt = math.Clamp(now - self.Dernier, 0, 0.1)
        self.Dernier = now

        local rayon = self:GetRayon()
        local pos = self:GetPos()

        -- au retour : repart tout droit vers sa place à côté du lanceur (même écart qu'au départ), disparaît en l'atteignant
        if self.Retour then
            if not IsValid(lanceur) or not lanceur:Alive() then
                self:Remove()
                return
            end
            local vers = lanceur:GetPos() + self.Decalage - pos   -- revient à SA place, écartée comme au départ
            vers.z = 0
            if vers:Length() < 45 then
                self:Remove()
                return
            end
            local yaw = vers:Angle().y
            self.Direction = Angle(0, yaw, 0):Forward()
            self:SetAngles(Angle(0, yaw - 90, 0))
        end

        -- 1) avance ; un mur arrête l'aller (la roue revient) ou le retour (elle disparaît)
        local nouvelle = pos + self.Direction * self.Vitesse * dt
        local demi = rayon * 0.4
        -- La partie enterrée ne doit pas bloquer la trace contre le terrain.
        local basTrace = math.max(-rayon * 0.3, 1 - rayon * self.HauteurSolFraction)
        local tr = util.TraceHull({
            start = pos, endpos = nouvelle,
            mins = Vector(-demi, -demi, basTrace), maxs = Vector(demi, demi, math.max(basTrace + 1, rayon * 0.6)),
            mask = MASK_SOLID,
            filter = Traversable,
        })
        if tr.Hit and not tr.StartSolid then
            if self.Retour then
                self:Remove()
            else
                self:Retourner()
            end
            self:NextThink(now)
            return true
        end

        -- 2) reste collée au sol (relief) ; dans le vide, elle garde sa hauteur (elle ne tombe jamais)
        local sol = util.TraceLine({
            start = nouvelle + Vector(0, 0, rayon),
            endpos = nouvelle - Vector(0, 0, rayon * 2),
            mask = MASK_SOLID,
            filter = Traversable,
        })
        if sol.Hit and not sol.StartSolid then
            nouvelle.z = sol.HitPos.z + rayon * self.HauteurSolFraction
        else
            nouvelle.z = pos.z
        end
        self:SetPos(nouvelle)

        -- 3) dégâts (par hitbox) sur le trajet parcouru pendant ce tick
        self:Blesser(lanceur, pos, nouvelle)

        self:NextThink(now)
        return true
    end
end

if CLIENT then
    -- À la vitesse du jutsu, une rotation physique complète devient trop rapide
    -- pour être lisible. On limite seulement la rotation visuelle à deux tours/s.
    local VITESSE_ROTATION_MAX = 720

    function ENT:Initialize()
        local taille = Matrix()
        taille:Scale(Vector(self.Largeur, 1, 1))
        self:EnableMatrix("RenderMultiply", taille)
        -- PATTACH_ABSORIGIN_FOLLOW : la particule suit la roue et lit son modèle
        -- (l'initialiseur "Position on Model Random" du .pcf)
        self.Particule = CreateParticleSystem(self, self.FX_NOM, PATTACH_ABSORIGIN_FOLLOW, 0)
        self.Rotation = 0
        self.DernierePos = self:GetPos()
        self.DerniereRotation = CurTime()
    end

    function ENT:Think()
        -- Mise à jour indépendante de Draw : plusieurs passes de rendu ne doivent
        -- pas faire avancer la rotation, et les particules gardent les angles.
        local now = CurTime()
        local dt = math.max(now - (self.DerniereRotation or now), 0)
        self.DerniereRotation = now
        local pos = self:GetPos()
        local rayon = math.max(self:GetRayon(), 1)
        local parcouru = (pos - (self.DernierePos or pos)):Length2D()
        self.DernierePos = pos
        local rotation = math.min(math.deg(parcouru / rayon), VITESSE_ROTATION_MAX * dt)
        self.Rotation = ((self.Rotation or 0) - rotation) % 360

        local ang = self:GetAngles()
        ang:RotateAroundAxis(ang:Forward(), self.Rotation)   -- X modèle = axe de la roue
        self:SetRenderAngles(ang)
        self:InvalidateBoneCache()
        self:SetNextClientThink(CurTime())
        return true
    end

    function ENT:Draw()
        -- Le cache d'éclairage peut encore devenir noir quand l'origine traverse
        -- le terrain. Le papier garde sa couleur de texture pendant tout le rendu.
        -- La suppression ne concerne que cette roue, puis l'éclairage est rétabli.
        render.SuppressEngineLighting(true)
        self:DrawModel()
        render.SuppressEngineLighting(false)
    end

    function ENT:OnRemove()
        if IsValid(self.Particule) then self.Particule:StopEmission() end
        self:StopParticles()
    end

    ------------------------------------------------------
    -- DEBUG (kami_roue_debug 1 ou developer 1)
    ------------------------------------------------------
    local COL_ROUE    = Color(0, 200, 255)
    local COL_COULOIR = Color(255, 220, 0)
    local COL_TETE    = Color(255, 40, 40)
    local COL_CORPS   = Color(40, 255, 80)
    local COL_CONTACT = Color(255, 0, 255)

    local contacts = {}

    net.Receive("kami_roue_dbg", function()
        contacts[#contacts + 1] = { pos = net.ReadVector(), fin = CurTime() + 4 }
    end)

    -- hitbox réelles d'un joueur / PNJ (celles que testent la roue)
    local function DessinerHitbox(ent)
        ent:SetupBones()
        local set = ent:GetHitboxSet() or 0
        for i = 0, (ent:GetHitBoxCount(set) or 0) - 1 do
            local os = ent:GetHitBoxBone(i, set)
            local mins, maxs = ent:GetHitBoxBounds(i, set)
            local m = os and mins and ent:GetBoneMatrix(os)
            if m then
                local col = ent:GetHitBoxHitGroup(i, set) == HITGROUP_HEAD and COL_TETE or COL_CORPS
                render.DrawWireframeBox(m:GetTranslation(), m:GetAngles(), mins, maxs, col, true)
            end
        end
    end

    hook.Add("PostDrawTranslucentRenderables", "KamiRoue_Debug", function(depth, sky)
        if sky or not DebugActif() then return end

        local roues = ents.FindByClass("kami_paper_wheel")
        local moi = LocalPlayer()

        -- hitbox des cibles possibles autour de toi
        for _, ent in ipairs(ents.FindInSphere(moi:GetPos(), 1500)) do
            if (ent:IsPlayer() and ent:Alive()) or ent:IsNPC() or ent:IsNextBot() then
                if ent ~= moi or moi:ShouldDrawLocalPlayer() then DessinerHitbox(ent) end
            end
        end

        for _, roue in ipairs(roues) do
            if roue:EstChef() then   -- une seule boîte pour la paire
                local pos, ang = roue:GetPos(), roue:GetAngles()
                local rayon = roue:GetRayon()

                local mins, maxs = roue:BoiteGroupe()
                render.DrawWireframeBox(pos, ang, mins, maxs, COL_ROUE, true)

                -- couloirs de traces : direction = axe +Y du modèle (la gauche)
                local dir = -ang:Right()
                local axe = ang:Forward()
                for i = 0, 4 do
                    for _, h in ipairs({ -0.9, -0.3, 0.3, 0.9 }) do
                        local off = axe * Lerp(i / 4, mins.x, maxs.x) + Vector(0, 0, rayon * h)
                        render.DrawLine(pos - dir * rayon + off, pos + dir * (rayon + 25) + off, COL_COULOIR, true)
                    end
                end
            end
        end

        for i = #contacts, 1, -1 do
            if CurTime() > contacts[i].fin then
                table.remove(contacts, i)
            else
                render.DrawWireframeSphere(contacts[i].pos, 4, 8, 8, COL_CONTACT, true)
            end
        end
    end)
end
