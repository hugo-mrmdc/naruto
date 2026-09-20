-- lua/server/sv_main.lua
TONADDON = TONADDON or {}
TONADDON._hooks  = TONADDON._hooks  or {}
TONADDON._timers = TONADDON._timers or {}

local function AddHook(event, id, fn)
    hook.Remove(event, id)
    hook.Add(event, id, fn)
    TONADDON._hooks[id] = event
end

local function AddTimer(id, delay, reps, fn)
    timer.Remove(id)
    timer.Create(id, delay, reps, fn)
    TONADDON._timers[id] = true
end

function TONADDON:Shutdown()
    -- remove hooks
    for id, event in pairs(self._hooks) do
        hook.Remove(event, id)
        self._hooks[id] = nil
    end
    -- remove timers
    for id, _ in pairs(self._timers) do
        timer.Remove(id)
        self._timers[id] = nil
    end
end

function TONADDON:Init()
    print("naruto SV Init")

    -- EXEMPLES (mets ton code ici)
    AddHook("PlayerInitialSpawn", "TONADDON_PlayerInitialSpawn", function(ply)
        print("[naruto] Player join:", ply:Nick())
    end)

    AddTimer("naruto_TestTimer", 5, 0, function()
        -- tick serveur
    end)
end

-- (Re)start propre
TONADDON:Shutdown()
TONADDON:Init()
