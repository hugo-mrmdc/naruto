--[[
    Core : registres génériques

    Toutes les données extensibles (jutsu, clans, objets, villages, grades...) passent
    par un registre. Ajouter du contenu = appeler :Register(id, definition).

        local Items = NRP.CreateRegistry("items", {
            defaults = { weight = 0, stack = 1 },
            validate = function(def) return isstring(def.name), "nom manquant" end,
        })
        Items:Register("kunai", { name = "Kunai" })
]]

NRP.Registries = NRP.Registries or {}

local REGISTRY = {}
REGISTRY.__index = REGISTRY

function NRP.CreateRegistry(name, opts)
    opts = opts or {}
    local reg = setmetatable({
        name = name,
        items = {},
        list = {},
        defaults = opts.defaults,
        validate = opts.validate,
        onRegister = opts.onRegister,
    }, REGISTRY)

    NRP.Registries[name] = reg
    return reg
end

function NRP.GetRegistry(name)
    return NRP.Registries[name]
end

function REGISTRY:Register(id, def)
    if not NRP.Util.IsValidId(id) then
        NRP.Error("[" .. self.name .. "] identifiant invalide :", tostring(id))
        return
    end
    if not istable(def) then
        NRP.Error("[" .. self.name .. "] définition invalide pour", id)
        return
    end

    def.id = id

    if self.defaults then
        for k, v in pairs(self.defaults) do
            if def[k] == nil then
                def[k] = istable(v) and table.Copy(v) or v
            end
        end
    end

    if self.validate then
        local ok, err = self.validate(def)
        if not ok then
            NRP.Error("[" .. self.name .. "] '" .. id .. "' ignoré :", err or "invalide")
            return
        end
    end

    if not self.items[id] then
        self.list[#self.list + 1] = id
    end
    self.items[id] = def

    if self.onRegister then
        self.onRegister(def)
    end

    return def
end

-- Enregistre toutes les entrées d'une table de config { id = def }.
function REGISTRY:RegisterAll(tbl)
    for id, def in SortedPairs(tbl or {}) do
        self:Register(id, def)
    end
end

function REGISTRY:Get(id)
    if id == nil then return nil end
    return self.items[id]
end

function REGISTRY:Exists(id)
    return id ~= nil and self.items[id] ~= nil
end

function REGISTRY:GetAll()
    return self.items
end

function REGISTRY:Count()
    return #self.list
end

-- Itère dans l'ordre d'enregistrement.
function REGISTRY:Iterate()
    local i = 0
    local list, items = self.list, self.items
    return function()
        i = i + 1
        local id = list[i]
        if id then
            return id, items[id]
        end
    end
end

-- Liste triée par un champ (ex: "order") puis par nom.
function REGISTRY:Sorted(field)
    local out = {}
    for _, id in ipairs(self.list) do
        out[#out + 1] = self.items[id]
    end
    field = field or "order"
    table.sort(out, function(a, b)
        local fa, fb = tonumber(a[field]) or 0, tonumber(b[field]) or 0
        if fa ~= fb then return fa < fb end
        return tostring(a.name or a.id) < tostring(b.name or b.id)
    end)
    return out
end

function REGISTRY:Remove(id)
    if not self.items[id] then return end
    self.items[id] = nil
    table.RemoveByValue(self.list, id)
end
