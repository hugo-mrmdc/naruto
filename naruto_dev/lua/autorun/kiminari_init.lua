-- Chargeur des techniques Kiminari.
-- GMod ne lit PAS les sous-dossiers de lua/autorun : sans ce fichier, rien ne se charge.

-- Particules : chargées des deux côtés
game.AddParticles("particles/atg_farisv2.pcf")
PrecacheParticleSystem("[19]_kiminari_charge")
game.AddParticles("particles/atg_faris.pcf")
PrecacheParticleSystem("[3]_electric_tornado")
PrecacheParticleSystem("[3]_electric_aura")

if SERVER then
    resource.AddFile("particles/atg_farisv2.pcf")
    resource.AddFile("particles/atg_faris.pcf")
    resource.AddFile("materials/ui/icon/kiminari_frappe_noir.png")
    resource.AddFile("materials/ui/icon/kiminari_prison_noir.png")

    AddCSLuaFile("autorun/client/kiminari/cl_kiminari_frappe.lua")
    include("autorun/server/kiminari/sv_kiminari_frappe.lua")
    AddCSLuaFile("autorun/client/kiminari/cl_kiminari_prison.lua")
    include("autorun/server/kiminari/sv_kiminari_prison.lua")
end

if CLIENT then
    include("autorun/client/kiminari/cl_kiminari_frappe.lua")
    include("autorun/client/kiminari/cl_kiminari_prison.lua")
end
