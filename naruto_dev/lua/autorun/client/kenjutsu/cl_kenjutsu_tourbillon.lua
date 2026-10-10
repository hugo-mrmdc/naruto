--========================================================
-- Kenjutsu : Tourbillon de lame (CLIENT)
-- Lancement depuis la barre de techniques ; animation et coup sont côté serveur.
-- La particule de slash est posée en hauteur, suit le lanceur et s'arrête à la fin de l'animation.
--========================================================

local FX      = "[2]_concasse_add"   -- particles/julio.pcf
local HAUTEUR = 55                   -- hauteur de la particule au-dessus des pieds (le slash passe à hauteur du torse)

NA_Cast = NA_Cast or {}
NA_Cast.kenjutsu_tourbillon = function()
    net.Start("kenjutsu_tourbillon_cast")
    net.SendToServer()
end

game.AddParticles("particles/julio.pcf")
PrecacheParticleSystem(FX)

local actifs = {}   -- { ent, fin, p }

net.Receive("kenjutsu_tourbillon_fx", function()
    local ent, delai, duree = net.ReadEntity(), net.ReadFloat(), net.ReadFloat()
    if not IsValid(ent) then return end
    timer.Simple(delai, function()
        if not IsValid(ent) then return end
        local p = ent:CreateParticleEffect(FX, 0)
        if p then actifs[#actifs + 1] = { ent = ent, fin = CurTime() + duree, p = p } end
    end)
end)

hook.Add("Think", "Kenjutsu_Tourbillon_FX", function()
    for i = #actifs, 1, -1 do
        local a = actifs[i]
        local fini = not IsValid(a.ent) or not a.ent:Alive() or CurTime() > a.fin or not IsValid(a.p)
        if fini then
            if IsValid(a.p) then a.p:StopEmissionAndDestroyImmediately() end
            table.remove(actifs, i)
        else
            local ang = Angle(0, a.ent:EyeAngles().y, 0)
            a.p:SetControlPoint(0, a.ent:GetPos() + Vector(0, 0, HAUTEUR))
            a.p:SetControlPointOrientation(0, ang:Forward(), ang:Right(), ang:Up())
        end
    end
end)
