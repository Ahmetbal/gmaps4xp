#!/bin/bash


# north=44.920523&south=44.623974&east=11.973813&west=11.355621
BASE_URL="http://www.informationfreeway.org/api/0.6"
BASE_URL="http://xapi.openstreetmap.org/api/0.5"


left="11.355621"
bottom="44.623974"
right="11.973813"
top="44.920523"

QUERY_URL="${BASE_URL}/map?bbox=$left,$bottom,$right,$top"

#wget -O output.log "$QUERY_URL"

XML_OUTPUT="$( cat output.log )"

echo "Get ways list..."
WAYS_START=( $( echo "$XML_OUTPUT" | grep -n "<way id=" | awk -F:  {'print $1'} | tr "\n" " " ) )
WAYS_END=(   $( echo "$XML_OUTPUT" | grep -n "</way>"   | awk -F:  {'print $1'} | tr "\n" " " ) )

echo "Get nodes list..."
NODES="$(       echo "$XML_OUTPUT" | grep "node id="    | awk -F\' {'print $2" "$4" "$6'} )"

echo "${#WAYS_START[@]}"
i="1100"
while [ ! -z "${WAYS_START[$i]}" ]  ; do

	CONTENT="$( echo "$XML_OUTPUT" 	| head -n "${WAYS_END[$i]}" | tail -n $[ ${WAYS_END[$i]} - ${WAYS_START[$i]} + 1 ] )" 
	TAG="$(     echo "$CONTENT" 	| grep "<tag k="  | awk -F\' {'print $2'} )"
	echo "$TAG"
	if [ ! -z "$( echo "$TAG" | grep -i "waterway" )" ] ; then
		echo "waterway skip..."		
		continue
	fi

	REF="$(     echo "$CONTENT" 	| grep "<nd ref=" | awk -F\' {'print $2'} | tr "\n" " " )"

	cnt="0"
	for r in $REF ; do
		echo -n "."		
		WAY[$cnt]="$( echo "$NODES" | grep "^$r" | awk {'print $2","$3'} )"
		cnt=$[ $cnt + 1 ]
	done
	echo 
	echo "${WAY[*]}"
	echo
	i="$[ $i + 1 ]"
	exit
done

