--========================================================
-- Jinton : cage de cube (entité, SERVEUR + CLIENT)
--
-- Un grand cube (cubeonoki2.mdl) posé là où le lanceur regarde. Il ne stun personne : c'est une BOÎTE.
--   * ceux qui sont DANS le cube quand il apparaît (les "captifs") ne peuvent plus en sortir, et prennent des
--     dégâts à chaque tick ;
--   * personne d'autre ne peut y entrer ;
--   * aucun jutsu lancé depuis l'EXTÉRIEUR du cube ne fait de dégâts à ceux qui sont dedans ;
--   * le lanceur entre et sort comme il veut, n'est pas blessé par le cube, et dans le cube il a une
--     résistance (Resistance, en % de dégâts subis en moins).
-- Les captifs bougent librement à l'intérieur : seuls les bords du cube les arrêtent.
-- Les valeurs viennent de la technique (sv_jinton_cage.lua).
--
-- Joueurs : la limite est appliquée dans le hook FinishMove (SERVEUR ET CLIENT, donc prédite : aucun à-coup).
-- PNJ / NextBots : repositionnés à chaque tick par le serveur.
--========================================================

AddCSLuaFile()

ENT.Type        = "anim"
ENT.Base        = "base_anim"
ENT.PrintName   = "Cage Jinton"
ENT.Spawnable   = false
ENT.RenderGroup = RENDERGROUP_BOTH

ENT.Model     = "models/justu/jinton/cubeonoki2.mdl"
ENT.FX        = "solve_geams_01_j"   -- particles/solve_jinton_geams.pcf, sur chaque captif à chaque tick
ENT.SonDebut  = "solve_naruto_base/jutsu/jinton/damage_cube_start.wav"
ENT.SonTick   = "solve_naruto_base/jutsu/jinton/damage_cube_explosion.wav"

-- Valeurs par défaut (remplacées au lancement)
ENT.Duree      = 4      -- secondes
ENT.Degats     = 25     -- dégâts par tick et par captif
ENT.Intervalle = 0.5    -- secondes entre deux ticks de dégâts
ENT.Echelle    = 6      -- échelle du cube (1 = 72 unités de côté ; 6 = 430)
ENT.Resistance = 50     -- % de dégâts en moins pour le lanceur tant qu'il est DANS le cube
ENT.DemiModele = 35.8   -- demi-côté du modèle à l'échelle 1 (cubeonoki2.mdl)
ENT.DureeApparition = 0.2   -- secondes pour que le cube grossisse à son arrivée

function ENT:SetupDataTables()
    self:NetworkVar("Float", 0, "Debut")   -- CurTime() de l'apparition
    self:NetworkVar("Float", 1, "Demi")    -- demi-côté du cube, en unités (lu par le client pour les limites)
end

