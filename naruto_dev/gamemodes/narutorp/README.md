# Naruto RP — gamemode Garry's Mod

Gamemode RP ninja modulaire, dérivé de **sandbox**, écrit en GLua (syntaxe Lua 5.1 standard).
Emplacement : `garrysmod/addons/naruto_dev/gamemodes/narutorp/` (un addon peut contenir un gamemode).

Lancement : menu principal → gamemode **Naruto RP**, ou `+gamemode narutorp` sur un serveur dédié.

---

## 1. Architecture

```
gamemodes/narutorp/
├── narutorp.txt                     infos du gamemode (base sandbox)
├── entities/
│   ├── weapons/nrp_hands.lua        mains ninja (attaques légère / lourde)
│   └── entities/                    mannequin, mur de terre, bûche de substitution,
│                                    objet au sol, objet de mission, PNJ mission, marchand
└── gamemode/
    ├── shared.lua / init.lua / cl_init.lua   points d'entrée + chargeur
    ├── core/        socle technique (aucune règle de jeu)
    ├── config/      équilibrage et contenu (données uniquement)
    ├── modules/     logique de jeu, un dossier par domaine
    └── ui/          HUD et interfaces (client)
```

### Chargement

1. `core/` dans l'ordre de `NRP.CoreFiles`
2. `config/` (fichiers sans préfixe = partagés, `sv_` = serveur uniquement)
3. `modules/` dans l'ordre de `NRP.ModuleOrder`, puis tout dossier supplémentaire
4. `ui/core/` puis les autres dossiers de `ui/`

Préfixes : `sv_` serveur, `cl_` client (envoyé automatiquement), `sh_` partagé.
Dans un dossier : sans préfixe → `sh_` → `sv_` → `cl_`, puis les sous-dossiers.
**Ajouter un module = créer un dossier dans `modules/`** : il est chargé sans toucher au cœur.

### Core

| Fichier | Rôle |
|---|---|
| `sh_util.lua` | logs, formatage, recherche de joueur, compensation de latence sûre |
| `sh_registry.lua` | registres génériques (`NRP.CreateRegistry`) utilisés pour tout le contenu |
| `sh_net.lua` | réseau : limite de débit par joueur, taille max, permission, `pcall`, expulsion en cas d'abus |
| `sh_permissions.lua` | permissions : CAMI (ULX/SAM) → groupes de la config → grade ninja |
| `sh_notify.lua` | notifications, messages de chat colorés, annonces |
| `sh_cooldowns.lua` | cooldowns autoritaires, envoyés au seul joueur concerné |
| `sh_keys.lua` | touches configurables (convars USERINFO lues par le serveur) |
| `sv_commands.lua` | commandes `!cmd` / `/cmd` / `nrp cmd` avec arguments typés et permissions |

### Modules

| Module | Rôle | Dépend de |
|---|---|---|
| `database` | SQLite ou MySQLOO, API asynchrone unique, schéma déclaratif + migrations, journal | core |
| `character` | création, champs persistants extensibles, sauvegarde différentielle, synchro, affinités | database |
| `progression` | XP, niveaux, points, statistiques dérivées + modificateurs, grades, examens | character |
| `chakra` | chakra et endurance extrapolés côté client, drains, concentration | progression |
| `combat` | pipeline de dégâts, statuts, garde/parade, esquive, dash, substitution, projectiles, duels | chakra |
| `jutsu` | registre, conditions, incantation serveur, archetypes | combat |
| `clans` | clans, arbre de progression, passifs | jutsu |
| `dojutsu` | stades, activation, drain, yeux, vision | clans, chakra |
| `inventory` | objets, équipement, poids, lancers, objets au sol, boutique, échanges | progression, combat |
| `missions` | rangs D→S, 8 types, PNJ, groupes, points par carte, récompenses | inventory, villages |
| `villages` | relations, guerres, réputation, déserteurs, primes, Bingo Book, spawns | character |
| `admin` | commandes et panneau, inspection, événements RP, entités persistantes | tous |

