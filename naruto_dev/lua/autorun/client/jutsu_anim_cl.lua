-- Jutsu Animations (CLIENT)
Jutsu = Jutsu or {}
Jutsu.Anim = Jutsu.Anim or {}

-- Diagnostic : les séquences nrp_* viennent de models/player/wiltos/anim_extension_*.mdl,
-- ajoutées au modèle du joueur par wOS DynaBase. Si DynaBase ne se charge pas, elles n'existent pas.
local warned = {}
local function warnMissing(ply, seqName)
    if ply ~= LocalPlayer() or warned[seqName] then return end
    warned[seqName] = true
    local dyna = ply:LookupSequence("_dynamic_wiltos_enabled_")
    MsgC(Color(255, 80, 80), "[Jutsu] Animation introuvable sur ", ply:GetModel(), " : ", seqName, "\n")
    if not dyna or dyna < 0 then
        MsgC(Color(255, 80, 80), "[Jutsu] wOS DynaBase n'est PAS actif sur ce modèle -> tape wos_dynabase_help\n")
    else
        MsgC(Color(255, 200, 80), "[Jutsu] DynaBase est actif : l'extension qui contient cette animation n'est pas montée (menu DynaBase)\n")
    end
    RunConsoleCommand("jutsu_anim_check")
end

-- Rapport écrit dans garrysmod/data/jutsu_anim_diag.txt (lisible sans recopier la console)
local CHECK_SEQS = {
    "nrp_ninjutsu_defend_dragonflamebombs_start",
    "nrp_ninjutsu_trow_fireball_lv3",
    "nrp_base_dashstep_behind",
    "nrp_lobby_shikamaru_etc_team_type1_wait_loop",
    "ryoku_h_idle",
}

