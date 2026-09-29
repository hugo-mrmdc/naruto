-- Lecture des flexes des têtes Source v48 de cet addon.
-- Layouts : Valve source-sdk-2013/src/public/studio.h.
local M = {}
local opened = {}
function M.ClosePending()
    for f in pairs(opened) do f:Close() end
    opened = {}
end

function M.Key(v)
    return string.format("%.4f/%.4f/%.4f/%.4f/%.4f", v.pos.x, v.pos.y, v.pos.z, v.u, v.v)
end

local function Half(n)
    local sign = n >= 32768 and -1 or 1
    n = n % 32768
    local exponent, fraction = math.floor(n / 1024), n % 1024
    if exponent == 0 then return sign * fraction * 2 ^ -24 end
    if exponent == 31 then error("non-finite flex delta") end
    return sign * (1 + fraction / 1024) * 2 ^ (exponent - 15)
end

function M.Load(model, yieldWork)
    -- Ces modèles ont un seul LOD sans fixups et des deltas float16.
    if not string.match(model, "^models/head/face_%d+%.mdl$") then return nil, "unsupported model" end
    local mdl = file.Open(model, "rb", "GAME")
    local vvd = file.Open(string.gsub(model, "%.mdl$", ".vvd"), "rb", "GAME")
    if not mdl or not vvd then
        if mdl then mdl:Close() end
        if vvd then vvd:Close() end
        return nil, "missing MDL/VVD"
    end
    opened[mdl], opened[vvd] = true, true
    local mdlSize, vvdSize = mdl:Size(), vvd:Size()
    local ok, result = pcall(function()
        local function At(f, offset, bytes)
            assert(offset >= 0 and offset + bytes <= (f == mdl and mdlSize or vvdSize), "flex data out of bounds")
            f:Seek(offset)
            return f
        end
        local function Int(offset) return At(mdl, offset, 4):ReadLong() end
        assert(At(mdl, 0, 4):Read(4) == "IDST" and Int(4) == 48, "unsupported MDL")
        assert(bit.band(Int(152), 0x200000) == 0, "fixed-point flexes unsupported")
        assert(At(vvd, 0, 4):Read(4) == "IDSV", "invalid VVD")
        assert(At(vvd, 48, 4):ReadLong() == 0, "VVD fixups unsupported")
        local vertexStart = At(vvd, 56, 4):ReadLong()
        local descriptorCount, descriptors = Int(260), Int(264)
        local names = {}
        for d = 0, descriptorCount - 1 do
            local start = descriptors + d * 4
            At(mdl, start + Int(start), 1)
            local chars = {}
            for c = 1, 128 do
                local ch = mdl:Read(1)
                if ch == "\0" then break end
                assert(ch and ch ~= "", "invalid flex name")
                chars[#chars + 1] = ch
            end
            names[d] = table.concat(chars)
        end
        local body = Int(236)
        local modelOffset = body + Int(body + 12)
        local meshes = modelOffset + Int(modelOffset + 76)
        local modelVertexOffset = Int(modelOffset + 84)
        local data = { vertices = {}, flexes = {} }
        for mi = 0, Int(modelOffset + 72) - 1 do
            local meshOffset = meshes + mi * 116
            -- Les têtes de cet addon ont le matériau face à l'index 2.
            if Int(meshOffset) == 2 then
                local keys = {}
                local vertexOffset = Int(meshOffset + 12)
                for vi = 0, Int(meshOffset + 8) - 1 do
                    if yieldWork and vi % 64 == 0 then yieldWork() end
                    local offset = vertexStart + modelVertexOffset + (vertexOffset + vi) * 48
                    At(vvd, offset + 16, 32)
                    local pos = Vector(vvd:ReadFloat(), vvd:ReadFloat(), vvd:ReadFloat())
                    At(vvd, offset + 40, 8)
                    keys[vi] = M.Key({ pos = pos, u = vvd:ReadFloat(), v = vvd:ReadFloat() })
                end
                local flexBase = meshOffset + Int(meshOffset + 20)
                for fi = 0, Int(meshOffset + 16) - 1 do
                    local offset = flexBase + fi * 60
                    assert(Int(offset + 28) == 0, "paired flex unsupported")
                    assert(At(mdl, offset + 32, 1):ReadByte() == 0, "wrinkle flex unsupported")
                    At(mdl, offset + 4, 16)
                    local flex = { name = names[Int(offset)] }
                    -- Int(offset) déplace le curseur : relire les quatre cibles.
                    At(mdl, offset + 4, 16)
                    flex.targets = { mdl:ReadFloat(), mdl:ReadFloat(), mdl:ReadFloat(), mdl:ReadFloat() }
                    assert(flex.name, "unknown flex descriptor")
                    data.flexes[#data.flexes + 1] = flex
                    local flexIndex = #data.flexes
                    local deltas = offset + Int(offset + 24)
                    local seen = {}
                    for di = 0, Int(offset + 20) - 1 do
                        if yieldWork and di % 64 == 0 then yieldWork() end
                        At(mdl, deltas + di * 16, 16)
                        local vi = mdl:ReadUShort()
                        mdl:ReadByte() -- speed (la forme courante est appliquée sans retard)
                        mdl:ReadByte() -- side (pas de flexpair sur ces modèles)
                        local dp = Vector(Half(mdl:ReadUShort()), Half(mdl:ReadUShort()), Half(mdl:ReadUShort()))
                        local dn = Vector(Half(mdl:ReadUShort()), Half(mdl:ReadUShort()), Half(mdl:ReadUShort()))
                        local key = assert(keys[vi], "invalid flex vertex")
                        if not seen[key] then
                            seen[key] = true
                            data.vertices[key] = data.vertices[key] or {}
                            table.insert(data.vertices[key], { flex = flexIndex, pos = dp, normal = dn })
                        end
                    end
                end
            end
        end
        return data
    end)
    mdl:Close()
    vvd:Close()
    opened[mdl], opened[vvd] = nil, nil
    if not ok then return nil, tostring(result) end
    return result
end

function M.Weights(ent, data)
    local weights = {}
    local ids = ent.NA_SenjuFlexIDs
    if not ids or ids.data ~= data then
        ids = { data = data }
        for i, flex in ipairs(data.flexes) do ids[i] = ent:GetFlexIDByName(flex.name) or false end
        ent.NA_SenjuFlexIDs = ids
    end
    local scale = ent:GetFlexScale()
    for i, flex in ipairs(data.flexes) do
        local id = ids[i]
        local value = id and ent:GetFlexWeight(id) or 0
        local t = flex.targets
        local w = 0
        if value > t[1] and value < t[4] then
            if value < t[2] then w = (value - t[1]) / (t[2] - t[1])
            elseif value > t[3] then w = (t[4] - value) / (t[4] - t[3])
            else w = 1 end
        end
        weights[i] = w * scale
    end
    return weights
end

return M
