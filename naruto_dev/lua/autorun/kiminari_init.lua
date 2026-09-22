-- Chargeur des techniques Kiminari.
-- GMod ne lit PAS les sous-dossiers de lua/autorun : sans ce fichier, rien ne se charge.

-- Particules : chargées des deux côtés
game.AddParticles("particles/atg_farisv2.pcf")
PrecacheParticleSystem("[19]_kiminari_charge")

if SERVER then
    resource.AddFile("particles/atg_farisv2.pcf")
    resource.AddFile("materials/ui/icon/kiminari_frappe_noir.png")

    AddCSLuaFile("autorun/client/kiminari/cl_kiminari_frappe.lua")
    include("autorun/server/kiminari/sv_kiminari_frappe.lua")
end

if CLIENT then
    include("autorun/client/kiminari/cl_kiminari_frappe.lua")
end