--========================================================
-- Limites de la boîte (partagé)
--========================================================
-- Appliquée à un déplacement (origine + vitesse). Retourne la nouvelle origine et vitesse, ou nil si rien ne change.
--   captif = true  : doit rester DANS le cube (tout son corps, d'après sa boîte de collision)
--   captif = false : ne doit pas ENTRER dans le cube (repoussé vers la face la plus proche, sur les côtés)
function ENT:Contraindre(ent, org, vel, captif)
    local c, h = self:GetPos(), self:GetDemi()
    if h <= 0 then return nil end
    local mins, maxs = ent:OBBMins(), ent:OBBMaxs()
    local o, v = Vector(org), Vector(vel)
    local change = false

    if captif then
        local bornes = {
            { "x", c.x - h - mins.x, c.x + h - maxs.x },
            { "y", c.y - h - mins.y, c.y + h - maxs.y },
            { "z", c.z - h - mins.z, c.z + h - maxs.z },
        }
        for _, b in ipairs(bornes) do
            local k = b[1]
            if o[k] < b[2] then o[k] = b[2] if v[k] < 0 then v[k] = 0 end change = true
            elseif o[k] > b[3] then o[k] = b[3] if v[k] > 0 then v[k] = 0 end change = true end
        end
    else
        -- dans le cube élargi de sa propre boîte ? (z inclus : debout à côté du cube = dedans en z)
        local x0, x1 = c.x - h - maxs.x, c.x + h - mins.x
        local y0, y1 = c.y - h - maxs.y, c.y + h - mins.y
        local z0, z1 = c.z - h - maxs.z, c.z + h - mins.z
        if o.x > x0 and o.x < x1 and o.y > y0 and o.y < y1 and o.z > z0 and o.z < z1 then
            -- face la plus proche (sur les côtés)
            local d = { o.x - x0, x1 - o.x, o.y - y0, y1 - o.y }
            local mini, idx = d[1], 1
            for i = 2, 4 do if d[i] < mini then mini, idx = d[i], i end end
            if idx == 1 then o.x = x0 if v.x > 0 then v.x = 0 end
            elseif idx == 2 then o.x = x1 if v.x < 0 then v.x = 0 end
            elseif idx == 3 then o.y = y0 if v.y > 0 then v.y = 0 end
            else o.y = y1 if v.y < 0 then v.y = 0 end end
            change = true
        end
    end

    if change then return o, v end
    return nil
end

-- Cages actives (les deux côtés) : le hook de déplacement ne parcourt que cette liste
local cages = {}

hook.Add("FinishMove", "NA_JintonCage", function(ply, mv)
    if next(cages) == nil or ply:GetMoveType() == MOVETYPE_NOCLIP then return end
    for cage in pairs(cages) do
        if not IsValid(cage) then cages[cage] = nil continue end
        if cage:GetOwner() == ply then continue end   -- le lanceur passe librement
        local captif = ply:GetNW2Entity("NA_JintonCage") == cage
        local o, v = cage:Contraindre(ply, mv:GetOrigin(), mv:GetVelocity(), captif)
        if o then
            mv:SetOrigin(o)
            mv:SetVelocity(v)
        end
    end
end)

function ENT:OnRemove()
    cages[self] = nil
    if SERVER then
        for ent in pairs(self.Captifs or {}) do
            if IsValid(ent) and ent:IsPlayer() and ent:GetNW2Entity("NA_JintonCage") == self then
                ent:SetNW2Entity("NA_JintonCage", NULL)
            end
        end
    end
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
        self:SetModelScale(self.Echelle, 0)
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_NONE)
        self:DrawShadow(false)

        -- posé SUR le sol : le centre est à (sol + demi-côté) au minimum, le cube ne s'enfonce pas
        local pos = self:GetPos()
        local demi = self.DemiModele * self.Echelle
        local sol = util.TraceLine({ start = pos, endpos = pos - Vector(0, 0, 600), mask = MASK_SOLID_BRUSHONLY })
        local solZ = sol.Hit and sol.HitPos.z or (pos.z - demi)
        self:SetPos(Vector(pos.x, pos.y, math.max(pos.z, solZ + demi)))
        self:SetDemi(demi)

        self.Fin = CurTime() + self.Duree
        self.ProchainTick = CurTime() + 0.1
        self:SetDebut(CurTime())
        cages[self] = true
        self:EmitSound(self.SonDebut, 80, 90)

        -- captifs : ceux qui sont dans le cube à son apparition (le lanceur n'est jamais captif)
        self.Captifs = {}
        local owner = self:GetOwner()
        local c = self:GetPos()
        local h = Vector(1, 1, 1) * demi
        for _, e in ipairs(ents.FindInBox(c - h, c + h)) do
            if EstCible(e, owner) then
                self.Captifs[e] = true
                if e:IsPlayer() then e:SetNW2Entity("NA_JintonCage", self) end
            end
        end
    end

    -- Le centre de l'entité est-il dans le cube ?
    local function Dedans(cage, ent)
        local c, h = cage:GetPos(), cage:GetDemi()
        local p = ent:WorldSpaceCenter()
        return math.abs(p.x - c.x) <= h and math.abs(p.y - c.y) <= h and math.abs(p.z - c.z) <= h
    end

    -- Dégâts dans le cube :
    --   * tout ce qui est DANS le cube est protégé des jutsus lancés depuis l'EXTÉRIEUR (attaquant hors du cube) ;
    --     les dégâts du cube lui-même et ceux venant de l'intérieur (lanceur, captifs) passent normalement ;
    --   * le lanceur dans le cube subit ENT.Resistance % de dégâts en moins.
    hook.Add("EntityTakeDamage", "NA_JintonCage_Degats", function(cible, dmg)
        if next(cages) == nil then return end
        if not (cible:IsPlayer() or cible:IsNPC() or cible:IsNextBot()) then return end

        for cage in pairs(cages) do
            if IsValid(cage) and cage:GetDemi() > 0 and Dedans(cage, cible) then
                local inflicteur, attaquant = dmg:GetInflictor(), dmg:GetAttacker()

                -- attaquant hors du cube (le monde, les chutes... ne comptent pas : ce ne sont pas des jutsus)
                if inflicteur ~= cage and IsValid(attaquant) and attaquant ~= cible and attaquant ~= cage
                    and (attaquant:IsPlayer() or attaquant:IsNPC() or attaquant:IsNextBot())
                    and not Dedans(cage, attaquant) then
                    dmg:SetDamage(0)
                    return true
                end

                if cage:GetOwner() == cible then
                    dmg:ScaleDamage(1 - math.Clamp(cage.Resistance, 0, 100) / 100)
                end
                return
            end
        end
    end)

    function ENT:Tick(ent)
        local owner = self:GetOwner()
        ParticleEffect(self.FX, ent:WorldSpaceCenter(), angle_zero)

        local dmg = DamageInfo()
        dmg:SetDamage(self.Degats)
        dmg:SetAttacker(IsValid(owner) and owner or self)
        dmg:SetInflictor(self)
        dmg:SetDamageType(DMG_GENERIC)
        dmg:SetDamagePosition(ent:WorldSpaceCenter())
        ent:TakeDamageInfo(dmg)
    end

    -- Déplace un PNJ / NextBot (les joueurs sont gérés par FinishMove, avec un filet de sécurité ici)
    local function Placer(ent, o)
        ent:SetPos(o)
        if ent.loco then ent.loco:SetVelocity(vector_origin) else ent:SetVelocity(-ent:GetVelocity()) end
    end

    function ENT:Think()
        local now = CurTime()
        local owner = self:GetOwner()
        if not IsValid(owner) or now >= self.Fin then self:Remove() return end

        local c, h = self:GetPos(), self:GetDemi()
        local tick = now >= self.ProchainTick
        if tick then
            self.ProchainTick = now + self.Intervalle
            self:EmitSound(self.SonTick, 75, math.random(96, 104))
        end

        -- captifs : dégâts, et retenue des PNJ (filet de sécurité aussi pour les joueurs : téléportation, dash...)
        for e in pairs(self.Captifs) do
            if not EstCible(e, owner) then
                self.Captifs[e] = nil
            else
                if tick then self:Tick(e) end
                local o = self:Contraindre(e, e:GetPos(), vector_origin, true)
                if o and (not e:IsPlayer() or o:DistToSqr(e:GetPos()) > 24 * 24) then Placer(e, o) end
            end
        end

        -- PNJ / NextBots qui ne sont pas captifs : repoussés hors du cube
        local m = Vector(1, 1, 1) * (h + 80)
        for _, e in ipairs(ents.FindInBox(c - m, c + m)) do
            if (e:IsNPC() or e:IsNextBot()) and not self.Captifs[e] and EstCible(e, owner) then
                local o = self:Contraindre(e, e:GetPos(), vector_origin, false)
                if o then Placer(e, o) end
            end
        end

        self:NextThink(CurTime())
        return true
    end
end

if CLIENT then
    function ENT:Initialize()
        self:SetRenderBounds(Vector(-400, -400, -400), Vector(400, 400, 400))
        cages[self] = true
    end

    local function SortieDouce(k) return 1 - (1 - k) ^ 3 end

    function ENT:Draw()
        -- apparition : le cube grossit de 30 % à 100 % de sa taille
        local debut = self:GetDebut()
        local k = debut > 0 and math.Clamp((CurTime() - debut) / self.DureeApparition, 0, 1) or 1
        if k < 1 then
            local m = Matrix()
            m:Scale(Vector(1, 1, 1) * (0.3 + 0.7 * SortieDouce(k)))
            self:EnableMatrix("RenderMultiply", m)
        else
            self:DisableMatrix("RenderMultiply")
        end
        self:DrawModel()
    end
end
