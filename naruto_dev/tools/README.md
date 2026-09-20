# Outils de contenu

Scripts Python (3.x) pour savoir quels fichiers tes modèles utilisent réellement,
et regrouper ceux qui viennent d'addons tiers dans `addons/naruto_content`.

À lancer depuis ce dossier.

## 1. Lister les modèles utilisés

```bash
grep -rhoiE "models/[a-z0-9_/.-]+\.mdl" ../lua ../gamemodes --include=*.lua | tr 'A-Z' 'a-z' | sort -u > models.txt
```

## 2. Résoudre les dépendances

```bash
python deps.py models.txt
```

Construit un index de tous les fichiers fournis par tes addons workshop (`index.json`,
mis en cache : supprime-le après un changement d'abonnement), lit chaque `.mdl`
pour en extraire les matériaux, suit les `.vmt` jusqu'aux `.vtf`, puis affiche qui
fournit quoi et ce qui manque. Écrit la liste complète dans `needed.json`.

Les modèles Half-Life 2 / GMod de base apparaissent comme « manquants » : ils sont
dans les `.vpk` du jeu, que ces scripts ne lisent pas. C'est normal.

## 3. Regrouper le contenu tiers

```bash
python pack.py
```

Simulation. Ajoute `--write` pour copier réellement dans `addons/naruto_content`.

wOS DynaBase et l'extension Blade Symphony sont volontairement exclus : ils
contiennent du Lua et servent de base d'animation. Ils restent des abonnements
workshop obligatoires.

`SOURCES.txt` est généré dans l'addon et crédite les addons d'origine. Ne publie ce
contenu que si tu as le droit de le redistribuer.
