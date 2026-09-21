# Génère les yeux à iris réduit de materials/models/naruto_dev/yeux/ (utilisés par sv_yeux.lua).
#   python tools/yeux/reduire_yeux.py 0.7            -> écrit les 15 yeux (0.7 = iris réduit de 30 %, valeur actuelle : 0.8)
#   python tools/yeux/reduire_yeux.py 0.7 --apercu   -> apercu_yeux.png avant / après, sans rien écrire
# Puis relancer la map.
import sys, os
ICI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, ICI)
from PIL import Image
from vtf import lire
from ecrire_vtf import ecrire_vtf

FACTEUR = float(sys.argv[1]) if len(sys.argv) > 1 else 0.7
W = "C:/Program Files (x86)/Steam/steamapps/workshop/content/4000/3457349172/gmpublisher/materials/models/kaesar/solve/naruto_head/"
DEV = os.path.join(ICI, "..", "..") + "/"
SORTIE = DEV + "materials/models/naruto_dev/yeux/"

SOURCES = {   # nom de sortie -> texture d'origine
    "normal":         W + "mi_chr_eyes_wthinl_01.vtf",
    "sharingan1":     W + "eyes_skin_geams/1_tomoe_eye_left.vtf",
    "sharingan2":     W + "eyes_skin_geams/2_tomoe_eye.vtf",
    "sharingan3":     W + "eyes_skin_geams/3_tomoe_eye.vtf",
    "byakugan":       W + "eyes_skin_geams/byakugan_active_eye.vtf",
    "mangekyou":      W + "eyes_skin_geams/eternel_mangekyou_eye.vtf",
    "itachi":         W + "eyes_skin_geams/tsukuyomi_itachi_eye.vtf",
    "sasuke":         W + "eyes_skin_geams/amaterasu_sasuke_eye.vtf",
    "obito":          W + "eyes_skin_geams/kamui_obito_eye.vtf",
    "shisui":         W + "eyes_skin_geams/kotoamatsukami_shisui_eye.vtf",
    "madara":         W + "eyes_skin_geams/jikan_madara_eye.vtf",
    "mugen":          W + "eyes_skin_geams/mugen_eye.vtf",
    "ermite_crapaud": W + "eyes_skin_geams/ermite_crapeau_eye.vtf",
    "ermite_serpent": W + "eyes_skin_geams/ermite_snake_eye.vtf",
}

def blanc(img):
    # couleur du blanc de l'œil : moyenne des 4 coins
    w, h = img.size
    px = [img.getpixel(p) for p in ((2, 2), (w - 3, 2), (2, h - 3), (w - 3, h - 3))]
    return tuple(sum(c[i] for c in px) // 4 for i in range(3))

PAS_REDUITS = {"shisui"}   # iris déjà tout petit dans la texture d'origine

def reduire(img, nom=None):
    img = img.convert('RGB'); w, h = img.size
    if nom in PAS_REDUITS: return img
    fond = Image.new('RGB', (w, h), blanc(img))
    nw, nh = round(w * FACTEUR), round(h * FACTEUR)
    petit = img.resize((nw, nh), Image.LANCZOS)
    fond.paste(petit, ((w - nw) // 2, (h - nh) // 2))
    return fond

images = {n: lire(p) for n, p in SOURCES.items()}
# Ketsuryugan : refait depuis ton image d'origine (meilleure qualité qu'une texture déjà réduite)
k = Image.open(os.path.join(ICI, 'ketsuryugan_source.webp')).convert('RGBA')
k = k.crop(k.getchannel('A').point(lambda a: 255 if a > 20 else 0).getbbox())
D = round(124 * FACTEUR)
tex = Image.new('RGBA', (256, 256), (241, 243, 241, 255))
tex.alpha_composite(k.resize((D, D), Image.LANCZOS), ((256 - D) // 2, (256 - D) // 2))

resultats = {n: reduire(i, n) for n, i in images.items()}
resultats["ketsuryugan"] = tex.convert('RGB')

if '--apercu' in sys.argv:
    avant = dict(images); avant["ketsuryugan"] = k   # image source
    noms = list(resultats)
    feuille = Image.new('RGB', (len(noms) * 130, 270), (40, 40, 40))
    for i, n in enumerate(noms):
        feuille.paste(avant[n].convert('RGB').resize((128, 128)), (i * 130, 0))
        feuille.paste(resultats[n].resize((128, 128)), (i * 130, 140))
    feuille.save(os.path.join(ICI, 'apercu_yeux.png')); print('aperçu écrit')
else:
    os.makedirs(SORTIE, exist_ok=True)
    vmt = open(W + "eyes_skin_geams/3_tomoe_eye.vmt", encoding='utf-8', errors='replace').read()
    for n, img in resultats.items():
        ecrire_vtf(img, SORTIE + n + ".vtf")
        open(SORTIE + n + ".vmt", 'w', encoding='utf-8', newline='\n').write(
            vmt.replace("models/kaesar/solve/naruto_head/eyes_skin_geams/3_tomoe_eye", "models/naruto_dev/yeux/" + n))
    print(len(resultats), 'yeux écrits dans', SORTIE)
