#!/usr/bin/perl
#
# Rend invisible OPAC les notices sans exemplaires, sauf les périodiques
# Aide disponible avec l'option --help
# Adapté uniquement aux données de l'Université Rennes 2
# Ne fonctionne qu'avec les valeurs suivantes dans la configuration de Zebra :
# 099 d = Suppress
# 099 s = Serial
# Modèle : script communautaire UNIMARC_sync_date_created_with_marc_biblio.pl
# Auteur : Mathieu Saby, Université Rennes 2
# 2012-12-11    Version 0.02 : ajout de l'option -exfk

use strict;
use warnings;

use C4::Biblio;
use Getopt::Long;

# =======================================
# Variables globales
# =======================================

my $dbh;
my $sth_prepared;
my $nb_notices_masquees = 0;
my $nb_notices_perios =0;
my $nb_notices_grilles_exclues =0;
my $nb_notices_sans_ex =0;
my $nb_notices_perios_masquees =0;
my $query;
my $sth;
my @grilles_exclues;
# paramètres de Zebra
my $zoneSuppress='099';
my $souszoneSuppress='d';
my $zonePeriodiques='099';
my $souszonePeriodiques='s';
my $valeur_suppress="1";
my $valeur_periodique="1";
# paramètres passés au script
my $run;
my $help;
my $verbose;
my $exfk;
my $where;
my $includeserials;

# =======================================
# Fonctions
# =======================================

# Sub print_usage
# affiche de l'aide dans la console
sub print_usage {
    print <<_USAGE_;
Passe toutes les notices sans exemplaires en statut invisible OPAC, sauf les notices de périodiques.
Spécifique à l'UNIMARC
Ne fonctionne qu'avec les valeurs suivantes dans la configuration de Zebra :
099 d = Suppress
099 s = Serial
Par défaut le script se lance en mode test, sans modifier les notices.
Pour le lancer effectivement, utiliser l'option -run

Paramètres :
    --help or -h                Affiche ce message
    --verbose or -v             Mode bavard : envoie des traces à la console
                                Pour les récupérer, utiliser les redirections.
                                Ex : ./masque_notices_sans_ex.pl >masque_notices.log
    --run                       exécute effectivement le script
    --includeserials            Applique également le script aux périodiques
    --exfk                      Exclut une ou plusieurs types de grilles de catalogage
                                Doit être suivi d'un ou plusieurs codes de grilles existant dans la base
                                Saisir DEFAULT pour la grille par défaut
                                (si plusieurs, séparées par un espace et mises entre guillemets simples)
                                Ex : -exfk 'FA ACQ'
    --where                     Facultatif (utile pour le débogage) : exécuter le script sur certaines notices.
                                Doit être suivi d'une condition MySQL (entre guillemets simples si elle contient des espaces)
                                portant sur les tables biblio ou biblioitem (par défaut sur la table biblio).                                
                                Ex : -where biblionumber=345
                                Ex : -where 'biblionumber between 1 and 35'
_USAGE_
}


# Sub give_marc_value
# renvoie le contenu d'une zone/sous zone
# paramètres : $biblio [Notice]
#              $zone [chaîne]
# (optionnel)  $souszone [chaîne]            
# retourne : contenu de la $zone entière, ou de la $souszone
sub give_marc_value {
    my ($biblio,$zone,$souszone) = @_;
    my $champ_marc ;
    my $marc_field = $biblio->field($zone);
    my $marc_value;
    if ($marc_field) {
        $marc_value =
          defined $souszone
          ? $marc_field->subfield($souszone)
          : $marc_field->data();
    }
    unless (defined $marc_value) {$marc_value ='';}
    return $marc_value;
}


# Sub biblio_is_serial
# vérifie si une notice est une notice de périodique
# paramètres : $biblio [Notice]
# retourne : 1 si notice de périodique
sub biblio_is_serial {
    my $biblio = shift;
    my $_marc_value = give_marc_value ($biblio,$zonePeriodiques,$souszonePeriodiques);
    if ($_marc_value eq $valeur_periodique) {return 1;}
    return;
}


# Sub biblio_is_hidden
# vérifie si une notice est masquée
# paramètres : $biblio [Notice]
# retourne : 1 si masquée
sub biblio_is_hidden {
    my $biblio = shift;
    my $_marc_value = give_marc_value ($biblio,$zoneSuppress,$souszoneSuppress);
    if ($_marc_value eq $valeur_suppress) {return 1;}
    return;
}

# Sub hide_record
# Masque la notice passée en paramètre
# paramètres : $biblio [Notice], $id, $fcode
# retourne : 0 si erreur
sub hide_record {
    my ($biblio,$id,$fcode) = @_;
    my $champ_marc ;
    # si mode run désactivé, on quitte la fonction
    return 1 unless $run;
    # La zone existe-t-elle? Si non, on la crée
    $champ_marc = $biblio->field($zoneSuppress);
    unless ($champ_marc) {
        $biblio->add_fields( new MARC::Field( $zoneSuppress, '', '' ) );
        $verbose and print "[WARN] $zoneSuppress n'existait pas dans la notice $id => zone créée par le script.";
        $champ_marc = $biblio->field($zoneSuppress);
    }
    # On passe la sous-zone à "1"
    $champ_marc->update( $souszoneSuppress, $valeur_suppress);

    # On applique à la BDD
    if ( &ModBiblio( $biblio, $id, $fcode ) ) {
        return 1;
    }
    return;
}

