"""Agrandit un système de particules d'un .pcf (DMX binaire v2), en place.

Usage : python pcfscale.py <original.pcf> <sortie.pcf> <nom_du_systeme> <facteur>

Seules les valeurs sont modifiées (même taille en octets) : la structure du
fichier ne bouge pas. Le système visé ET ses enfants sont agrandis.
Toujours partir de l'ORIGINAL : relancer ne cumule pas les agrandissements.
"""
import struct, sys

src, dst, cible, facteur = sys.argv[1], sys.argv[2], sys.argv[3], float(sys.argv[4])
d = bytearray(open(src, 'rb').read())
p = d.index(b'\n') + 1
if d[p] == 0:
    p += 1

def i32():
    global p
    v = struct.unpack_from('<i', d, p)[0]; p += 4; return v

def cstr():
    global p
    e = d.index(b'\0', p); s = d[p:e].decode('utf-8', 'replace'); p = e + 1; return s

save = p
n = struct.unpack_from('<h', d, p)[0]
if 0 < n < 5000:
    p += 2
else:
    p = save; n = i32()
strings = [cstr() for _ in range(n)]

def sidx():
    global p
    v = struct.unpack_from('<h', d, p)[0]; p += 2; return strings[v]

nel = i32()
elements = []
for _ in range(nel):
    typ = sidx(); name = cstr(); p += 16
    elements.append({'type': typ, 'name': name, 'attrs': {}})

SIZES = {2: 4, 3: 4, 4: 1, 7: 4, 8: 4, 9: 8, 10: 12, 11: 16, 12: 12, 13: 16}
FMT = {2: '<i', 3: '<f', 4: '<B', 7: '<i', 8: '<4B', 9: '<2f', 10: '<3f', 11: '<4f', 12: '<3f', 13: '<4f'}

def value(t):
    """renvoie (valeur, offset, type)"""
    global p
    if t == 1:
        return (('elem', i32()), None, t)
    if t == 5:
        return (cstr(), None, t)
    if t == 6:
        n = i32(); p += n; return (None, None, t)
    if t in FMT:
        off = p
        v = struct.unpack_from(FMT[t], d, p); p += SIZES[t]
        return ((v[0] if len(v) == 1 else v), off, t)
    if t == 14:
        p += 64; return (None, None, t)
    if t >= 15:
        base = t - 14
        n = i32()
        if base == 1:
            return ([('elem', i32()) for _ in range(n)], None, t)
        if base == 5:
            return ([cstr() for _ in range(n)], None, t)
        if base == 6:
            for _ in range(n):
                m = i32(); p += m
            return (None, None, t)
        out = [value(base)[0] for _ in range(n)]
        return (out, None, t)
    raise ValueError(t)

for el in elements:
    na = i32()
    for _ in range(na):
        name = sidx()
        t = d[p]; p += 1
        el['attrs'][name] = value(t)

# --- éléments à modifier : le système, ses enfants (récursif) et tous leurs opérateurs
racines = [i for i, e in enumerate(elements) if e['name'] == cible and e['type'] == 'DmeParticleSystemDefinition']
assert racines, "système introuvable : " + cible

definitions, operateurs = [], []
def parcourir(idx):
    if idx in definitions: return
    definitions.append(idx)
    el = elements[idx]
    for groupe in ('emitters', 'initializers', 'operators', 'renderers', 'forces', 'constraints'):
        v = el['attrs'].get(groupe, (None,))[0] or []
        for ref in v:
            operateurs.append(ref[1])
    for ref in (el['attrs'].get('children', (None,))[0] or []):
        enfant = elements[ref[1]]
        cdef = enfant['attrs'].get('child', (None,))[0]
        if cdef: parcourir(cdef[1])
for r in racines: parcourir(r)

# --- attributs de taille (en unités) à multiplier
FLOTTANTS = {"radius", "distance_min", "distance_max", "speed_min", "speed_max",
             "radius_min", "radius_max", "emission_rate"}
VECTEURS = {"bounding_box_min", "bounding_box_max",
            "speed_in_local_coordinate_system_min", "speed_in_local_coordinate_system_max",
            "offset min", "offset max", "gravity"}
ENTIERS = {"max_particles"}   # plus grand = plus de particules pour garder la densité

modifs = 0
for idx in definitions + operateurs:
    el = elements[idx]
    oscille_rayon = el['attrs'].get('oscillation field', (None,))[0] == 3
    for nom, (val, off, t) in el['attrs'].items():
        if off is None: continue
        if t == 3 and (nom in FLOTTANTS or (oscille_rayon and nom in ("oscillation rate min", "oscillation rate max"))):
            struct.pack_into('<f', d, off, val * facteur); modifs += 1
        elif t == 10 and nom in VECTEURS:
            struct.pack_into('<3f', d, off, *(c * facteur for c in val)); modifs += 1
        elif t == 2 and nom in ENTIERS:
            struct.pack_into('<i', d, off, int(round(val * facteur))); modifs += 1

open(dst, 'wb').write(d)
print("systèmes agrandis :", [elements[i]['name'] for i in definitions])
print("valeurs modifiées :", modifs, "| facteur :", facteur)
