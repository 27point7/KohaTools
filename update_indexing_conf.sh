#!/bin/bash
# Script pour mettre à jour la configuration du Queryparser et (partiellement) de Zebra et relancer l'indexation après une mise à jour de ces fichiers dans les sources

while test $# -gt 0
do
if [[ "$1" = "--help" ]]; then
    echo "Script en ligne de commande pour mettre à jour la configuration du Queryparser et (partiellement) de Zebra"
    echo "Il ne touche pas aux fichiers de configuration de Zebra qui contiennent des valeurs dépendant de choix faits lors de l'installation (dom/grs1, icu/chr, type de marc)"
    echo "Peut être utile pour tester des patchs relatifs à Zebra :"
    echo "- Créer une branche de test avec git"
    echo "- Appliquer le patch à tester (avec git bz ou simplement git am)"
    echo "- Lancer le script de mise à jour de l'indexation ./update_indexing_conf.sh"
    echo "- Tester le patch"
    echo "- Revenir en branche master"
    echo "- Relancer le script pour restaurer la configuration standard"
    exit 0
fi
shift
done

if [ -z "$KOHA_CONF" ]; then
    echo "La variable d'environnement KOHA_CONF doit être définie"
    exit 1
fi
echo "==================================================="
echo "        Extraction des chemins"
echo "==================================================="
zebra_conf_dir=$(xmllint --xpath "//server[@id='biblioserver']/config/text()" $KOHA_CONF)
zebra_conf_dir=${zebra_conf_dir%/*}
koha_src_dir=$(xmllint --xpath "//intranetdir/text()" $KOHA_CONF)
qp_conf=$(xmllint --xpath "//queryparser_config/text()" $KOHA_CONF)
echo "Chemin des sources de Koha: "$koha_src_dir
echo "Chemin de la configuration du Queryparser: "$qp_conf
echo "Chemin de la configuration de Zebra: "$zebra_conf_dir
echo "==================================================="
echo "        Copie du fichier de configuration du Queryparser"
echo "==================================================="
cp -v -f $koha_src_dir/etc/searchengine/queryparser.yaml $qp_conf
echo "==================================================="
echo "        Copie des principaux fichiers de configuration de Zebra"
echo "        Ne copie pas les fichiers contenant des variables modifiées à l'installation"
echo "==================================================="
cp -v -f $koha_src_dir/etc/zebradb/ccl.properties $zebra_conf_dir/ccl.properties
cp -v -f $koha_src_dir/etc/zebradb/cql.properties $zebra_conf_dir/cql.properties
cp -v -f $koha_src_dir/etc/zebradb/pqf.properties $zebra_conf_dir/pqf.properties
cp -v -f $koha_src_dir/etc/zebradb/biblios/etc/bib1.att $zebra_conf_dir/biblios/etc/bib1.att
cp -v -f $koha_src_dir/etc/zebradb/authorities/etc/bib1.att $zebra_conf_dir/authorities/etc/bib1.att
cp -v -f -r $koha_src_dir/etc/zebradb/marc_defs/unimarc/biblios/* $zebra_conf_dir/marc_defs/unimarc/biblios
cp -v -f -r $koha_src_dir/etc/zebradb/marc_defs/marc21/biblios/* $zebra_conf_dir/marc_defs/marc21/biblios
cp -v -f -r $koha_src_dir/etc/zebradb/marc_defs/unimarc/authorities/* $zebra_conf_dir/marc_defs/unimarc/authorities
cp -v -f -r $koha_src_dir/etc/zebradb/marc_defs/marc21/authorities/* $zebra_conf_dir/marc_defs/marc21/authorities
echo "==================================================="
echo "        Réindexation des notices d'autorités"
echo "==================================================="
perl $koha_src_dir/misc/migration_tools/rebuild_zebra.pl -a -v -r
echo "==================================================="
echo "        Réindexation des notices bibliographiques"
echo "==================================================="
perl $koha_src_dir/misc/migration_tools/rebuild_zebra.pl -b -v -r
