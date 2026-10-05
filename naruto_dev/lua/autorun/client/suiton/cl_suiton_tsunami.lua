--========================================================
-- Suiton : Tsunami (CLIENT)
-- Lancement depuis la barre de techniques, et affichage de la vague (modèle tsunami_solve_custom) sous tous les
-- joueurs dont NW2Float "NA_TsunamiFin" est dans le futur (posé par sv_suiton_tsunami.lua) : tout le monde la voit.
-- La vague est un modèle côté client collé à la position du joueur (prédite : pas de retard), tourné dans la direction
-- où il regarde.
--========================================================

--========================================================
-- RÉGLAGES
--========================================================
local MODELE       = "models/nature/suiton/tsunami_solve_custom.mdl"
local ECHELLE      = NA_Tsunami and NA_Tsunami.Echelle or 1.5   -- défini dans sh_suiton_tsunami.lua (crête = hauteur du joueur)
local DECALAGE_YAW = 0               -- orientation d'origine, qui était bonne. Si la vague est de travers : essayer 90, -90 ou 180
--========================================================

NA_Cast = NA_Cast or {}
NA_Cast.suiton_tsunami = function()
    net.Start("suiton_tsunami_cast")
    net.SendToServer()
end

util.PrecacheModel(MODELE)   -- chargé au démarrage : pas de micro freeze à la première vague

local vagues = {}   -- joueur -> modèle client

local function Arreter(ply)
    if IsValid(vagues[ply]) then vagues[ply]:Remove() end
    vagues[ply] = nil
end

-- Éclairage fixe : la lumière d'un modèle est lue à son ORIGINE. Quand la vague passe dans le sol ou un mur (elle est
-- grande et posée sur le sol), son origine se retrouve dans la géométrie et le modèle devient NOIR. On impose donc une
-- lumière fixe et claire (même méthode que le dragon Bakuton).
local function Dessiner(self)
    render.SuppressEngineLighting(true)
    render.ResetModelLighting(0.9, 0.9, 0.9)
    render.SetModelLighting(BOX_TOP, 1, 1, 1)
    self:DrawModel()
    render.SuppressEngineLighting(false)
end

local function Creer()
    local ent = ClientsideModel(MODELE, RENDERGROUP_TRANSLUCENT)
    if not IsValid(ent) then return end
    ent:SetModelScale(ECHELLE, 0)
    ent.RenderOverride = Dessiner
    return ent
end

-- une fois par image, avant le dessin : position et cap à jour
hook.Add("PreRender", "NA_SuitonTsunami", function()
    local now = CurTime()
    for _, ply in ipairs(player.GetAll()) do
        local actif = ply:Alive() and not ply:IsDormant() and ply:GetNW2Float("NA_TsunamiFin", 0) > now
        if actif then
            local ent = vagues[ply]
            if not IsValid(ent) then
                ent = Creer()
                vagues[ply] = ent
            end
            if IsValid(ent) then
                local ang = Angle(0, ply:EyeAngles().y + DECALAGE_YAW, 0)
                -- la vague est posée SUR LE SOL, sous le joueur (même quand il saute : elle reste au sol)
                local pos = ply:GetPos()
                local sol = util.TraceLine({
                    start = pos + Vector(0, 0, 10), endpos = pos - Vector(0, 0, 500), mask = MASK_SOLID_BRUSHONLY,
                })
                if sol.Hit then pos = sol.HitPos end
                ent:SetPos(pos)
                ent:SetAngles(ang)
            end
        elseif vagues[ply] then
            Arreter(ply)
        end
    end
    for ply in pairs(vagues) do
        if not IsValid(ply) then Arreter(ply) end   -- joueur parti
    end
end)

----------------------------------------------------------
-- Animation du joueur sur la vague : la MÊME que sur le dragon d'encre (cl_inkuton_dragon.lua), la pose de mudra
-- "nrp_lobby_shikamaru_etc_team_type1_wait_loop". Ces hooks tournent pour TOUS les joueurs à chaque image : le test
-- vient en premier, donc un joueur qui n'est pas sur la vague sort tout de suite. (L'index de la séquence n'est pas
-- mis en cache : wOS DynaBase peut le changer.)
----------------------------------------------------------
local SEQ_POSE = "nrp_lobby_shikamaru_etc_team_type1_wait_loop"

local function SurLaVague(ply)
    return ply:GetNW2Float("NA_TsunamiFin", 0) > CurTime() and ply:Alive()
end

hook.Add("CalcMainActivity", "NA_SuitonTsunami_Pose", function(ply)
    if not SurLaVague(ply) then return end
    local seq = ply:LookupSequence(SEQ_POSE)
    if seq and seq >= 0 then return ACT_INVALID, seq end
    return ACT_HL2MP_IDLE, -1
end)

hook.Add("UpdateAnimation", "NA_SuitonTsunami_Pose_Update", function(ply)
    if not SurLaVague(ply) then return end
    local seq = ply:LookupSequence(SEQ_POSE)
    if seq and seq >= 0 then
        if ply:GetSequence() ~= seq then
            ply:SetSequence(seq)
            ply:SetCycle(0)
        end
        ply:SetPlaybackRate(1)
    end
    return true
end)
