-- Only distribute the textures used by the F4 menu, never the full-size sources.
for _, name in ipairs({ "fond_v2", "utiliser", "caseEmpty", "equipecase", "comun", "rare", "epique", "legendaire" }) do
    resource.AddFile("materials/ui/newUi/optimized/" .. name .. ".png")
end
