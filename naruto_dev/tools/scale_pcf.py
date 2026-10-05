"""Réduit (ou agrandit) la TAILLE d'un système de particules d'un .pcf, directement dans le fichier.

Une particule Source n'a pas d'échelle réglable depuis Lua : sa taille est écrite dans le .pcf. Ce script
multiplie, pour un système et tous ses sous-systèmes (noms qui commencent par le même préfixe), les valeurs
qui font sa taille : rayon des particules, échelle de rayon, distance d'apparition, vitesse (= étalement).
Les valeurs sont des nombres de même taille : on les modifie sur place, la structure du fichier ne change pas.

    python scale_pcf.py ../particles/patlick_atgsuiton.pcf shark_explo_pat 0.5

Une copie de l'original est gardée dans tools/original_particles/ (jamais écrasée : relancer le script ne
cumule donc pas les réductions, il repart toujours de l'original).
"""
import os, shutil, struct, sys

FLOATS = (
    "radius", "radius_min", "radius_max", "radius_start_scale", "radius_end_scale",
    "distance_min", "distance_max", "speed_min", "speed_max",
)
VECTEURS = (
    "speed_in_local_coordinate_system_min", "speed_in_local_coordinate_system_max",
    "distance_bias_absolute_value",
)


def parse(d):
    """Comme dmx.parse, mais retient aussi l'offset de chaque valeur d'attribut (pour la modifier sur place)."""
    p = d.index(b'\0') + 1
    ver = int(d[:p - 1].decode().strip().split('binary ')[1].split()[0])

    def i32():
        nonlocal p; v = struct.unpack_from('<i', d, p)[0]; p += 4; return v

    def cstr():
        nonlocal p; e = d.index(b'\0', p); s = d[p:e].decode('latin1'); p = e + 1; return s

    def i16():
        nonlocal p; v = struct.unpack_from('<h', d, p)[0]; p += 2; return v

    strings = []
    if ver >= 2:
        strings = [cstr() for _ in range(i16())]

    def sidx():
        return strings[i16()] if ver >= 2 else cstr()

    elems = []
    for _ in range(i32()):
        t = sidx(); name = sidx() if ver >= 4 else cstr()
        p += 16
        elems.append({'type': t, 'name': name, 'attrs': {}, 'offs': {}})

    def val(t):
        nonlocal p
        if t == 1:
            v = i32(); return ('elem', v) if v != -2 else ('ext', cstr())
        if t == 2: return i32()
        if t == 3: v = struct.unpack_from('<f', d, p)[0]; p += 4; return v
        if t == 4: v = d[p]; p += 1; return bool(v)
        if t == 5: return cstr() if ver < 4 else sidx()
        if t == 6: n = i32(); v = d[p:p + n]; p += n; return v
        if t == 7: return i32() / 10000
        if t == 8: v = tuple(d[p:p + 4]); p += 4; return v
        sizes = {9: 2, 10: 3, 11: 4, 12: 3, 13: 4, 14: 16}
        if t in sizes:
            n = sizes[t]; v = struct.unpack_from('<%df' % n, d, p); p += 4 * n; return v
        if 15 <= t <= 28:
            n = i32(); sub = t - 14
            if sub == 5: return [cstr() for _ in range(n)]
            return [val(sub) for _ in range(n)]
        raise ValueError('type inconnu %d' % t)

    for e in elems:
        for _ in range(i32()):
            an = sidx(); t = d[p]; p += 1
            debut = p
            e['attrs'][an] = (t, val(t))
            e['offs'][an] = (t, debut)
    return elems


def main():
    chemin, prefixe, facteur = sys.argv[1], sys.argv[2], float(sys.argv[3])
    sauvegarde = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'original_particles', os.path.basename(chemin))
    if not os.path.exists(sauvegarde):
        shutil.copyfile(chemin, sauvegarde)
        print('sauvegarde :', sauvegarde)
    d = bytearray(open(sauvegarde, 'rb').read())   # on part TOUJOURS de l'original
    elems = parse(bytes(d))

    systemes = [e for e in elems if e['type'] == 'DmeParticleSystemDefinition' and e['name'].startswith(prefixe)]
    if not systemes:
        sys.exit('aucun système dont le nom commence par ' + prefixe)

    def refs(v):
        return [x[1] for x in v if isinstance(x, tuple) and x[0] == 'elem' and x[1] >= 0] if isinstance(v, list) else []

    # le système + ses initializers / operators / emitters / forces (les sous-systèmes sont dans la liste `systemes`)
    cibles = []
    for s in systemes:
        cibles.append(s)
        for cle in ('initializers', 'operators', 'emitters', 'forces', 'constraints'):
            for i in refs(s['attrs'].get(cle, (0, []))[1]):
                cibles.append(elems[i])

    n = 0
    for e in cibles:
        for nom, (t, off) in e['offs'].items():
            # "Remap Initial Scalar" vers le rayon (champ de sortie 3) : sa valeur de sortie EST la taille (ex. fissures au sol)
            remap_rayon = e['attrs'].get('output field', (0, None))[1] == 3 and nom in ('output minimum', 'output maximum')
            if (nom in FLOATS or remap_rayon) and t == 3:
                v = struct.unpack_from('<f', d, off)[0]
                struct.pack_into('<f', d, off, v * facteur); n += 1
            elif nom in VECTEURS and t == 10:
                v = struct.unpack_from('<3f', d, off)
                struct.pack_into('<3f', d, off, *[x * facteur for x in v]); n += 1
    open(chemin, 'wb').write(d)
    print('%d systèmes, %d valeurs multipliées par %s dans %s' % (len(systemes), n, facteur, chemin))


if __name__ == '__main__':
    main()
