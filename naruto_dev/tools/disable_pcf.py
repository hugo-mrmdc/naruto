"""Désactive (sans les supprimer) des systèmes de particules d'un .pcf : leur émission est mise à zéro.

    python disable_pcf.py ../particles/solve_raiton.pcf solve_raiton_area_hit

Tous les systèmes dont le nom commence par le préfixe donné n'émettent plus rien ; la structure du fichier ne change pas
(les valeurs sont modifiées sur place). Une copie de l'original est gardée dans tools/original_particles/ (jamais
écrasée) : on repart toujours de l'original.
"""
import os, shutil, struct, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from scale_pcf import parse


def main():
    chemin, prefixe = sys.argv[1], sys.argv[2]
    sauvegarde = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'original_particles', os.path.basename(chemin))
    if not os.path.exists(sauvegarde):
        shutil.copyfile(chemin, sauvegarde)
        print('sauvegarde :', sauvegarde)
    d = bytearray(open(sauvegarde, 'rb').read())
    elems = parse(bytes(d))

    systemes = [e for e in elems if e['type'] == 'DmeParticleSystemDefinition' and e['name'].startswith(prefixe)]
    if not systemes:
        sys.exit('aucun système dont le nom commence par ' + prefixe)

    n = 0
    for s in systemes:
        liste = s['attrs'].get('emitters', (0, []))[1] or []
        for x in liste:
            if not (isinstance(x, tuple) and x[0] == 'elem' and x[1] >= 0):
                continue
            em = elems[x[1]]
            for nom, (t, off) in em['offs'].items():
                if nom == 'emission_rate' and t == 3:
                    struct.pack_into('<f', d, off, 0.0); n += 1
                elif nom in ('num_to_emit', 'num_to_emit_minimum') and t == 2:
                    struct.pack_into('<i', d, off, 0); n += 1
    open(chemin, 'wb').write(d)
    print('%d systèmes désactivés (%d valeurs) dans %s' % (len(systemes), n, chemin))


if __name__ == '__main__':
    main()
