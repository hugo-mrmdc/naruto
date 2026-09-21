-- Jutsu Animations (SERVER)
util.AddNetworkString("Jutsu_Anim_Request")
util.AddNetworkString("Jutsu_Anim_Play")

local function isSafeSeqName(s)
    if type(s) ~= "string" then return false end
    if #s < 2 or #s > 128 then return false end
    -- autorise lettres, chiffres, _, -, / (si tu en as), et .
    return s:match("^[%w_/%-%.]+$") ~= nil
end

net.Receive("Jutsu_Anim_Request", function(_, ply)
    if not IsValid(ply) then return end

    local seqName = net.ReadString()
    if not isSafeSeqName(seqName) then return end

    -- Cooldown simple (évite spam réseau)
    ply._jutsuAnimCD = ply._jutsuAnimCD or 0
    if ply._jutsuAnimCD > CurTime() then return end
    ply._jutsuAnimCD = CurTime() + 0.25

    -- Broadcast à tous: jouer la séquence sur CE joueur
    NA_AnimJutsu(ply, seqName)   -- animation + pas de coups pendant (_na_mudra.lua)
end)
