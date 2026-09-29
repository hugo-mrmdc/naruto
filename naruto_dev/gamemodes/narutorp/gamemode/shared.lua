--[[
    Naruto RP - point d'entrée partagé (SERVER + CLIENT)

    Convention de nommage des fichiers :
        sv_*.lua  -> serveur uniquement
        cl_*.lua  -> client uniquement (envoyé au client par le serveur)
        sh_*.lua  -> partagé
        *.lua     -> (sans préfixe) partagé, utilisé pour les fichiers de config

    Ordre de chargement :
        1. core/     (liste explicite, voir NRP.CoreFiles)
        2. config/   (données uniquement)
        3. modules/  (NRP.ModuleOrder puis les dossiers restants)
        4. ui/       (ui/core puis les autres dossiers)
]]

GM.Name = "Naruto RP"
GM.Author = "hugo-mrmdc"
GM.Email = ""
GM.Website = ""
GM.TeamBased = false

DeriveGamemode("sandbox")

NRP = NRP or {}
NRP.Version = "0.1.0"
NRP.Folder = GM.FolderName .. "/gamemode"
NRP.Config = NRP.Config or {}

NRP.CoreFiles = {
    "sh_util.lua",
    "sh_registry.lua",
    "sh_net.lua",
    "sh_permissions.lua",
    "sh_notify.lua",
    "sh_cooldowns.lua",
    "sh_keys.lua",
    "sv_commands.lua",
}

-- Les modules sont chargés dans cet ordre (dépendances au chargement).
-- Un dossier ajouté dans modules/ sans figurer ici est chargé automatiquement ensuite.
NRP.ModuleOrder = {
    "database",
    "character",
    "progression",
    "chakra",
    "combat",
    "jutsu",
    "clans",
    "dojutsu",
    "inventory",
    "villages",
    "admin",
}

local REALMS = { sv_ = "server", cl_ = "client", sh_ = "shared" }
local PREFIX_ORDER = { sh_ = 1, sv_ = 2, cl_ = 3 }

function NRP.IncludeFile(path)
    local fileName = string.GetFileFromFilename(path)
    local realm = REALMS[string.sub(fileName, 1, 3)] or "shared"
    local full = NRP.Folder .. "/" .. path

    if realm == "server" then
        if SERVER then include(full) end
    elseif realm == "client" then
        if SERVER then
            AddCSLuaFile(full)
        else
            include(full)
        end
    else
        if SERVER then AddCSLuaFile(full) end
        include(full)
    end
end

-- Charge tous les fichiers .lua d'un dossier (sans préfixe, puis sh_, sv_, cl_),
-- puis ses sous-dossiers si recursive est vrai.
function NRP.IncludeDir(dir, recursive)
    local files, folders = file.Find(NRP.Folder .. "/" .. dir .. "/*", "LUA")
    local luaFiles = {}

    for _, f in ipairs(files or {}) do
        if string.GetExtensionFromFilename(f) == "lua" then
            luaFiles[#luaFiles + 1] = f
        end
    end

    table.sort(luaFiles, function(a, b)
        local pa = PREFIX_ORDER[string.sub(a, 1, 3)] or 0
        local pb = PREFIX_ORDER[string.sub(b, 1, 3)] or 0
        if pa ~= pb then return pa < pb end
        return a < b
    end)

    for _, f in ipairs(luaFiles) do
        NRP.IncludeFile(dir .. "/" .. f)
    end

    if recursive and folders then
        table.sort(folders)
        for _, sub in ipairs(folders) do
            NRP.IncludeDir(dir .. "/" .. sub, true)
        end
    end
end

function NRP.LoadModules()
    local loaded = {}
    for _, name in ipairs(NRP.ModuleOrder) do
        NRP.IncludeDir("modules/" .. name, true)
        loaded[name] = true
    end

    local _, folders = file.Find(NRP.Folder .. "/modules/*", "LUA")
    table.sort(folders)
    for _, name in ipairs(folders) do
        if not loaded[name] then
            NRP.IncludeDir("modules/" .. name, true)
        end
    end
end

function NRP.LoadUI()
    NRP.IncludeDir("ui/core", true)

    local _, folders = file.Find(NRP.Folder .. "/ui/*", "LUA")
    table.sort(folders)
    for _, name in ipairs(folders) do
        if name ~= "core" then
            NRP.IncludeDir("ui/" .. name, true)
        end
    end
end

for _, f in ipairs(NRP.CoreFiles) do
    NRP.IncludeFile("core/" .. f)
end

NRP.IncludeDir("config", true)
NRP.LoadModules()
NRP.LoadUI()

NRP.Print("Gamemode chargé (v" .. NRP.Version .. ", " .. (SERVER and "serveur" or "client") .. ")")
hook.Run("NRP.Loaded")
