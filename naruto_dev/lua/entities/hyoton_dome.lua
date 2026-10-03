--========================================================
-- Hyoton : Dôme de glace (entité) : même fonctionnement que futton_monde (zone sur le lanceur, dégâts par tick,
-- ralenti), avec la particule [9]_snowarea (particles/solve_hyoton_geams_give.pcf).
--========================================================

AddCSLuaFile()

ENT.Type      = "anim"
ENT.Base      = "futton_monde"
ENT.PrintName = "Dôme de glace"
ENT.Spawnable = false

ENT.FX = "[9]_snowarea"
