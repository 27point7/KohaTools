#!/bin/bash
#Script pour restaurer la base de données en utilisant un point de restauration créé par savedb.sh
if [ -z "$KOHA_CONF" ]; then
    echo "La variable d'environnement KOHA_CONF doit être définie"
    exit 1
fi
koha_etc_dir=${KOHA_CONF%/*}
db_backup_dir=$koha_etc_dir/db_backup
echo "Restauration de la base de données"
echo "Points de restaurations utilisables:"
index=1
for fichier in $(ls $db_backup_dir/*.sql.gz)
do
    fichier_info=$(echo $fichier | sed s/sql.gz/info/)    
    echo "   "$index" -- "$(grep "^Version" $fichier_info) " -- Sauvegarde du "$(basename $fichier | cut -b8-17) "à" $(basename $fichier | cut -b19-20)"h"$(basename $fichier | cut -b22-23)"m"$(basename $fichier | cut -b25-26)"s"
    index=$(($index+1))
done
index=$(($index-1))
read -p "Saisissez le numéro du point de restauration à utiliser puis <Entrée>: " choix
if [[ "$choix" -gt "$index" || "$choix" = "0" ||  $choix = *[!0-9]* ]]
then
    echo "Choix invalide!"
    exit 1
fi
index=1
for fichier in $(ls $db_backup_dir/*.sql.gz)
do
    if [[ "$choix" -eq "$index" ]]
    then
        fichier_info=$(echo $fichier | sed s/sql.gz/info/)
        db_name=$(grep "^Nom" $fichier_info | cut -d: -f2)
        db_user=$(grep "^Utilisateur" $fichier_info | cut -d: -f2)
        db_pass=$(grep "^Mot de passe" $fichier_info | cut -d: -f2)
        echo "   "$index" -- "$(grep "^Version" $fichier_info) " -- Restauration de la sauvegarde du "$(basename $fichier | cut -b8-17) "à" $(basename $fichier | cut -b19-20)"h"$(basename $fichier | cut -b22-23)"m"$(basename $fichier | cut -b25-26)"s"     
        echo "Restauration en cours..."
        gunzip < $db_backup_dir/$(basename $fichier) | mysql -u $db_user -p$db_pass $db_name
    fi
    index=$(($index+1))
done
