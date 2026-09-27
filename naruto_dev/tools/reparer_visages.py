"""Répare les formes (flex) des visages models/head/face_N.mdl.

Les 28 visages contiennent les MÊMES données de formes (yeux, nez, mâchoire...), écrites pour
l'ordre des sommets de face_1. Mais leurs sommets sont rangés dans un autre ordre : sur la plupart,
une forme d'yeux se retrouve donc appliquée au nez, à la bouche ou au menton (pas aux yeux).

Ici, pour chaque visage 2..28, on retrouve pour chaque sommet le sommet de face_1 le plus proche
(même matériau, même position) et on lui donne les déplacements de celui-ci. Les données sont
ajoutées à la fin du .mdl (les anciennes restent, inutilisées). La forme de bouche propre à chaque
visage ("mouth_<nom>") n'est pas touchée.

Les .mdl d'origine sont copiés dans _originaux/head_mdl/ (relus à chaque lancement : relancer ne
cumule rien). À lancer depuis ce dossier : python reparer_visages.py
"""
import os, shutil, struct
import numpy as np

RACINE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
DOSSIER = os.path.join(RACINE, "models", "head")
SAUVEGARDE = os.path.join(RACINE, "_originaux", "head_mdl")
REFERENCE = 1
DISTANCE_MAX = 0.6          # au-delà, le sommet n'a pas de correspondant (géométrie en plus)
TAILLE_FLEX, TAILLE_MESH, TAILLE_MODELE, TAILLE_VERT = 60, 116, 148, 16


def chaine(d, o):
    return d[o:d.index(b"\0", o)].decode("latin1")


def lire(mdl, vvd):
    d = bytearray(open(mdl, "rb").read())
    dv = open(vvd, "rb").read()
    n, = struct.unpack_from("<i", dv, 16)
    debut, = struct.unpack_from("<i", dv, 56)
    a = np.frombuffer(dv, dtype=np.uint8, count=n * 48, offset=debut).reshape(n, 48)
    pos = np.frombuffer(a[:, 16:28].tobytes(), "<f4").reshape(-1, 3)
    uv = np.frombuffer(a[:, 40:48].tobytes(), "<f4").reshape(-1, 2)

    nt, ti = struct.unpack_from("<ii", d, 204)
    tex = [chaine(d, ti + i * 64 + struct.unpack_from("<i", d, ti + i * 64)[0]).lower() for i in range(nt)]
    nfd, fdi = struct.unpack_from("<ii", d, 260)
    noms = [chaine(d, fdi + i * 4 + struct.unpack_from("<i", d, fdi + i * 4)[0]) for i in range(nfd)]

    nbp, bpi = struct.unpack_from("<ii", d, 232)
    _, _, mi = struct.unpack_from("<iii", d, bpi + 4)        # bodypart "Face" : un seul modèle
    mo = bpi + mi
    nmesh, meshi = struct.unpack_from("<ii", d, mo + 72)
    meshes = {}
    for k in range(nmesh):
        so = mo + meshi + k * TAILLE_MESH
        mat, nvert, voff = struct.unpack_from("<iii", d, so)
        nfx, fxi = struct.unpack_from("<ii", d, so + 16)
        flex = []
        for f in range(nfx):
            fo = so + fxi + f * TAILLE_FLEX
            desc, = struct.unpack_from("<i", d, fo)
            nv, vi = struct.unpack_from("<ii", d, fo + 20)
            assert d[fo + 32] == 0, "déplacements de type wrinkle non gérés"
            lignes = np.frombuffer(bytes(d[fo + vi:fo + vi + nv * TAILLE_VERT]), dtype=np.uint8).reshape(nv, TAILLE_VERT)
            flex.append({"desc": desc, "nom": noms[desc], "struct": bytes(d[fo:fo + TAILLE_FLEX]), "lignes": lignes})
        meshes[tex[mat]] = {"so": so, "voff": voff, "nvert": nvert, "flex": flex}
    return d, pos, uv, meshes


