#!/bin/bash
#Script pour créer des points de restauration de la base de données avant de tester un patch qui pourrait l'altérer
#A utiliser avec restoredb.sh
#Extrait un dump de la base et le stocke dans un dossier db_backup créé dans le dossier où se trouve le fichier koha_conf.xml
if [ -z "$KOHA_CONF" ]; then
    echo "La variable d'environnement KOHA_CONF doit être définie"
    exit 1
fi
koha_etc_dir=${KOHA_CONF%/*}
db_backup_dir=$koha_etc_dir/db_backup
db_name=$(xmllint --xpath "//config/database/text()" $KOHA_CONF)
db_user=$(xmllint --xpath "//config/user/text()" $KOHA_CONF)
db_pass=$(xmllint --xpath "//config/pass/text()" $KOHA_CONF)
koha_src_dir=$(xmllint --xpath "//intranetdir/text()" $KOHA_CONF)
db_version=$(grep "^\$DBversion = \"" $koha_src_dir/installer/data/mysql/updatedatabase.pl | cut -d"=" -f2 | cut -d'"' -f2 | sort | tail -1 | sed s/"\."/-/g)
mkdir -p $db_backup_dir

echo "Informations sur la base de donnée:"
echo "Nom           :"$db_name
echo "Utilisateur   :"$db_user
echo "Mot de passe  :"$db_pass
echo "Version       :"$db_version

file_name="backup_"$(date +%Y-%m-%d-%H.%M.%S)
file_name_info=$file_name".info"
file_name_sql=$file_name".sql.gz"
touch $db_backup_dir/$file_name
echo "Nom           :"$db_name >> $db_backup_dir/$file_name_info 
echo "Utilisateur   :"$db_user >> $db_backup_dir/$file_name_info 
echo "Mot de passe  :"$db_pass >> $db_backup_dir/$file_name_info 
echo "Version       :"$db_version >> $db_backup_dir/$file_name_info 


echo "Sauvegarde de la base de donnée dans le dossier "$db_backup_dir "..."
file_name="backup_"$(date +%Y-%m-%d-%H.%M.%S)".sql.gz"
mysqldump -u $db_user -p$db_pass --databases $db_name | gzip > $db_backup_dir/$file_name_sql

if [ -f $db_backup_dir/$file_name_sql ]
then
    echo "Fichier $file_name créé avec succès."
else
    echo "Erreur: fichier non créé"
fi
