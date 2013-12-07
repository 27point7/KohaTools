KohaTools
=========

Quelques outils pour Koha
Attention, outils présentés sans aucune garantie

========
Some Tools for Koha ILS
Without any garanty


1. masque_notices_sans_ex.pl
Script en ligne de commande pour masquer à l'OPAC les notices sans exemplaire (pour des notices UNIMARC).
Lancer avec -h pour une aide détaillée

2. update_indexing_conf.sh
Script en ligne de commande pour mettre à jour la configuration du Queryparser et (partiellement) de Zebra
Peut être utile pour tester des patchs relatifs à Zebra :
Lancer avec --help pour avoir une aide

3. savedb.sh et restoredb.sh
Scripts pour sauvegarder et restaurer la base de données. Pratique pour revenir à l'état initial après avoir testé un patch.
Plusieurs points de restauration possibles. Indique la version exacte de la base et la date précise pour chaque point de restauration.