def correspondance(pos_t, uv_t, pos_r, uv_r):
    """Pour chaque sommet de t : indice du plus proche dans r, et sa distance."""
    ft = np.hstack([pos_t, uv_t * 0.05])
    fr = np.hstack([pos_r, uv_r * 0.05])
    idx = np.empty(len(ft), int)
    dist = np.empty(len(ft))
    for a in range(0, len(ft), 512):
        d2 = ((ft[a:a + 512, None, :] - fr[None, :, :]) ** 2).sum(2)
        idx[a:a + 512] = d2.argmin(1)
        dist[a:a + 512] = np.sqrt(d2.min(1))
    return idx, dist


def reparer(n, ref):
    mdl = os.path.join(DOSSIER, "face_%d.mdl" % n)
    copie = os.path.join(SAUVEGARDE, "face_%d.mdl" % n)
    if not os.path.exists(copie):
        shutil.copy2(mdl, copie)                              # original, une seule fois

    d, pos, uv, meshes = lire(copie, os.path.join(DOSSIER, "face_%d.vvd" % n))
    d_r, pos_r, uv_r, meshes_r = ref

    for mat, m in meshes.items():
        r = meshes_r.get(mat)
        if not r or not r["flex"]:
            continue
        pt = pos[m["voff"]:m["voff"] + m["nvert"]]
        ut = uv[m["voff"]:m["voff"] + m["nvert"]]
        pr = pos_r[r["voff"]:r["voff"] + r["nvert"]]
        ur = uv_r[r["voff"]:r["voff"] + r["nvert"]]
        plus_proche, dist = correspondance(pt, ut, pr, ur)
        valide = dist < DISTANCE_MAX

        nouveaux = [f for f in m["flex"] if f["nom"].startswith("mouth_")]   # propre au visage : gardée
        for fr_ in r["flex"]:
            if fr_["nom"].startswith("mouth_"):
                continue
            # ligne de r par indice de sommet
            par_indice = {int(np.frombuffer(l[0:2].tobytes(), "<u2")[0]): l for l in fr_["lignes"]}
            lignes = []
            for j in np.nonzero(valide)[0]:
                l = par_indice.get(int(plus_proche[j]))
                if l is not None:
                    l = l.copy()
                    l[0:2] = np.frombuffer(struct.pack("<H", int(j)), dtype=np.uint8)
                    lignes.append(l)
            if lignes:
                nouveaux.append({"desc": fr_["desc"], "nom": fr_["nom"], "struct": fr_["struct"], "lignes": np.array(lignes)})
        nouveaux.sort(key=lambda f: f["desc"])

        # écriture à la fin du fichier : déplacements, puis tableau de structures
        while len(d) % 4:
            d.append(0)
        debuts = []
        for f in nouveaux:
            debuts.append(len(d))
            d += f["lignes"].tobytes()
        while len(d) % 4:
            d.append(0)
        table = len(d)
        d += b"\0" * (TAILLE_FLEX * len(nouveaux))
        for k, f in enumerate(nouveaux):
            fo = table + k * TAILLE_FLEX
            d[fo:fo + TAILLE_FLEX] = f["struct"]
            struct.pack_into("<ii", d, fo + 20, len(f["lignes"]), debuts[k] - fo)   # numverts, vertindex
        struct.pack_into("<ii", d, m["so"] + 16, len(nouveaux), table - m["so"])   # numflexes, flexindex

    struct.pack_into("<i", d, 76, len(d))                      # longueur du fichier
    open(mdl, "wb").write(d)


def main():
    os.makedirs(SAUVEGARDE, exist_ok=True)
    ref = lire(os.path.join(DOSSIER, "face_%d.mdl" % REFERENCE), os.path.join(DOSSIER, "face_%d.vvd" % REFERENCE))
    for n in range(1, 29):
        if n != REFERENCE:
            reparer(n, ref)
            print("face_%d réparé" % n)


if __name__ == "__main__":
    main()
