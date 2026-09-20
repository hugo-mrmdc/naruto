-- lua/client/cl_main.lua
TONADDON = TONADDON or {}
TONADDON._clhooks = TONADDON._clhooks or {}

local function AddHook(event, id, fn)
    hook.Remove(event, id)
    hook.Add(event, id, fn)
    TONADDON._clhooks[id] = event
end

function TONADDON:CLShutdown()
    for id, event in pairs(self._clhooks) do
        hook.Remove(event, id)
        self._clhooks[id] = nil
    end
end

function TONADDON:CLInit()
    print("[TONADDON] CL Init")

    -- EXEMPLE
    AddHook("HUDPaint", "TONADDON_HUDPaint", function()
        -- draw hud
    end)
end

TONADDON:CLShutdown()
TONADDON:CLInit()
