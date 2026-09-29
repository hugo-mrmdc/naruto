<?php

declare(strict_types=1);

// Point d'entrée WEB : ce fichier ne fait qu'inclure le vrai code (routage,
// endpoints...) qui vit dans naruto_api/index.php, en dehors de public/.
// Ne mets aucune logique ici — c'est naruto_api/index.php qu'il faut modifier.
require __DIR__ . '/../index.php';