Le module `combat` est chargé avant `jutsu` car les jutsu utilisent son pipeline de dégâts et ses projectiles.
Les modules communiquent surtout par **hooks** (`NRP.CharacterLoaded`, `NRP.LevelUp`, `NRP.ScaleDamage`,
`NRP.PostDamage`, `NRP.CanHarm`, `NRP.StatsUpdated`, `NRP.ResourceDepleted`, `NRP.ClanChanged`…).

---

## 2. Sécurité et performances

- Le client n'envoie que des **intentions** (numéro d'emplacement, identifiant d'objet, cible visée).
  Dégâts, chakra, cooldowns, conditions, achats, échanges et statistiques sont **recalculés côté serveur**.
- Chaque message reçu passe par `NRP.Net.Receive` : limite de débit, taille maximale, permission,
  personnage chargé, `pcall`. Les abus répétés entraînent une expulsion (`NRP.Config.Net`).
- Le panneau admin n'a aucun pouvoir propre : il exécute des commandes dont la permission est revérifiée.
- Aucune table arbitraire n'est acceptée depuis un client ; les chaînes sont bornées.
- **Pas de Think serveur permanent** : la régénération est calculée à la demande et extrapolée par le client ;
  l'épuisement d'un drain est programmé par un timer à l'instant exact.
- Projectiles sans entité : un hook `Tick` n'existe que tant qu'un projectile vole ; 2 messages réseau par projectile.
- Données publiques en NW2 (nom, village, grade…), données privées envoyées au seul propriétaire,
  regroupées par tick. Sauvegarde des seuls champs modifiés.
- Côté client : listes de cibles (noms au-dessus des têtes, vision dojutsu, flair) rafraîchies par timer, pas à chaque frame.
  Seule exception : un petit `Think` client détecte 2 touches (menu, lancement), car `PlayerButtonDown`
  n'est pas appelé côté client en solo.

---

## 3. Commandes et touches

Touches par défaut (modifiables dans **Menu → PERSONNAGE**) :

| Action | Touche | Action | Touche |
|---|---|---|---|
| Menu principal | F3 | Attaque légère / lourde | Clic gauche / droit |
| Lancer le jutsu | Clic molette | Choisir un emplacement | 1 à 6 / molette |
| Bloquer (maintenir) | C | Esquive | Z |
| Dash | Alt gauche | Substitution | X |
| Lancer l'outil équipé | H | Concentrer le chakra | M |
| Dojutsu | P | | |

Ces touches évitent celles des techniques de `lua/autorun` (F, G, R, T, I, N, J, K, B, L, E, O, V, F4).

Les joueurs ayant le sandbox maintiennent **Maj** + chiffre pour changer d'arme.

`!help` (ou `nrp help` en console) liste les commandes accessibles. Pour cibler soi-même : `moi` (ex. `!givexp moi 500`). Principales :

- Joueurs : `!duel`, `!exam join`, `!mission leave|invite|start`, `!event join`, `!deserter`, `!clans`, `!ranks`
- Responsables RP : `!promote`, `!exam open|pass|fail|close`, `!event start|stop|desc|pos|reward`
- Admin : `!givexp`, `!setlevel`, `!statpoints`, `!resetstats`, `!setrank`, `!giveryo`, `!setryo`, `!setclan`,
  `!clanpoints`, `!addaffinity`, `!removeaffinity`, `!primaryaffinity`, `!givejutsu`, `!takejutsu`, `!setdojutsu`,
  `!giveitem`, `!takeitem`, `!startmission`, `!endmission`, `!relation`, `!setvillage`, `!setdeserter`, `!rep`,
  `!bounty`, `!inspect`, `!inspectid`, `!logs`, `!revive`, `!rename`, `!wipechar`, `!dbstatus`, `!saveall`
- Carte : `!spawn add <village>`, `!mpoint add <tag> [nom]`, `!missionnpc <village|all>`, `!shopnpc <boutique>`,
  `!dummy`, `!persist`, `!unpersist`

