#!/usr/bin/env bash

PROGRAM_STI="`dirname \"$0\"`"                   # relativ sti
PROGRAM_STI="`( cd \"$PROGRAM_STI\" && pwd )`"   # absolutt og normalisert sti
if [ -z "$PROGRAM_STI" ] ; then
  echo "FEIL: Har ikke tilstrekkelige rettigheter for å lese fra $PROGRAM_STI"
  exit 1
fi

PATH=$PATH:$PROGRAM_STI
lib=$PROGRAM_STI/lib
skjemaer=$PROGRAM_STI/skjema

source $lib/valider-felles.sh 2> /dev/null || { echo "FEIL: Finner ikke $lib/valider-felles.sh" ; exit 1; }

versjon="0.2.0"
program="${0##*/}"
kommando="$*"

vis_hjelp() {
cat << EOF
EPJ journal pakke validator versjon $versjon

Bruk: $program [opsjoner] <epj> [<rapport>]

Validerer en EPJ pakke

Opsjoner:
  
    -h|--hjelp  vis denne hjelpen og avslutt
    fil         EPJ tar pakke
    rapport     rapportfil som genereres, hvis ikke oppgitt skrives rapporten til standard utenhet
EOF
}


#
# Les argumenter fra kommandolinjen
#
while :; do
    case $1 in
        -h|-\?|--hjelp)
            vis_hjelp    
            exit
            ;;
        --)              # End of all options.
            shift
            break
            ;;
        -?*)
            avslutt "FEIL: Unkjent parameter: $1\n"
            ;;
        *)               # Default case: No more options, so break out of the loop.
            break
    esac

    shift
done

epj=$1
rapport=$2

[ "$epj" == "" ] && { vis_hjelp ; avslutt "FEIL: Må oppgi EPJ!\n"; }

uuid=$(basename $epj .tar)

skjema_pasientinfo="$skjemaer/epj/pasientinfo.xsd"
skjema_dok="$skjemaer/epj/epj_dokument.xsd "
skjema_sak="$skjemaer/epj/epj_sak.xsd "

pasientinfofil=$(tar tf $epj | grep -E "^$uuid/$uuid_regexp\.xml$")
epjsakfil=$(tar tf $epj | grep -E "^$uuid/journal/$uuid_regexp\.xml$")
declare -a epjdokfiler=($(tar tf $epj | grep -E "^$uuid/dokumenter/$uuid_regexp\.xml$"))

regelfil="$lib/epj.regler"

if [ "$rapport" == "" ] ; then
    rapport=$(mktemp /tmp/$program.XXXXX)
    temprapport=1
    trap "rm -f $rapport" EXIT
fi
[ "$epj" == "" ]     && { vis_hjelp ; avslutt "FEIL: Må oppgi EPJ fil!\n"; }

rapport_start $rapport

[ ! -f "$regelfil" ] && { rapport_feil "EPJ-00" `printf "Regelfilen finnes ikke: %s" $regelfil` ; rapport_slutt $rapport ; exit 1; }

# Feilkode 	   Feltnavn	       Datatype	    Validator		Kategori     Type 	    Innholdsbeskrivelse
#
# Kravtype: Angir type krav. Her brukes kodene:
#   T Terminal - avslutter testingen

function valider_spj_shell() {
    valider_shell
    [ "$?" != "0" ] && [ "$type" == "T" ] && { rapport_slutt $rapport $temprapport; exit ; }
}

function valider_dok() {
    valider_shell
    [ "$?" != "0" ] && [ "$type" == "T" ] && { rapport_slutt $rapport $temprapport; exit ; }
}

les_regler "shell"
valider_regler "valider_spj_shell"

les_regler "dok"
for epjdokfil in ${epjdokfiler[@]}; do
    valider_regler "valider_dok"
done

# Valider EPJ-dok
#    tar xOf $epj $d | xmllint --noout --schema $skjema_dok -

rapport_slutt $rapport $temprapport

if [ "${#feil[@]}" != "0" ]; then
    r="($rapport)"
    [ "$temprapport" == "1" ] && r="over"
    avslutt "EPJ validerer ikke, se rapport $r for detaljer\n"
fi

