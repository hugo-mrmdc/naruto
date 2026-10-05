if SERVER then
    AddCSLuaFile("autorun/client/futon/cl_futon_windslash.lua")
    include("autorun/server/futon/sv_futon_windslash.lua")
    AddCSLuaFile("autorun/client/futon/cl_futon_tornade.lua")
    include("autorun/server/futon/sv_futon_tornade.lua")
    AddCSLuaFile("autorun/client/futon/cl_futon_windball.lua")
    include("autorun/server/futon/sv_futon_windball.lua")
    AddCSLuaFile("autorun/client/futon/cl_futon_ouragan.lua")
    include("autorun/server/futon/sv_futon_ouragan.lua")
    AddCSLuaFile("autorun/client/futon/cl_futon_expulsion.lua")
    include("autorun/server/futon/sv_futon_expulsion.lua")
    AddCSLuaFile("autorun/client/futon/cl_futon_grand_ouragan.lua")
    include("autorun/server/futon/sv_futon_grand_ouragan.lua")
    AddCSLuaFile("autorun/client/futon/cl_futon_rasenshuriken.lua")
    include("autorun/server/futon/sv_futon_rasenshuriken.lua")
end

if CLIENT then
    include("autorun/client/futon/cl_futon_windslash.lua")
    include("autorun/client/futon/cl_futon_tornade.lua")
    include("autorun/client/futon/cl_futon_windball.lua")
    include("autorun/client/futon/cl_futon_ouragan.lua")
    include("autorun/client/futon/cl_futon_expulsion.lua")
    include("autorun/client/futon/cl_futon_grand_ouragan.lua")
    include("autorun/client/futon/cl_futon_rasenshuriken.lua")
end
