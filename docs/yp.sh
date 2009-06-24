#!/bin/bash

MercatorToNormal(){                                                                                                                                                                                                                          
        y="$1"
# Start BC 
bc -l << EOF
scale   = 8
y       = $y
y = s( -1 * y * 4*a(1) / 180 )
y = (1 + y ) / ( 1 - y )
y = 0.5 * l(y)
y = y * 1.0 / (2 * 4*a(1))
y + 0.5
EOF

}


GetQuadtreeAddress(){                                                                                                                                                                                                                        
        lon="$1"
        lat="$2"
        quad="t"
        lookup=( q r t s )
        x="$( echo "scale = 8 ; ( 180 + $lon ) / 360" | bc )"
        y="$( MercatorToNormal $lat )"
        for i in $( seq 24 ) ; do
                b=0
                x="0.$( echo $x | awk -F. {'print $2'} )"
                y="0.$( echo $y | awk -F. {'print $2'} )"
                [ $( echo "$x >= 0.5" | bc ) = 1  ] && b=$[ $b + 1 ]
                [ $( echo "$y >= 0.5" | bc ) = 1  ] && b=$[ $b + 2 ]
                quad="$quad${lookup[$b]}"
                x=$( echo "$x * 2" | bc )
                y=$( echo "$y * 2" | bc )
        done
        echo "$quad"
}


qrst2xyz(){
        str="$1"

        # get normalized coordinate first
        x=0
        y=0
        z=17

        str="${str:1}" # skip the first character
        qrst=( 00 01 10 11 )    

        cnt="0"

        while [ ! -z "${str:$cnt:1}" ] ; do
                c="${str:$cnt:1}"
                [ "$c" = "q" ] && c="0"
                [ "$c" = "t" ] && c="1"
                [ "$c" = "r" ] && c="2"
                [ "$c" = "s" ] && c="3"
                x=$[ $x * 2 + ${qrst[$c]:0:1} ]
                y=$[ $y * 2 + ${qrst[$c]:1:1} ]
                z=$[ $z - 1 ]
                cnt=$[ $cnt + 1 ]

        done

        echo "x=$x&y=$y&zoom=$z"
}

GetPagineGialleAddress(){
        lon="$1"
        lat="$2"

	z="32768"

	echo "$lat $lon"


	# From 30 to 69		
	lat_dim="90"
	lat_offset="15"

	# From -10 to 35
	lon_offset="-10"
	lon_dim="45"

	lat="$( echo "scale = 6; $lat - $lat_offset" | bc )"
	lon="$( echo "scale = 6; $lon - $lon_offset" | bc )"
	
	echo "$lat $lon"


	cnt="1"
	while [ "$z" != "1" ] ; do
		x="$( echo "scale = 6; ($lon * ($cnt*4) / $lon_dim )" | bc | awk -F. {'print $1'} )"
		y="$( echo "scale = 6; ($lat * ($cnt*4) / $lat_dim )" | bc | awk -F. {'print $1'} )"

		echo "$x $y $z"
		z="$[ $z / 2 ]"
		cnt="$[ $cnt + 1 ]"
	done

}






# http://visualimages2.paginegialle.it/xml.php/europa-orto.imgi?cmd=tile&format=jpeg&x=2113&y=2658&z=32&extra=2&ts=256&q=65&rdr=0&sito=visual
#
#  44.807262  11.742726
#
GetQuadtreeAddress	11.742726 44.807262
GetPagineGialleAddress	11.742726 44.807262

exit
# trtqtstqqqsqrsqqrrt
qrst2xyz trtqtstqqqsqrsqqrrt
echo "http://mt0.google.com/mt/v=w2.92&$( qrst2xyz trtqtstqqqsqrsqqrr )"
echo "http://khm0.google.com/kh?v=3&t=trtqtstqqqsqrsqqrr" 
echo "http://visualimages2.paginegialle.it/xml.php/europa-orto.imgi?cmd=tile&format=png&$( qrst2yp trtqtstqqqsqrsqqrr )&extra=2&ts=256&q=65&rdr=0&sito=visual"

z="32768"

while [ "$z" != "1" ] ; do
	echo "$z"
	z="$[ $z / 2 ]"
done
exit
for x  in $( seq  0 3 ) ; do
	for y in $( seq  0 3 ) ; do
		echo	wget -O "tile-$x-$y.png" "http://visualimages1.paginegialle.it/xml.php/europa-orto.imgi?cmd=tile&format=png&x=$x&y=$y&z=32768&extra=2&ts=256&q=65&rdr=0&sito=visual"

	done
done

for x  in $( seq  0 15 ) ; do
	for y in $( seq  0 15 ) ; do
		echo	wget -O "tile-$x-$y.png" "http://visualimages1.paginegialle.it/xml.php/europa-orto.imgi?cmd=tile&format=png&x=$x&y=$y&z=16384&extra=2&ts=256&q=65&rdr=0&sito=visual"

	done
done


