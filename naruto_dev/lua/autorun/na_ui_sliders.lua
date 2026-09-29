-- Curseur numérique commun aux interfaces Naruto.
if SERVER then
    AddCSLuaFile()
    resource.AddFile("materials/ui/chara_crea/slider.png")
    resource.AddFile("materials/ui/chara_crea/knob_slider.png")
    return
end

local track = Material("ui/chara_crea/slider.png", "smooth")
local knob = Material("ui/chara_crea/knob_slider.png", "smooth")
local PANEL = {}

function PANEL:Init()
    -- vgui.Create a déjà initialisé DNumSlider avant cette classe dérivée.
    local slider = self.Slider
    slider:SetTrapInside(true)
    slider.Knob:SetSize(20, 24) -- zone de clic plus large que le dessin

    slider.Paint = function(control, w, h)
        local half = control.Knob:GetWide() / 2
        surface.SetMaterial(track)
        surface.SetDrawColor(255, 255, 255, control:IsEnabled() and 255 or 100)
        -- Les centres des deux extrémités du PNG suivent la course du bouton.
        surface.DrawTexturedRect(half - 6, (h - 14) / 2, math.max(w - half * 2 + 12, 12), 14)
    end

    slider.Knob.Paint = function(control, w, h)
        surface.SetMaterial(knob)
        local alpha = control:IsEnabled() and 255 or 100
        surface.SetDrawColor(255, 255, 255, alpha)
        surface.DrawTexturedRect((w - 12) / 2, (h - 21) / 2, 12, 21)
    end
end

vgui.Register("NA_NumSlider", PANEL, "DNumSlider")
