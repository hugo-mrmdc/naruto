"""Copie dans addons/naruto_content les fichiers requis qui viennent d'addons tiers."""
import json, os, sys
import gmaindex

# Ces addons restent des dépendances workshop : ils contiennent du Lua (DynaBase)
# ou servent de cible d'inclusion d'animations. Les recopier casserait le système.
KEEP_AS_WORKSHOP = {"2916561591", "848953359"}

DEST = gmaindex.GMOD + "/addons/naruto_content"
DATA = gmaindex.build("index.json")
INDEX = DATA["index"]
TITLES = DATA["titles"]

needed = json.load(open("needed.json", encoding='utf-8'))
dry = "--write" not in sys.argv

copied, skipped, total = [], [], 0
for path in sorted(needed):
    entry = INDEX.get(path)
    if not entry or entry.get("src") != "workshop":
        continue
    if entry["wsid"] in KEEP_AS_WORKSHOP:
        skipped.append((path, TITLES.get(entry["wsid"])))
        continue
    data = gmaindex.read(entry)
    total += len(data)
    out = os.path.join(DEST, path.replace("/", os.sep))
    copied.append((path, entry["wsid"], len(data)))
    if not dry:
        os.makedirs(os.path.dirname(out), exist_ok=True)
        with open(out, 'wb') as f:
            f.write(data)

sources = sorted({TITLES.get(w) or w for _, w, _ in copied})

if not dry:
    with open(os.path.join(DEST, "addon.json"), 'w', encoding='utf-8') as f:
        json.dump({
            "title": "Naruto RP - Contenu",
            "type": "servercontent",
            "tags": ["roleplay", "scenic"],
            "ignore": ["*.psd", "*.vcproj", "*.svn*"],
        }, f, indent=1, ensure_ascii=False)
    with open(os.path.join(DEST, "SOURCES.txt"), 'w', encoding='utf-8') as f:
        f.write("Contenu regroupé pour le serveur Naruto RP.\n\n")
        f.write("Fichiers extraits des addons workshop suivants (crédit à leurs auteurs) :\n")
        for s in sources:
            f.write("  - " + s + "\n")
        f.write("\nRestent nécessaires en abonnement workshop :\n")
        f.write("  - [wOS] DynaBase - Dynamic Animation Manager (2916561591)\n")
        f.write("  - [wOS] Animation Extension - Blade Symphony (848953359)\n")

print(("SIMULATION" if dry else "COPIE"), "->", DEST)
print("%d fichiers, %.2f Mo" % (len(copied), total / 1048576))
for s in sources:
    n = sum(1 for _, w, _ in copied if (TITLES.get(w) or w) == s)
    print("   %4d depuis %s" % (n, s))
print("gardés en workshop : %d fichiers (%s)" % (len(skipped), ", ".join(sorted({s or "?" for _, s in skipped}))))