---

## 4. Étendre le gamemode

- **Jutsu** : une entrée dans `config/jutsu.lua` (archetypes : projectile, aoe, cone, strike, dash_strike, wall,
  buff, heal, genjutsu, bind, teleport). Comportement unique : `OnCast = function(ply, jutsu, ctx) end`.
  Nouvel archetype : `NRP.Jutsu.RegisterArchetype`. Nouvel effet visuel : `NRP.FX.Register` (client).
- **Clan** : `config/clans.lua` (bonus, passifs, arbre, dojutsu). Nouveau passif : `NRP.Passives.Registry:Register`.
- **Dojutsu** : `config/dojutsu.lua`.
- **Objet / boutique** : `config/items.lua`.
- **Mission** : `config/missions.lua` ; nouveau type : `NRP.Missions.RegisterType` dans `modules/missions/types/`.
- **Village / relation** : `config/villages.lua`.
- **Statut** : `NRP.Status.Registry:Register` (`modules/combat/sh_status.lua`).
- **Donnée de personnage** : `NRP.Char.RegisterField("maCle", { type = "json", default = {} })` —
  la colonne SQL est ajoutée automatiquement au démarrage suivant.
- **Onglet de menu** : `NRP.UI.RegisterTab("id", { name, order, build, refreshOn })`.
- **Icônes** : champ `icon = "chemin/material.png"` ; sans fichier, une pastille avec initiales est affichée.

---

## 5. Procédures de test

Préparation : lancer une partie **multijoueur locale** (2 joueurs ou plus) ou un serveur dédié, sur une carte
quelconque, en étant `superadmin`. Ajouter des bots avec `bot` dans la console (ils reçoivent un personnage
temporaire non sauvegardé, pratique pour le combat). Activer `developer 1` pour voir les erreurs Lua.

1. **Core** — la console affiche `[NRP] Gamemode chargé` (serveur et client). `nrp help` liste les commandes.
   Envoyer rapidement une même requête (spam du clic molette) : aucune erreur, le serveur ignore l'excès.
2. **Base de données** — `[NRP] Base de données prête (sqlite, 7 tables)`. `!dbstatus`.
   Avec MySQLOO : `Driver = "mysqloo"` dans `config/sv_database.lua`, vérifier la création des tables `nrp_*`.
3. **Personnage** — première connexion : l'assistant de création s'ouvre, le joueur est figé et invisible.
   Tester un nom invalide (chiffres, trop court, nom réservé), puis créer. Se reconnecter : le personnage est chargé
   sans création. `!inspect <nom>` affiche la fiche.
4. **Progression** — `!givexp moi 5000` : passage de niveaux, points de stats. F3 → STATISTIQUES : `+1` / `+5`,
   la vie max et la vitesse changent. `!setrank`, `!promote`, puis `!exam open genin` / `!exam join` / `!exam pass`.
5. **Chakra** — lancer un jutsu : la barre baisse puis remonte après le délai. Maintenir M immobile : régénération
   accélérée et aura bleue ; un coup reçu interrompt la concentration. Vider le chakra : ralentissement.
6. **Jutsu** — `!givejutsu moi all`, F3 → JUTSU : placer des techniques dans les emplacements, les sélectionner (1-6),
   lancer avec le clic molette. Vérifier cooldown et coût dans le HUD, l'interruption par étourdissement, le refus sans chakra.
   Placer un mannequin (`!dummy`) pour lire les dégâts affichés.
7. **Combat** — contre un bot ou un joueur d'un autre village : combo clic gauche, attaque lourde, garde (C),
   parade (bloquer juste avant l'impact), bris de garde, esquive (Z, invulnérabilité), dash, substitution (X juste
   après un coup). Même village : aucun dégât sauf `!duel <nom>` puis `!duel accept`.
