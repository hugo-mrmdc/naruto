--[[
    Module : Jutsu (client)

    - Touches 1..N (binds slot1..slotN) : sélection d'un emplacement quand les mains ninja
      sont en main. Molette : emplacement suivant/précédent (nrp_wheel_select 1).
      Les joueurs ayant accès au sandbox maintiennent MAJ pour changer d'arme normalement.
    - Touche "cast" (R par défaut) : lance le jutsu sélectionné.
    - nrp_quickcast 1 : la touche numérique lance directement le jutsu.
    Le client n'envoie que le numéro d'emplacement ; le serveur décide de tout le reste.
]]

local Jutsu = NRP.Jutsu

local cvQuickCast = CreateClientConVar("nrp_quickcast", "0", true, false, "Lancer le jutsu dès la sélection de l'emplacement")
local cvWheel = CreateClientConVar("nrp_wheel_select", "1", true, false, "La molette change d'emplacement de jutsu")

Jutsu.SelectedSlot = Jutsu.SelectedSlot or 1

function Jutsu.GetLoadout()
    local data = NRP.Char.Local
    return data and data.loadout or {}
end

function Jutsu.GetSelected()
    local id = Jutsu.GetLoadout()[Jutsu.SelectedSlot]
    if id and id ~= "" then
        return Jutsu.Registry:Get(id), id
    end
end

function Jutsu.RequestCast(slot)
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end
    local id = Jutsu.GetLoadout()[slot]
    if not id or id == "" then return end
    if not NRP.Net.CanSend("CastJutsu", 0.12) then return end

    NRP.Net.Start("CastJutsu")
        net.WriteUInt(slot, 4)
    net.SendToServer()
end

function Jutsu.RequestSetSlot(slot, id)
    if not NRP.Net.CanSend("SetLoadout" .. slot, 0.2) then return end
    NRP.Net.Start("SetLoadout")
        net.WriteUInt(slot, 4)
        net.WriteString(id or "")
    net.SendToServer()
end

function Jutsu.Select(slot)
    slot = math.Clamp(slot, 1, Jutsu.SlotCount())
    if Jutsu.SelectedSlot ~= slot then
        Jutsu.SelectedSlot = slot
        surface.PlaySound("solve_naruto_base/ui/swap_jutsu_deck.wav")
        hook.Run("NRP.JutsuSelected", slot)
    end
    if cvQuickCast:GetBool() then
        Jutsu.RequestCast(slot)
    end
end

NRP.Keys.OnPress("cast", function()
    Jutsu.RequestCast(Jutsu.SelectedSlot)
end)

local function HoldingHands(ply)
    local wep = ply:GetActiveWeapon()
    return IsValid(wep) and wep:GetClass() == "nrp_hands"
end

hook.Add("PlayerBindPress", "NRP.Jutsu.Binds", function(ply, bind, pressed)
    if not pressed or not HoldingHands(ply) then return end
    if NRP.Perm.Has(ply, "admin.sandbox") and input.IsKeyDown(KEY_LSHIFT) then return end

    local slot = tonumber(string.match(bind, "^slot(%d+)$"))
    if slot and slot >= 1 and slot <= Jutsu.SlotCount() then
        Jutsu.Select(slot)
        return true
    end

    if cvWheel:GetBool() then
        local count = Jutsu.SlotCount()
        if string.find(bind, "invnext", 1, true) then
            Jutsu.SelectedSlot = Jutsu.SelectedSlot % count + 1
            hook.Run("NRP.JutsuSelected", Jutsu.SelectedSlot)
            return true
        elseif string.find(bind, "invprev", 1, true) then
            Jutsu.SelectedSlot = (Jutsu.SelectedSlot - 2) % count + 1
            hook.Run("NRP.JutsuSelected", Jutsu.SelectedSlot)
            return true
        end
    end
end)

---------------------------------------------------------------------------
-- Animations et effets d'incantation
---------------------------------------------------------------------------

local function PlayAnimation(ply, anim)
    if not anim then return end
    if anim.sequence then
        local seq = ply:LookupSequence(anim.sequence)
        if seq and seq >= 0 then
            ply:AddVCDSequenceToGestureSlot(GESTURE_SLOT_CUSTOM, seq, 0, true)
            return
        end
    end
    if anim.gesture then
        ply:AnimRestartGesture(GESTURE_SLOT_CUSTOM, anim.gesture, true)
    end
end

NRP.Net.Receive("JutsuFX", function()
    local ply = net.ReadEntity()
    local id = net.ReadString()
    local event = net.ReadUInt(2)
    local duration = net.ReadFloat()
    if not IsValid(ply) then return end

    local jutsu = Jutsu.Registry:Get(id)
    if not jutsu then return end

    if event == 1 then
        PlayAnimation(ply, jutsu.castAnimation)
        ply.NRPCastColor = (Jutsu.Categories:Get(jutsu.category) or {}).color
        ply.NRPCastDuration = duration
    elseif event == 2 then
        PlayAnimation(ply, jutsu.animation)
    elseif event == 3 then
        ply:AnimResetGestureSlot(GESTURE_SLOT_CUSTOM)
    end

    hook.Run("NRP.JutsuFX", ply, jutsu, event, duration)
end)

-- Lueur de chakra dans les mains pendant les mudras
local MAT_GLOW = Material("sprites/light_glow02_add")

hook.Add("PostPlayerDraw", "NRP.Jutsu.CastGlow", function(ply)
    if ply:GetNW2Float("NRP_CastEnd", 0) <= CurTime() or ply:IsDormant() then return end

    local bone = ply:LookupBone("ValveBiped.Bip01_R_Hand")
    local pos = bone and ply:GetBonePosition(bone)
    if not pos then return end

    local color = ply.NRPCastColor or Color(80, 160, 255)
    local pulse = 18 + math.sin(CurTime() * 20) * 4
    render.SetMaterial(MAT_GLOW)
    render.DrawSprite(pos, pulse, pulse, Color(color.r, color.g, color.b, 220))
end)
