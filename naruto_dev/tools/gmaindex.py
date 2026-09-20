"""Index des fichiers fournis par les GMA workshop + les fichiers en vrac de garrysmod."""
import struct, os, glob, json

GMOD = "C:/Program Files (x86)/Steam/steamapps/common/GarrysMod/garrysmod"
WORKSHOP = "C:/Program Files (x86)/Steam/steamapps/workshop/content/4000"
ADDON = GMOD + "/addons/naruto_dev"


def gma_filelist(path):
    """Retourne (titre, [(nom, offset_donnees, taille)]) sans lire tout le fichier."""
    with open(path, 'rb') as f:
        head = f.read(8 * 1024 * 1024)
    if head[:4] != b'GMAD':
        return None, []
    p = 5 + 16
    while True:
        e = head.index(b'\0', p)
        s = head[p:e]
        p = e + 1
        if not s:
            break
    vals = []
    for _ in range(3):
        e = head.index(b'\0', p)
        vals.append(head[p:e].decode('utf-8', 'replace'))
        p = e + 1
    p += 4
    entries = []
    while True:
        num = struct.unpack_from('<I', head, p)[0]
        p += 4
        if num == 0:
            break
        e = head.index(b'\0', p)
        name = head[p:e].decode('utf-8', 'replace')
        p = e + 1
        size = struct.unpack_from('<q', head, p)[0]
        p += 12
        entries.append((name, size))
    out = []
    off = p
    for name, size in entries:
        out.append((name, off, size))
        off += size
    return vals[0], out


def disabled_ids():
    path = GMOD + "/cfg/addonnomount.txt"
    ids = set()
    if os.path.exists(path):
        for line in open(path, encoding='utf-8', errors='replace'):
            parts = line.replace('"', ' ').split()
            for tok in parts:
                if tok.isdigit() and len(tok) > 6:
                    ids.add(tok)
    return ids


def build(cache_path=None):
    if cache_path and os.path.exists(cache_path):
        with open(cache_path, encoding='utf-8') as f:
            return json.load(f)

    index = {}   # chemin minuscule -> {"src": ..., "gma":..., "off":..., "size":..., "wsid":..., "title":...}
    titles = {}

    # fichiers en vrac : garrysmod/ puis l'addon (priorité la plus forte en dernier)
    for base, label in ((GMOD, "garrysmod (vrac)"), (GMOD + "/addons/naruto_content", "addon naruto_content"), (ADDON, "addon naruto_dev")):
        for sub in ("models", "materials", "particles", "sound"):
            root = os.path.join(base, sub)
            for dirpath, _, files in os.walk(root):
                for fn in files:
                    full = os.path.join(dirpath, fn)
                    rel = os.path.relpath(full, base).replace("\\", "/").lower()
                    index[rel] = {"src": label, "path": full}

    for gma in sorted(glob.glob(WORKSHOP + "/*/*.gma") + glob.glob(WORKSHOP + "/*/*.bin")):
        wsid = os.path.basename(os.path.dirname(gma))
        try:
            title, entries = gma_filelist(gma)
        except Exception:
            continue
        if not entries:
            continue
        titles[wsid] = title
        for name, off, size in entries:
            key = name.lower()
            if key in index and index[key].get("path"):
                continue
            index[key] = {"src": "workshop", "gma": gma, "off": off, "size": size,
                          "wsid": wsid, "title": title}

    data = {"index": index, "titles": titles, "disabled": sorted(disabled_ids())}
    if cache_path:
        with open(cache_path, 'w', encoding='utf-8') as f:
            json.dump(data, f)
    return data


def read(entry):
    if entry.get("path"):
        return open(entry["path"], 'rb').read()
    with open(entry["gma"], 'rb') as f:
        f.seek(entry["off"])
        return f.read(entry["size"])


if __name__ == "__main__":
    d = build("index.json")
    print(len(d["index"]), "fichiers indexés,", len(d["titles"]), "addons workshop")
