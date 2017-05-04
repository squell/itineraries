#! /bin/bash

CURL="wget --quiet -O -"

trap "TITANIC=gezonken" ERR

declare -A tabel

die() {
	echo "$1" 1>&2
	zenity --error --text "$1"
	exit 1
}

# print de afstand in km, volgens google maps, tussen twee fysieke addressen
afstand() {
	URL="https://maps.googleapis.com/maps/api/distancematrix/json?origins=$1&destinations=$2&key=AIzaSyCHc_k-0nMYf-zUPEgfUIqY81Y3uYKA3gM"
	$CURL "$URL" | sed -n /distance/,/value/p | awk -v FS=':' '/value/{ printf "%.1f", ($2/1000.0) }'
}

# lees de addressen in een array
while read naam rest; do
    	test -z "${naam%#*}" && continue
	test -z "${tabel[$naam]}" || die "Naam $naam dubbelop gedefinieerd! Fix de adressen!"
	tabel["$naam"]="$rest"
done < "${0%/*}/addressen.txt"

# verwerk een reisplan
reisschema() {
	# check args
	for plaats; do
		test "${tabel[$plaats]}" || die "Onbekende bestemming: $plaats"
	done

	echo -n "$1,"
	vorig="$1"; shift
	while [ "$1" ]; do
		km=`afstand "${tabel[$vorig]}" "${tabel[$1]}"`
		[ "$km" ] || die "${tabel[$1]} is geen goed adres!"
		echo -n "$1,$km,"
		vorig="$1"; shift
	done
}

# converteer datum naar dagen sinds 30-12-1899
dagnummer() {
	echo $((`date -d "$*" +%s` /60/60/24 + 25570))
}

# lees reizen.txt uit ("datum: a b c ..." formaat)
CSV=$(mktemp --suffix .csv)
while read gereisd; do
	datum="${gereisd%:*}"
	echo "bezig met $datum" >&2
	datumnr="$(dagnummer "$datum")"
	gereisd="${gereisd#*:}"
	[ "$datumnr" ] || die "Ongeldige datum: $datum"
	echo -n "$datumnr,"
        reisschema $gereisd
	echo
done < "${0%/*}/reizen.txt" > $CSV

if [ "$TITANIC" ]; then 
	die 'Daar ging iets fout.'
else
	localc --infilter="csv:44,34,0,1" "$CSV"
fi
