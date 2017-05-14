#! /bin/bash

CURL="wget --quiet -O -"

trap "TITANIC=gezonken" ERR

declare -A tabel

die() {
	echo "$1" 1>&2
	zenity --error --text "$1"
	exit 1
}

# check of de addressen enigszins overeenkomen
komtovereen() {
	ascii="$(echo "$1" | iconv -c -t ascii//translit)"
	output="$(cat | sed 's/.*\[//;s/].*$//')"
	echo "$output" | iconv -c -t ascii//translit | grep -qi "${ascii%,*}" || die "Adres ${1^} veranderd in $output"
}

# print de afstand in km, volgens google maps, tussen twee fysieke addressen
afstand() {
	URL="https://maps.googleapis.com/maps/api/distancematrix/json?origins=$1&destinations=$2&key=AIzaSyCHc_k-0nMYf-zUPEgfUIqY81Y3uYKA3gM"
	response="$($CURL "$URL")"
	echo "$response" | grep "origin_addresses"      | komtovereen "$1"
	echo "$response" | grep "destination_addresses" | komtovereen "$2"
	echo "$response" | sed -n /distance/,/value/p | awk -v FS=':' '/value/{ printf "%.1f", ($2/1000.0) }'
}

if [ $(afstand "amsterdam" "amsterdam") != 0.0 ]; then
	die "Er is iets mis met Google."
fi

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
	localc --infilter="Text - txt - csv (StarCalc):44,34,0,1,1/10/2/10/3/10/4/10/5/10/6/10/7/10/8/10/9/10/10/10/11/10/12/10/13/10/14/10/15/10/16/10/17/10/18/10/19/10/20/10" "$CSV"
fi
