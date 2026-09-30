# Menu F4

Le menu utilise `materials/ui/newUi/optimized/`. Les PNG sources sont conservés.
Régénération : `powershell -File tools/optimize-newui.ps1` depuis cet addon.
Cases : 256 px maximum ; boutons : 512 px ; panneaux : 768 px ; fond conservé.
Les quatre nouvelles raretés sont exportées en 256 × 256 px sous les noms
`comun`, `rare`, `epique` et `legendaire`, déjà utilisés par l'addon.
Leurs marges transparentes sont conservées ; le dessin aligne les bordures
sur les cases vides avec des coordonnées normalisées sur 256 pour chaque axe.
Seules les versions optimisées sont distribuées. Après remplacement des PNG,
redémarrer le jeu pour vider le cache des matériaux. Si une texture de rareté
échoue au chargement, la case normale est utilisée à la place du damier rose.

Première ouverture : les textures fixes sont préparées progressivement après
l'arrivée du joueur (une toutes les 250 ms). Le cadre est affiché avant les
aperçus, puis une création d'aperçu au maximum est traitée par image.
Les icônes de la grille ne sont créées que lorsqu'elles entrent dans la zone
visible. Les tâches dont le panneau a été supprimé sont ignorées.
Le chargement d'un modèle individuel reste synchrone dans le moteur.

Les 40 emplacements et les messages serveur existants sont conservés.
Clic simple : détails ; clic droit / double clic : équiper ou retirer.
Les accessoires sont dans Cosmétiques, les autres objets dans Objets.
Matériaux filtre les objets non équipables. La jauge compte les emplacements,
car le système actuel ne fournit pas de poids. Vente et abandon ne sont pas
exposés : aucun traitement serveur correspondant n'existe dans ce menu.

`AjouterItem` accepte un dernier argument optionnel `rarete` :
`commun`, `rare`, `epique`, `legendaire` (commun par défaut).
Le tri conserve les indices d'inventaire : équiper vise toujours le bon objet.
`DefinirRareteItem(slot, "epique")` met à jour un objet existant.
Les définitions d'armes peuvent déclarer `SWEP.Rarete = "rare"`.
La rareté reste attachée à l'objet équipé puis retiré. Elle apparaît dans
sa case, son infobulle et sa fiche. Les cases utilisent les images optimisées
comun, rare, epique et legendaire. Ce classement est visuel,
sans modification des statistiques ni probabilités de butin.

Contrôle en jeu à effectuer :
- F4 et Échap ; recherche puis Entrée ; ouverture répétée.
- Première ouverture après connexion ; fermer pendant le chargement, rouvrir,
  puis filtrer et faire défiler pendant l'apparition progressive des icônes.
- `test_items` uniquement sur une session de développement (remplit des cases).
- Onglets, recherche, tri, quantités et défilement des 40 cases.
- Équiper / retirer tenue, masque, accessoire et épée ; ajuster leur placement.
- Rotation du personnage et affichage des accessoires.
- Résolutions 1280×720, 1920×1080 et écran ultralarge.
