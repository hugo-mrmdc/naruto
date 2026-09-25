if SERVER then
    AddCSLuaFile("autorun/client/futon/cl_futon_windslash.lua")
    include("autorun/server/futon/sv_futon_windslash.lua")
    AddCSLuaFile("autorun/client/futon/cl_futon_tornade.lua")
    include("autorun/server/futon/sv_futon_tornade.lua")
end

if CLIENT then
    include("autorun/client/futon/cl_futon_windslash.lua")
    include("autorun/client/futon/cl_futon_tornade.lua")
end