# =====================================
# Corps du script
# =====================================

GetOptions(
    'help|h'                 => \$help,
    'verbose|v'              => \$verbose,
    'run'                    => \$run,
    'includeserials'         => \$includeserials,
    'exfk:s'                 => \$exfk,
    'where:s'                => \$where,
);
$verbose = 1 if $ENV{DEBUG};
$verbose and print "Option --verbose activée : le script génèrera des traces et des messages d'erreur.\n";
$verbose and $where and print "Option --where activée : le script ne s'appliquera qu'aux notices répondant à la condition suivante :\n$where\n";
$verbose and $includeserials and print "Option --includeserials activée : le script masquera également les périodiques.\n";
$verbose and !$includeserials and print "Option --includeserials non activée : le script ne masquera pas les périodiques.\n";
$verbose and $exfk and print "Option --exfk activée : le script ne s'appliquera pas aux notices cataloguées avec les grilles $exfk.\n";
$verbose and !$exfk and print "Option --exfk non activée : le script s'appliquera aux notices cataloguées avec toutes les grilles.\n";
$verbose and $run and print "Option --run activée : le script modifiera effectivement les notices dans la base de donnée.\n";
$verbose and !$run and print "Option --run non activée : le script ne modifiera pas les notices dans la base de donnée.\n";

# Option "help" : affiche l'aide et sort du script
if ($help) {
    print_usage();
    exit 0;
}

# Sinon, prépare la requête
# on récupère aussi le frameworkcode (pas utilisé pour l'instant)
    $dbh = C4::Context->dbh;
    $query = q{
SELECT biblio.biblionumber, biblio.frameworkcode
FROM biblio 
JOIN biblioitems USING (biblionumber)
    };
# ajout de la limitation si elle a été saisi en option
    if ($where) {
        $query .= qq{ WHERE (biblionumber NOT IN (SELECT biblionumber FROM items)) AND ($where)};
}
    else {
        $query .= qq{ WHERE biblionumber NOT IN (SELECT biblionumber FROM items)} ;
 }
    $sth = $dbh->prepare($query);
    $sth->execute();
# $sth contient maintenant les biblionumber de toutes les notices sans item
    $nb_notices_sans_ex = $sth->rows;
    $verbose and print "Nombre de notices sans exemplaires : " . $nb_notices_sans_ex . "\n";
    while ( my $biblios = $sth->fetchrow_hashref ) {
        $verbose and print "Notice n°".$biblios->{'biblionumber'}." : ".$biblios->{'frameworkcode'};
        my $mybiblio = GetMarcBiblio($biblios->{'biblionumber'});
# Si $biblio n'est pas vide
        if ($mybiblio) {
            my $mybiblioisserial=biblio_is_serial ($mybiblio);
# Si grille à ne pas traiter
            if ($exfk and
                (((index ($exfk, "DEFAULT") > -1)  and not ($biblios->{'frameworkcode'}))
                 or
                 (($biblios->{'frameworkcode'}) and (index ($exfk, $biblios->{'frameworkcode'}) > -1) ))) {
                $verbose and print "non traitée [Grille de catalogage exclue : $biblios->{'frameworkcode'}]";
                $nb_notices_grilles_exclues++;
            }
#Sinon
            else {             
# Si est un pério ou grille à ne pas traiter
                if ($mybiblioisserial and !$includeserials) 
                {
                    $verbose and print "non traitée [Notice de périodique]";
                    $nb_notices_perios++;
                }
                else {
# Sinon
                    my $mybiblioishidden=biblio_is_hidden ($mybiblio);
# Si déjà cachée
                    if ($mybiblioishidden and $verbose) {
                       $verbose and print "non traitée [Déja masquée!]";
                    }
# Si pas encore cachée
                    else {
                        my $ret = hide_record( $mybiblio, $biblios->{'biblionumber'},$biblios->{'frameworkcode'});
# Si $ret = 1
                        if ($ret) {
                            $verbose and print "masquée par le script";
                            if ($verbose and $mybiblioisserial) {
                                print " [Notice de périodique]";
                                $nb_notices_perios++;
                                $nb_notices_perios_masquees++;
                            }
                            $nb_notices_masquees++;
                        } # if $ret
# si $ret est vide
                        else {
                            $verbose and print "non traitée (erreur base de données: ModBiblio ne peut pas modifier la notice";
                        }   
                    } # else
                } # else 
            } 
        } # if ($mybiblio)
# Si $biblio est vide
        else {
            $verbose and print "non traitée (erreur base de données: GetMarcBiblio ne trouve pas la notice";
        }
        $verbose and print "\n";
    } # while

    $verbose and print "Nombre de notices de périodiques parmi les notices sans exemplaires : " .  $nb_notices_perios . "\n";
    ($verbose and $exfk) and print "Nombre de notices des grilles $exfk non masquées par le script : " .  $nb_notices_grilles_exclues . "\n";
    $verbose and print "Nombre de notices sans exemplaires masquées par le script : " .  $nb_notices_masquees . "\n";
    $verbose and print "Nombre de notices de périodiques sans exemplaires masquées par le script : " .  $nb_notices_perios_masquees. "\n";
    $verbose and print "Nombre de notices sans exemplaires non masquées par le script : " . ($nb_notices_sans_ex -$nb_notices_masquees). "\n";