8. **Clans** — `!setclan moi hyuga`, `!clanpoints moi 5`, F3 → CLAN : débloquer « Byakugan », puis P pour l'activer
   (yeux, teinte, contours à travers les murs, drain). `hyuga_rotation` devient lançable uniquement Byakugan actif.
9. **Missions** — sur la carte : `!mpoint add delivery "Forge"`, `!mpoint add bandits`, `!missionnpc all` en visant
   le sol. Utiliser (E) le PNJ : tableau, accepter une mission, suivre la balise, terminer, vérifier les récompenses
   et la recharge. Tester l'abandon et l'échec (temps, mort de l'équipe). `!missionlist` signale les points manquants.
10. **Inventaire** — `!giveitem moi kunai 20`, l'équiper, lancer avec H. Utiliser un onigiri, jeter un objet puis le
    ramasser (E). `!shopnpc general` : acheter / vendre. Entre deux joueurs : Inventaire → Proposer un échange,
    offres, validation des deux côtés ; modifier une offre annule les validations.
11. **HUD et interfaces** — changer la résolution : polices et tailles s'adaptent. Vérifier HUD, noms au-dessus des
    têtes, notifications, annonces, suivi de mission, écran de K.O., tous les onglets du menu.
12. **Villages** — `!relation konoha kumo war` : annonce, dégâts autorisés, score de guerre (onglet VILLAGE).
    `!spawn add konoha` puis mourir : réapparition au point. `!deserter` deux fois (niveau 10 requis) : statut Nukenin + prime ;
    tuer la cible avec un autre joueur : prime encaissée. Bingo Book mis à jour.
13. **Administration** — F3 → ADMIN avec un compte `admin` puis `user` : l'onglet disparaît et les requêtes forcées
    sont refusées. Lancer un événement (x2 XP), `!event join`, récompenser, terminer. `!logs 20`.

---

## 6. Cohabitation avec l'addon naruto_dev

Le gamemode fonctionne **avec** les scripts existants de `lua/autorun` et `lua/weapons` (réglages : `config/compat.lua`) :

- **Touches** : le gamemode n'utilise aucune touche des techniques de l'addon (voir tableau ci-dessus).
  Le menu de l'addon reste sur F4, celui du gamemode passe sur F3.
- **Armes** : l'addon bloque le chargement d'armes par défaut ; le gamemode donne quand même les mains ninja.
  Les armes de l'addon (`hand`, `zabuza`, `shibuki`, `kabutowari`, `hiramekarei`, `shuriken_fuma`)
  se prennent dans le menu Q par tous les joueurs ayant un personnage ; le reste du menu Q reste réservé au staff.
- **Dégâts** : les techniques de l'addon blessent normalement (seules les zones sûres et la protection
  d'apparition s'appliquent). `ExternalDamageVillageRules = true` dans `config/combat.lua` leur applique
  aussi les règles de village.
- **Apparence** : l'addon pose sa tenue, sa tête et ses cheveux ; le gamemode réapplique ensuite la tenue choisie
  à la création (tenues Senju / Fuma proposées, les modèles absents sont masqués). Pour un modèle qui possède
  déjà une tête (`hasHead = true`), la tête et les cheveux de l'addon sont retirés. Pendant la création,
  ils sont cachés. L'aperçu de création les affiche.
- **Désactiver la compatibilité** : `NRP.Config.Compat.NarutoDev.Enabled = false`.

## 7. Points d'attention

- **Modèles** : les tenues `models/tenue/...` viennent du contenu workshop ATG ; si elles ne sont pas installées,
  seuls les modèles HL2 apparaissent à la création.
- **Animations** : les jutsu utilisent des gestes GMod standards ; `sequence = "nom"` permet d'utiliser les
  séquences wOS (`jutsu_pack.mdl`) déjà présentes dans l'addon.
- **Effets** : `particles = { travel = "…" }` permet de réutiliser les fichiers `.pcf` de l'addon
  (chargés avec `game.AddParticles`).
- Les PNJ ennemis sont des PNJ Source (combine, metropolice) : remplaçables par des NextBots via un type de mission.
