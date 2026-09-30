"""Regression du tatouage : utilise le LuaJIT livré avec GMod, sans lancer le jeu."""
import ctypes
import os
from pathlib import Path

addon = Path(__file__).resolve().parents[1]
game = addon.parents[2]
search = [game / "bin/win64", game / "garrysmod/bin/win64", game / "bin"]
directories = [os.add_dll_directory(str(p)) for p in search if p.is_dir()]
lua = ctypes.CDLL(str(game / "garrysmod/bin/win64/lua_shared.dll"))
lua.luaL_newstate.restype = ctypes.c_void_p
lua.luaL_openlibs.argtypes = [ctypes.c_void_p]
lua.luaL_loadbuffer.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_size_t, ctypes.c_char_p]
lua.lua_pcall.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int]
lua.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_void_p]
lua.lua_tolstring.restype = ctypes.c_char_p
lua.lua_settop.argtypes = [ctypes.c_void_p, ctypes.c_int]
lua.lua_close.argtypes = [ctypes.c_void_p]
lua.lua_createtable.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int]
lua.lua_pushlstring.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_size_t]
lua.lua_setfield.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_char_p]
state = lua.luaL_newstate()
assert state
lua.luaL_openlibs(state)


def check(code, name, execute=False):
    code = code.encode("utf-8")
    result = lua.luaL_loadbuffer(state, code, len(code), name.encode())
    if result == 0 and execute:
        result = lua.lua_pcall(state, 0, 0, 0)
    if result:
        raise AssertionError(lua.lua_tolstring(state, -1, None).decode())
    lua.lua_settop(state, 0)


try:
    for name in ["cl_perso.lua", "senju/cl_senju_ermite.lua", "senju/face_shell_flex.lua"]:
        check((addon / "lua/autorun/client" / name).read_text(encoding="utf-8"), name)
    loader = (addon / "lua/autorun/client/senju/face_shell_flex.lua").read_text(encoding="utf-8")
    lua.lua_createtable(state, 0, 56)
    for path in (addon / "models/head").glob("face_*.*"):
        if path.suffix not in (".mdl", ".vvd"):
            continue
        content = path.read_bytes()
        lua.lua_pushlstring(state, content, len(content))
        lua.lua_setfield(state, -2, path.relative_to(addon).as_posix().encode())
    lua.lua_setfield(state, -10002, b"FILES")
    check(r"""
        bit = {band=function(value, mask)
            return math.floor(value / mask) % 2 == 1 and mask or 0
        end}
        function Vector(x,y,z) return {x=x,y=y,z=z} end
        file = {}
        function file.Open(path)
            local bytes = assert(FILES[path], path)
            local offset = 0
            local r = {}
            function r:Size() return #bytes end
            function r:Seek(o) offset = o end
            function r:Read(n)
                local value = string.sub(bytes, offset + 1, offset + n)
                offset = offset + n
                return value
            end
            function r:Close() end
            local function uint(n)
                local bytes = r:Read(n)
                local value = 0
                for k=n,1,-1 do value = value * 256 + string.byte(bytes,k) end
                return value
            end
            function r:ReadLong()
                local v = uint(4)
                return v >= 2147483648 and v - 4294967296 or v
            end
            function r:ReadFloat()
                local v = uint(4)
                local sign = v >= 2147483648 and -1 or 1
                local exponent = math.floor(v / 8388608) % 256
                local fraction = v % 8388608
                if exponent == 0 then return sign * fraction * 2^-149 end
                assert(exponent ~= 255)
                return sign * (1 + fraction / 8388608) * 2^(exponent - 127)
            end
            function r:ReadUShort() return uint(2) end
            function r:ReadByte() return string.byte(r:Read(1)) end
            return r
        end
        local function loadModule()
    """ + loader + r"""
        end
        local M = loadModule()
        local a = {pos=Vector(1,2,3),u=.4,v=.6,normal=Vector(0,1,0)}
        local b = {pos=a.pos,u=a.u,v=a.v,normal=Vector(0,0,1)}
        assert(M.Key(a) ~= M.Key(b), "seam vertices must remain distinct")
        for n=1,28 do
            local data, err = M.Load("models/head/face_" .. n .. ".mdl")
            assert(data, tostring(err))
            assert(#data.flexes > 0 and next(data.vertices), "missing flex data face_" .. n)
        end
        M.ClosePending()
    """, "shell-flex-regression", execute=True)
    # Confirme sur les vrais fichiers que la nouvelle clé ne fusionne pas
    # de deltas incompatibles, y compris les coutures des visages 5 et 21.
    import struct
    old_conflicts = new_conflicts = 0
    for path in (addon / "models/head").glob("face_*.mdl"):
        mdl, vvd = path.read_bytes(), path.with_suffix(".vvd").read_bytes()
        def integer(o): return struct.unpack_from("<i", mdl, o)[0]
        body = integer(236)
        model = body + integer(body + 12)
        start = struct.unpack_from("<i", vvd, 56)[0] + integer(model + 84)
        face_material = None
        for ti in range(integer(204)):
            texture = integer(208) + ti * 64
            name = texture + integer(texture)
            if mdl[name:mdl.index(b"\0", name)] == b"face":
                face_material = ti
        assert face_material is not None
        for mi in range(integer(model + 72)):
            mesh = model + integer(model + 76) + mi * 116
            if integer(mesh) != face_material:
                continue
            vertices = [struct.unpack_from("<8f", vvd,
                start + (integer(mesh + 12) + vi) * 48 + 16)
                for vi in range(integer(mesh + 8))]
            for fi in range(integer(mesh + 16)):
                flex = mesh + integer(mesh + 20) + fi * 60
                old_seen, new_seen = {}, {}
                for di in range(integer(flex + 20)):
                    d = flex + integer(flex + 24) + di * 16
                    vi = struct.unpack_from("<H", mdl, d)[0]
                    v = vertices[vi]
                    old_key = tuple(round(x, 4) for x in v[:3] + v[6:])
                    new_key = tuple(round(x, 4) for x in v)
                    delta = mdl[d + 4:d + 16]
                    old_conflicts += old_key in old_seen and old_seen[old_key] != delta
                    new_conflicts += new_key in new_seen and new_seen[new_key] != delta
                    old_seen[old_key] = new_seen[new_key] = delta
    assert new_conflicts == 0, (old_conflicts, new_conflicts)
    print(f"OK: Lua syntax; actual loader on 28 faces; conflicting matches {old_conflicts} -> {new_conflicts}")
finally:
    lua.lua_close(state)
