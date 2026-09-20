"""Remonte les dépendances (modèle -> matériaux -> textures) et dit qui fournit quoi."""
import re, struct, sys, json, os
import gmaindex

DATA = gmaindex.build("index.json")
INDEX = DATA["index"]
TITLES = DATA["titles"]
DISABLED = set(DATA["disabled"])

MDL_EXT = (".mdl", ".vvd", ".dx90.vtx", ".dx80.vtx", ".sw.vtx", ".phy", ".ani")
TEX_KEYS = ("$basetexture", "$basetexture2", "$bumpmap", "$bumpmap2", "$lightwarptexture",
            "$detail", "$selfillummask", "$phongexponenttexture", "$envmapmask",
            "$blendmodulatetexture", "$texture2", "$normalmap", "$iris", "$corneatexture",
            "$ambientoccltexture", "$fresnelrangestexture")


def get(path):
    return INDEX.get(path.lower().replace("\\", "/"))


def mdl_materials(data):
    """(dossiers cdmaterials, noms de textures) d'un .mdl"""
    try:
        numtextures, textureindex, numcd, cdindex = struct.unpack_from('<iiii', data, 204)
    except struct.error:
        return [], []
    names, dirs = [], []

    def cstr(off):
        e = data.index(b'\0', off)
        return data[off:e].decode('utf-8', 'replace')

    for i in range(min(numtextures, 256)):
        base = textureindex + i * 64
        try:
            sznameindex = struct.unpack_from('<i', data, base)[0]
            names.append(cstr(base + sznameindex))
        except Exception:
            pass
    for i in range(min(numcd, 32)):
        try:
            off = struct.unpack_from('<i', data, cdindex + i * 4)[0]
            dirs.append(cstr(off))
        except Exception:
            pass
    return dirs, names


def vmt_textures(text):
    out = []
    for key in TEX_KEYS:
        for m in re.finditer(r'(?i)"?%s"?[ \t]+"?([^"\r\n]+)"?' % re.escape(key), text):
            val = m.group(1).strip().strip('"').replace("\\", "/")
            if val and not val.startswith("["):
                out.append(val)
    includes = [m.group(1).strip().replace("\\", "/")
                for m in re.finditer(r'(?i)"?include"?\s+"([^"]+)"', text)]
    return out, includes


def walk(models):
    need = {}        # chemin -> raison
    missing = {}

    def want(path, why):
        path = path.lower().replace("\\", "/")
        if path in need:
            return
        e = get(path)
        if e:
            need[path] = (e, why)
        else:
            missing[path] = why
        return e

    for mdl in models:
        mdl = mdl.lower()
        base = mdl[:-4] if mdl.endswith(".mdl") else mdl
        entry = want(mdl, "modèle")
        for ext in MDL_EXT[1:]:
            if get(base + ext):
                want(base + ext, "modèle")
        if not entry:
            continue
        dirs, names = mdl_materials(gmaindex.read(entry))
        for name in names:
            found = False
            cands = []
            for d in dirs or [""]:
                cands.append("materials/" + (d + name).replace("\\", "/").lstrip("/") + ".vmt")
            cands.append("materials/" + name.replace("\\", "/") + ".vmt")
            for c in cands:
                if get(c):
                    want(c, "matériau de " + os.path.basename(mdl))
                    found = True
                    break
            if not found:
                missing[cands[0]] = "matériau de " + os.path.basename(mdl)

    # matériaux -> textures (récursif sur les Patch include)
    queue = [p for p in list(need) if p.endswith(".vmt")]
    seen = set()
    while queue:
        p = queue.pop()
        if p in seen:
            continue
        seen.add(p)
        e = need.get(p)
        if not e:
            continue
        try:
            text = gmaindex.read(e[0]).decode('utf-8', 'replace')
        except Exception:
            continue
        texs, includes = vmt_textures(text)
        for t in texs:
            want("materials/" + t + ".vtf", "texture de " + os.path.basename(p))
        for inc in includes:
            inc = inc if inc.lower().startswith("materials/") else "materials/" + inc
            if want(inc, "patch de " + os.path.basename(p)):
                queue.append(inc.lower())
    return need, missing


def source_label(entry):
    if entry.get("src") != "workshop":
        return entry["src"]
    wsid = entry["wsid"]
    flag = " [DÉSACTIVÉ]" if wsid in DISABLED else ""
    return "%s (%s)%s" % (TITLES.get(wsid) or "?", wsid, flag)


if __name__ == "__main__":
    models = [l.strip() for l in open(sys.argv[1], encoding='utf-8') if l.strip()]
    need, missing = walk(models)

    by_src = {}
    for path, (entry, why) in need.items():
        by_src.setdefault(source_label(entry), []).append((path, entry, why))

    total = 0
    for src in sorted(by_src, key=lambda s: -len(by_src[s])):
        files = by_src[src]
        size = sum(f[1].get("size") or os.path.getsize(f[1]["path"]) for f in files)
        total += size
        print("== %-60s %4d fichiers  %8.2f Mo" % (src, len(files), size / 1048576))
    print("TOTAL %.2f Mo" % (total / 1048576))
    print()
    print("MANQUANTS (%d) :" % len(missing))
    for p, why in sorted(missing.items()):
        print("   ", p, "-", why)

    json.dump({p: {"src": source_label(e), "why": w,
                   "size": e.get("size") or os.path.getsize(e["path"])}
               for p, (e, w) in need.items()},
              open("needed.json", "w", encoding='utf-8'), indent=1, ensure_ascii=False)