local function writeDiag(reason)
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    local lines = {}
    local function add(...) lines[#lines + 1] = table.concat({ ... }, " ") end

    add("raison:", reason, "date:", os.date("%Y-%m-%d %H:%M:%S"))
    add("gamemode:", engine.ActiveGamemode(), "map:", game.GetMap(), "version:", tostring(VERSION), tostring(BRANCH), jit.arch)
    add("modele:", ply:GetModel(), "sequences:", tostring(ply:GetSequenceCount()), "arme:", IsValid(ply:GetActiveWeapon()) and ply:GetActiveWeapon():GetClass() or "aucune")
    add("_dynamic_wiltos_enabled_:", tostring(ply:LookupSequence("_dynamic_wiltos_enabled_")))
    for _, name in ipairs(CHECK_SEQS) do
        add("seq", name, tostring(ply:LookupSequence(name)))
    end

    add("wOS.DynaBase charge:", tostring(wOS ~= nil and wOS.DynaBase ~= nil))
    if wOS and wOS.DynaBase then
        add("  InitCompleted:", tostring(wOS.DynaBase.InitCompleted), "FIRST_TIME_LOADED:", tostring(wOS.DynaBase.FIRST_TIME_LOADED),
            "ReloadModelBool:", tostring(wOS.DynaBase.ReloadModelBool))
        for name in pairs(wOS.DynaBase.Registers or {}) do add("  source:", name) end
        for name in pairs(wOS.DynaBase.UserMounts or {}) do add("  montage perso:", name) end
    end
    for _, cv in ipairs({ "wos_dynabase_restrict_client_content", "wos_dynabase_live_reload", "wos_dynabase_mountorder", "wos_dynabase_blacklist" }) do
        local c = GetConVar(cv)
        add("convar", cv, c and c:GetString() or "absente")
    end
    for _, f in ipairs({ "local_shared", "local_male", "anim_dynamic", "anim_dynamic_male" }) do
        add("data/wos/dynabase/" .. f .. ".dat", tostring(file.Size("wos/dynabase/" .. f .. ".dat", "DATA")))
    end

    -- le modèle d'extension lui-même se charge-t-il ?
    for _, mdl in ipairs({ "models/player/wiltos/anim_extension_mod6.mdl", "models/m_anm.mdl", "models/player/wiltos/anim_dynamic_pointer.mdl" }) do
        local ok = util.IsValidModel(mdl)
        local count = "?"
        local cs = ClientsideModel(mdl, RENDERGROUP_OTHER)
        if IsValid(cs) then
            count = tostring(cs:GetSequenceCount()) .. " / seq test " .. tostring(cs:LookupSequence(CHECK_SEQS[1]))
            cs:Remove()
        end
        add("modele", mdl, "valide:", tostring(ok), "sequences:", count)
    end

    -- Textures : présentes dans le contenu monté ?
    for _, mat in ipairs({
        "materials/models/godio/senju_a/senju_a.vmt",
        "materials/models/godio/senju_a/senju_a.vtf",
        "materials/models/godio/mat_skin.vmt",
        "materials/models/loeve_shaders/normal.vtf",
        "materials/models/loeve_shaders/lightwarptexture2.vtf",
        "materials/models/skylyxx/ctg/characters/mat_proxy.vtf",
        "materials/models/skylyxx/ctg/characters/toon.vtf",
        "materials/head_03.vmt",
        "materials/hairs1_head.vmt",
    }) do
        add("fichier", mat, tostring(file.Exists(mat, "GAME")))
    end
    local m = Material("models/godio/senju_a/senju_a")
    add("Material senju_a -> shader:", tostring(m and m:GetShader()), "erreur:", tostring(m and m:IsError()))

    add("addons montes / total:", tostring(#engine.GetAddons()))
    for _, a in ipairs(engine.GetAddons()) do
        add("addon", a.wsid, "monte:", tostring(a.mounted), "telecharge:", tostring(a.downloaded), "taille:",
            tostring(math.Round((tonumber(a.size) or 0) / 1048576)) .. "Mo", a.title)
    end

    file.Write("jutsu_anim_diag.txt", table.concat(lines, "\n"))
    print("[Jutsu] diagnostic écrit dans data/jutsu_anim_diag.txt")
end

concommand.Add("jutsu_anim_check", function()
    writeDiag("commande")
end)

hook.Add("InitPostEntity", "Jutsu_Anim_AutoDiag", function()
    timer.Simple(10, function() writeDiag("auto") end)
end)

local function playSequenceOn(ply, seqName, coupe)
    if not IsValid(ply) then return false end
    if type(seqName) ~= "string" or seqName == "" then return false end

    local seq = ply:LookupSequence(seqName)
    if not seq or seq < 0 then
        warnMissing(ply, seqName)
        return false
    end

    ply:AddVCDSequenceToGestureSlot(GESTURE_SLOT_CUSTOM, seq, 0, true)

    -- fin prévue de cette animation (3 s max, comme NA_AnimJutsu) : le souffle katon
    -- (cl_katon_souffle.lua) attend ce moment pour reprendre sa propre animation
    local duree = ply:SequenceDuration(seq)
    if coupe and coupe > 0 then duree = math.min(duree, coupe) end
    ply.NA_AnimFin = CurTime() + math.min(duree, 3)

    -- coupe l'animation après "coupe" secondes (sauf si une autre a été lancée entre-temps)
    local jeton = (ply.NA_AnimJeton or 0) + 1
    ply.NA_AnimJeton = jeton
    if coupe and coupe > 0 then
        timer.Simple(coupe, function()
            if IsValid(ply) and ply.NA_AnimJeton == jeton then
                ply:AnimResetGestureSlot(GESTURE_SLOT_CUSTOM)
            end
        end)
    end
    return true
end

-- Reçoit du serveur: tout le monde joue l'anim sur le joueur
-- (coupe envoyée seulement par NA_AnimJutsu, _na_mudra.lua ; les autres envois n'en ont pas)
net.Receive("Jutsu_Anim_Play", function()
    local ply = net.ReadEntity()
    local seqName = net.ReadString()
    local coupe = (net.BytesLeft() or 0) >= 4 and net.ReadFloat() or 0
    playSequenceOn(ply, seqName, coupe)
end)

-- ✅ API propre: Jutsu.Play("nom_sequence")
-- Options:
--   cooldown: secondes (par défaut 0.25)
--   localOnly: true/false (par défaut false) -> si true, joue uniquement pour toi (debug)
function Jutsu.Play(seqName, opts)
    opts = opts or {}

    local cd = tonumber(opts.cooldown) or 0.25
    Jutsu.Anim._next = Jutsu.Anim._next or 0
    if Jutsu.Anim._next > CurTime() then return false end
    Jutsu.Anim._next = CurTime() + cd

    if opts.localOnly then
        return playSequenceOn(LocalPlayer(), seqName)
    end

    net.Start("Jutsu_Anim_Request")
        net.WriteString(seqName)
    net.SendToServer()

    return true
end
