"""Adapte les coiffures au crâne des visages models/head/face_N.mdl.

Les coiffures (models/haire/*, models/hairs1_head) ont été modélisées pour l'ancienne
tête models/head_03.mdl ; le crâne des visages face_N est plus haut. On transforme les
sommets des .vvd dans le repère de l'os de la tête : étirement + décalage mesurés en
superposant les deux crânes (voir TRANSFO).

- models/haire/*        : .vvd modifiés sur place (les originaux vont dans _originaux/haire_vvd/,
                          et sont relus à chaque lancement : relancer ne cumule pas la transformation)
- models/hairs1_head    : copie adaptée -> models/hairs1_face.* (l'original ne change pas)

Les coiffures de models/haire/ ne vont donc plus sur l'ancienne tête (le menu le gère).
À lancer depuis ce dossier : python ajuster_cheveux.py
"""
import glob, os, shutil, struct
import numpy as np

RACINE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SAUVEGARDE = os.path.join(RACINE, "_originaux", "haire_vvd")

# Repère de l'os "ValveBiped.Bip01_Head1" : sommet' = sommet * ECHELLE + DECALAGE
# (ajustement du crâne head_03 -> face_N, erreur moyenne 0,19 unité contre 0,51 avant)
ECHELLE = np.array([1.194, 0.963, 1.006])
DECALAGE = np.array([0.13, -0.588, -0.008])


def chaine(d, o):
    return d[o:d.index(b"\0", o)].decode("latin1")


def repere_tete(mdl):
    """Matrice 4x4 monde <- local de l'os de la tête, à la pose de référence du .mdl."""
    d = open(mdl, "rb").read()
    nb, bi = struct.unpack_from("<ii", d, 156)
    for i in range(nb):
        o = bi + i * 216
        if chaine(d, o + struct.unpack_from("<i", d, o)[0]) == "ValveBiped.Bip01_Head1":
            m = np.array(struct.unpack_from("<12f", d, o + 96)).reshape(3, 4)   # pose -> os
            return np.linalg.inv(np.vstack([m, [0, 0, 0, 1]]))
    raise ValueError("pas d'os de tête : " + mdl)


def transformer(vvd_source, vvd_sortie, mdl):
    H = repere_tete(mdl)
    Hi = np.linalg.inv(H)
    R, Ri = H[:3, :3], Hi[:3, :3]

    d = bytearray(open(vvd_source, "rb").read())
    n = struct.unpack_from("<i", d, 16)[0]                  # sommets du LOD 0 (= tous)
    debut, tangentes = struct.unpack_from("<ii", d, 56)     # vertexDataStart, tangentDataStart
    v = np.frombuffer(d, dtype=np.uint8, count=n * 48, offset=debut).reshape(n, 48).copy()

    pos = np.frombuffer(v[:, 16:28].tobytes(), "<f4").reshape(n, 3).astype(np.float64)
    nor = np.frombuffer(v[:, 28:40].tobytes(), "<f4").reshape(n, 3).astype(np.float64)
    loc = pos @ Ri.T + Hi[:3, 3]                             # monde -> local
    loc = loc * ECHELLE + DECALAGE
    pos2 = loc @ R.T + H[:3, 3]                              # local -> monde

    def direction(x, f):   # normales : / échelle ; tangentes : * échelle
        x = (x @ Ri.T) * f @ R.T
        return x / np.maximum(np.linalg.norm(x, axis=1, keepdims=True), 1e-9)

    v[:, 16:28] = np.frombuffer(pos2.astype("<f4").tobytes(), np.uint8).reshape(n, 12)
    v[:, 28:40] = np.frombuffer(direction(nor, 1 / ECHELLE).astype("<f4").tobytes(), np.uint8).reshape(n, 12)
    d[debut:debut + n * 48] = v.tobytes()

    if tangentes:
        t = np.frombuffer(d, dtype="<f4", count=n * 4, offset=tangentes).reshape(n, 4).astype(np.float64)
        t[:, :3] = direction(t[:, :3], ECHELLE)
        d[tangentes:tangentes + n * 16] = t.astype("<f4").tobytes()

    open(vvd_sortie, "wb").write(d)


def main():
    os.makedirs(SAUVEGARDE, exist_ok=True)
    fait = 0
    for mdl in sorted(glob.glob(os.path.join(RACINE, "models", "haire", "*", "*.mdl"))):
        vvd = mdl[:-4] + ".vvd"
        if not os.path.exists(vvd):
            continue
        copie = os.path.join(SAUVEGARDE, os.path.basename(vvd))
        if not os.path.exists(copie):
            shutil.copy2(vvd, copie)                         # original, une seule fois
        try:
            transformer(copie, vvd, mdl)
        except ValueError as e:   # coiffure sans os de tête : laissée telle quelle (exclue du menu)
            print("ignorée :", os.path.basename(mdl), "-", e)
            continue
        fait += 1
    print(fait, "coiffures adaptées (originaux dans _originaux/haire_vvd)")

    # coiffure d'origine : copie adaptée pour les visages
    src = os.path.join(RACINE, "models", "hairs1_head")
    dst = os.path.join(RACINE, "models", "hairs1_face")
    for ext in (".mdl", ".dx80.vtx", ".dx90.vtx", ".phy"):
        if os.path.exists(src + ext):
            shutil.copy2(src + ext, dst + ext)
    transformer(src + ".vvd", dst + ".vvd", src + ".mdl")
    print("models/hairs1_face.* créé")


if __name__ == "__main__":
    main()
