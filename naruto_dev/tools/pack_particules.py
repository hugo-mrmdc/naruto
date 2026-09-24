import sys, glob, os, re, shutil
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dmx import parse
B = "C:/Program Files (x86)/Steam/steamapps/"
GM = B + "common/GarrysMod/garrysmod/"
DEST = GM + "addons/naruto_content/materials/"

def index(bases):
    d = {}
    for base in bases:
        for root, _, fs in os.walk(base):
            rel = os.path.relpath(root, base).replace(os.sep, '/').lower()
            rel = '' if rel == '.' else rel + '/'
            for f in fs:
                d.setdefault((rel + f).lower(), os.path.join(root, f))
    return d

montes = index([GM + "materials"] + glob.glob(GM + "addons/*/materials"))
sources = index(glob.glob(B + "workshop/content/4000/*/*/materials"))

besoin = {}
for p in glob.glob(GM + "addons/naruto_dev/particles/*.pcf"):
    try: E = parse(p)[1]
    except Exception: continue
    for e in E:
        if e['type'] != 'DmeParticleSystemDefinition': continue
        m = e['attrs'].get('material', (0, ''))[1].replace(chr(92), '/').lower()
        if m.endswith('.vmt'): m = m[:-4]
        if m: besoin.setdefault(m, 0)
        besoin[m] = besoin.get(m, 0) + 1

copies, introuvables = [], []
for m in besoin:
    if m + '.vmt' in montes: continue
    src = sources.get(m + '.vmt')
    if not src: introuvables.append(m); continue
    # le .vmt + ses textures ($basetexture, $bumpmap...)
    fichiers = {m + '.vmt': src}
    for tex in set(re.findall(r'"\$[a-z]*texture[a-z0-9]*"\s+"([^"]+)"', open(src, encoding='utf-8', errors='replace').read().lower())):
        tex = tex.replace(chr(92), '/').lower()
        if tex + '.vtf' in sources: fichiers[tex + '.vtf'] = sources[tex + '.vtf']
    for rel, s in fichiers.items():
        d = DEST + rel
        os.makedirs(os.path.dirname(d), exist_ok=True)
        if not os.path.exists(d): shutil.copy2(s, d); copies.append(rel)
print(len(copies), 'fichiers copiés dans naruto_content')
print(len(introuvables), 'toujours introuvables :', sorted(introuvables)[:15])
