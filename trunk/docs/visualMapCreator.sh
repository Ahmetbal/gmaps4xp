#!/bin/bash

TILE_LEVEL[2]="65536"
TILE_LEVEL[4]="32768"	
TILE_LEVEL[8]="16384"
TILE_LEVEL[16]="8192"	
TILE_LEVEL[32]="4096"	
TILE_LEVEL[64]="2048"	
TILE_LEVEL[128]="1024"
TILE_LEVEL[256]="512"
TILE_LEVEL[512]="256"
TILE_LEVEL[1024]="128"
TILE_LEVEL[2048]="64"
TILE_LEVEL[4096]="32"
TILE_LEVEL[8192]="16"
TILE_LEVEL[16384]="8"
TILE_LEVEL[32768]="4"
TILE_LEVEL[65536]="2"



log(){
        echo "$(date) - $1" 1>&2
}



#UL=( 44.854227 11.597803 )
#LR=( 44.824209 11.636779 )
#UL=( 44.875188 11.575790 )
#LR=( 44.849834 11.607900 )
#UL=( 44.906861 11.609939 )
#LR=( 44.671381 11.808416 )

#UpperLeftLat="45"
#UpperLeftLon="11"

UpperLeftLat="45"
UpperLeftLon="12"



UL=( $UpperLeftLat $UpperLeftLon )
LR=( $[ $UpperLeftLat - 1 ] $[ $UpperLeftLon + 1 ] )
LEVEL="16"
OUTPUT_DIR="$1"
tolerance="1"
log "Directory Tree creation ..."

[ ! -d "$OUTPUT_DIR" ] 		&& mkdir "$OUTPUT_DIR"
[ ! -d "$OUTPUT_DIR/images" ] 	&& mkdir "$OUTPUT_DIR/images"
[ ! -d "$OUTPUT_DIR/ter" ] 	&& mkdir "$OUTPUT_DIR/ter"
[ ! -d "$OUTPUT_DIR/tmp" ] 	&& mkdir "$OUTPUT_DIR/tmp"

WD="$( cd $( dirname $0 ); pwd )"


downloadTile(){
	local xcoord="$1"
	local ycoord="$2"
	local zcoord="$3"
	local file="$4"
	local server="$[ ( $xcoord % 4 )  + 1 ]"
	pid="1"
	while [ "$pid" -ne "0" ] ;  do
		wget --timeout=10 -q "http://visualimages${server}.paginegialle.it/xml.php/europa-orto.imgi?cmd=tile&format=png&x=${xcoord}&y=${ycoord}&z=${zcoord}&extra=2&ts=256&q=100&rdr=0&sito=visual" -O "$file"
		pid="$?"
		[ "$pid" -ne "0" ] && log "Unable to download retry in 10 seconds ..." && sleep 10
	done
}

# http://visualimages3.paginegialle.it/xml.php/europa-orto.imgi?cmd=tile&format=jpeg&x=1&y=1&z=32768&extra=2&ts=256&q=65&rdr=0&sito=visual
# http://visualimages3.paginegialle.it/xmlvisual.php/europa.imgi?cmd=tile&format=jpeg&x=8422&y=10628&z=8&extra=2&ts=256&q=60&rdr=0&sito=visual&v=1
# http://visualimages1.paginegialle.it/xml.php/europa-orto.imgi?cmd=tile&format=jpeg&x=8432&y=10648&z=8&extra=2&ts=256&q=65&rdr=0&sito=visual
# ftp://xftp.jrc.it/pub/srtmV4/tiff/srtm_39_04.zip


getXY(){
	local lat="$1"
	local lon="$2"
	local zoom="$3"
 	local zone="$( echo "scale = 6; ( $lon   + 180   ) / 6 + 1" | bc )"
	local zone="${zone%.*}"

cat << EOM | bc -l 
mapwidthlevel1pixel 	= 33554432
mapwidthmeters		= 4709238.7
mapcentreutmeasting	= 637855.35
mapcentreutmnorthing	= 5671353.65
define tan(x) { x = s(x) / c(x); return (x); }
define latlongxy(e,a,t){
	p = 6378137
	n = 0.00669438
	l = 0.9996
	u = 3.14159265
	b = u * e / 180
	f = u * a / 180
	q = ( (t-1) * 6 - 180 + 3 ) * u / 180
	h = (n) / (1-n)
	g = p /  sqrt(1-n * s(f) *s(f) )
	d = tan(f) * tan(f)
	m = h * c(f) * c(f)
	o = c(f) * (b-q)
	j = p*((1-n/4-3*n*n/64-5*n*n*n/256)*f-(3*n/8+3*n*n/32+45*n*n*n/1024) * s(2*f)+(15*n*n/256+45*n*n*n/1024) * s(4*f)-(35*n*n*n/3072)*s(6*f))
	s = (l*g*(o+(1-d+m)*o*o*o/6+(5-18*d+d*d+72*m-58*h)*o*o*o*o*o/120)+500000)
	r = (l*(j+g*tan(f)*(o*o/2+(5-d+9*m+4*m*m)*o*o*o*o/24+(61-58*d+d*d+600*m-330*h)*o*o*o*o*o*o/720)));

	x = s
	y = r
	n = mapwidthmeters
	f = mapcentreutmeasting
	g = mapcentreutmnorthing
	j = t
	e = x+((n/2)-f)
	b = g + (n/2) - y
	l = e / n
	h = b / n
	l * ${TILE_LEVEL[$zoom]}
	h * ${TILE_LEVEL[$zoom]}
	s
	r
	
}

a = latlongxy($lon, $lat, $zone)

EOM

}


getDirName(){
        local lat="$1"
        local lon="$2"
        [ -z "$lat" ] && log "getDirName Latitude is empty"     && exit 1
        [ -z "$lon" ] && log "getDirName Longitude is empty"    && exit 1



        [  "$( echo "$lat < 0" | bc -l )" = 1 ] && lat="$( echo "scale = 8; $lat - 10.0" | bc -l )"

        local int="${lat%.*}"
        [ -z "$int" ] && int="0"
        lat="$( echo  "$int - ( $int % 10 )" | bc )"
        [ -z "$( echo "${lat%.*}" | tr -d "-" )" ] && lat="$( echo "$lat" | sed -e s/"\."/"0\."/g )"
        [ "$( echo "$lat > 0" | bc -l )" = 1  ] && lat="+$lat"

        [ "$( echo -n "$lat" | tr -d "+-" | wc -c | awk {'print $1'} )" = "1" ] && lat="$( echo "$lat" | sed -e s/"+"/"+0"/g |  sed -e s/"-"/"-0"/g )"


        [  "$( echo "$lon < 0" | bc -l )" = 1 ] && lon="$( echo "scale = 8; $lon - 10.0" | bc -l )"

        local int="${lon%.*}"
        [ -z "$int" ] && int="0"
        lon="$( echo  "$int - ( $int % 10 )" | bc )"
        [ -z "$( echo "${lon%.*}" | tr -d "-" )" ] && lon="$( echo "$lon" | sed -e s/"\."/"0\."/g )"
        [ "$( echo "$lon >= 0" | bc -l )" = 1  ] && lon="+$lon"



        [ "$( echo -n "$lon" | tr -d "+-" | wc -c | awk {'print $1'} )" = "1" ] && lon="$( echo "$lon" | sed -e s/"+"/"+00"/g |  sed -e s/"-"/"-00"/g )"
        [ "$( echo -n "$lon" | tr -d "+-" | wc -c | awk {'print $1'} )" = "2" ] && lon="$( echo "$lon" | sed -e s/"+"/"+0"/g |  sed -e s/"-"/"-0"/g )"

        [ "$lat" = "0" ]        && lat="+00"
        [ -z "$lon" ]           && lon="+000"
        echo "$lat$lon"
}

getDSFName(){
        local lat="$1"
        local lon="$2"
        [ -z "$lat" ] && log "getDSFName Latitude is empty"     && exit 1
        [ -z "$lon" ] && log "getDSFName Longitude is empty"    && exit 1

        lat="$( echo "$lat" | awk -F. {'print $1'} )"
        [ -z "$lat" ] && lat="0"
        [ -z "$( echo "${lat%.*}" | tr -d "-" )" ] && lat="$( echo "$lat" | sed -e s/"\."/"0\."/g )"

        [ "$( echo "$lat < 0" | bc )" = 1  ] && lat="$( echo "$lat - 1" | bc )"
        [ "$( echo "$lat > 0" | bc )" = 1  ] && lat="+$lat"

        [ "$( echo -n "$lat" | tr -d "+-" | wc -c | awk {'print $1'} )" = "1" ] && lat="$( echo "$lat" | sed -e s/"+"/"+0"/g |  sed -e s/"-"/"-0"/g )"


        lon="$( echo "$lon" | awk -F. {'print $1'} )"
        [ -z "$lon" ] && lon="0"

        [ -z "$( echo "${lon%.*}" | tr -d "-" )" ] && lon="$( echo "$lon" | sed -e s/"\."/"0\."/g )"

        [ "$( echo "$lon < 0" | bc )" = 1  ] && lon="$( echo "$lon - 1" | bc )"
        [ "$( echo "$lon > 0" | bc )" = 1  ] && lon="+$lon"


        [ "$( echo -n "$lon" | tr -d "+-" | wc -c | awk {'print $1'} )" = "1" ] && lon="$( echo "$lon" | sed -e s/"+"/"+00"/g |  sed -e s/"-"/"-00"/g )"
        [ "$( echo -n "$lon" | tr -d "+-" | wc -c | awk {'print $1'} )" = "2" ] && lon="$( echo "$lon" | sed -e s/"+"/"+0"/g  |  sed -e s/"-"/"-0"/g  )"


        [ "$lat" = "0" ]        && lat="+00"
        [ "$lon" = "0" ]        && lon="+000"
        [ "$lon" = "-000" ]     && lon="-001"

        echo "$lat$lon.dsf"
}


geoRef(){
	local x="$1"
	local y="$2"
	local E="$3"
	local N="$4"

	local zoom="$5"

	local pixelRes="$( echo "scale = 6; 4709238.7 / ${TILE_LEVEL[$zoom]}" | bc )"
	

	local x="$( echo "$x" | awk -F. {'print "0."$2'} )"
	local y="$( echo "$y" | awk -F. {'print "0."$2'} )"

	local ULx="$( echo "scale = 6; $E - ( $pixelRes * $x )" | bc )"
	local ULy="$( echo "scale = 6; $N + ( $pixelRes * $y )" | bc )"
	local pixelRes="$( echo "scale = 6; 4709238.7 / ${TILE_LEVEL[$zoom]} / 256" | bc )"

	echo -n "$ULx, $pixelRes, 0.0, $ULy, 0.0, -$pixelRes"

}

imageGeoInfo(){
	local padfGeoTransform=( $( echo "$*" | tr "," " " ) )

cat << EOM | bc -l | tr -d  "\\\\\n" 
	scale 	= 6;

	dfpixel = 128;
	dfline	= 128;
	pdfgeox	= ${padfGeoTransform[0]} + dfpixel * ${padfGeoTransform[1]} + dfline * ${padfGeoTransform[2]};
	pdfgeoy	= ${padfGeoTransform[3]} + dfpixel * ${padfGeoTransform[4]} + dfline * ${padfGeoTransform[5]};
	print   pdfgeox, "," , pdfgeoy, " ";

	dfpixel = 0;
	dfline	= 0;
	pdfgeox	= ${padfGeoTransform[0]} + dfpixel * ${padfGeoTransform[1]} + dfline * ${padfGeoTransform[2]};
	pdfgeoy	= ${padfGeoTransform[3]} + dfpixel * ${padfGeoTransform[4]} + dfline * ${padfGeoTransform[5]};
	print   pdfgeox, "," , pdfgeoy, " ";

	dfpixel = 256;
	dfline	= 0;
	pdfgeox	= ${padfGeoTransform[0]} + dfpixel * ${padfGeoTransform[1]} + dfline * ${padfGeoTransform[2]};
	pdfgeoy	= ${padfGeoTransform[3]} + dfpixel * ${padfGeoTransform[4]} + dfline * ${padfGeoTransform[5]};
	print   pdfgeox, "," , pdfgeoy, " ";

	dfpixel = 256;
	dfline	= 256;
	pdfgeox	= ${padfGeoTransform[0]} + dfpixel * ${padfGeoTransform[1]} + dfline * ${padfGeoTransform[2]};
	pdfgeoy	= ${padfGeoTransform[3]} + dfpixel * ${padfGeoTransform[4]} + dfline * ${padfGeoTransform[5]};
	print   pdfgeox, "," , pdfgeoy, " ";

	dfpixel = 0;
	dfline	= 256;
	pdfgeox	= ${padfGeoTransform[0]} + dfpixel * ${padfGeoTransform[1]} + dfline * ${padfGeoTransform[2]};
	pdfgeoy	= ${padfGeoTransform[3]} + dfpixel * ${padfGeoTransform[4]} + dfline * ${padfGeoTransform[5]};
	print   pdfgeox, "," , pdfgeoy;

EOM


}

imageGeoInfoToLatLng(){
	local args=( $* )
	local zone="${args[0]}"

	scale="$[ $( echo "${tolerance#*.}" | wc -c ) - $( echo "${tolerance#*.}" | sed -e s/^0*//g  | wc -c ) + 2 ]"
	scale="${scale/-/}"
	[ -z "$scale" ] && scale="20"

	local cnt="1"
	while [ ! -z "${args[$cnt]}" ] ; do
		x="${args[$cnt]%,*}"
		y="${args[$cnt]#*,}"
cat << EOM | bc -l 
define i(xt) 		{  auto s ; s = scale; scale = 0; xt /= 1; scale = s; return (xt); }
scale = 20
define tan(xt) 		{ xt = s(xt) / c(xt); return (xt); }
define abs(xt) 		{ if ( xt < 0 ) xt = xt * -1.0; return (xt); }
define pow(at,bt)	{ xt = e(l(at) * bt); return (xt); }
define main(x,y, utmz){
	drad	= 4*a(1) / 180
	a	= 6378137.0;
	f	= 1 / 298.2572236;
	b 	= a*(1-f);
	k0	= 0.9996;			
	b	= a * ( 1 - f );		
	e 	= sqrt( 1 - ( b/a ) * (b/a) );	
	e0 	= e / sqrt(1 - e*e);		
	esq	= (1 - (b/a)*(b/a));	
	e0sq 	= e*e/(1-e*e);	
	zcm	= 3 + 6*(utmz-1) - 180;		
	e1 	= (1 - sqrt(1 - e*e))/(1 + sqrt(1 - e*e)); 
	m0 	= 0;
	m	= m0 + y/k0;
	mu	= m / (a*(1 - esq * ( 1/4 + esq * ( 3/64 + 5*esq/256))));
	phi1	= mu + e1*(3/2 - 27*e1*e1/32)* s(2*mu) + e1*e1*(21/16 -55*e1*e1/32) * s(4*mu);
	phi1	= phi1 + e1*e1*e1*(s(6*mu)*151/96 + e1*s(8*mu)*1097/512);
	c1 	= e0sq * c(phi1) * c(phi1);
	t1 	= tan(phi1) * tan(phi1);
	n1 	= a / sqrt(1 - ((e*s(phi1)) * e*s(phi1)) );
	r1 	= n1*(1-e*e)/ (1- (e*s(phi1) * e*s(phi1)) );
	d 	= (x-500000)/(n1*k0);
	phi	= (d*d)*(1/2 - d*d*(5 + 3*t1 + 10*c1 - 4*c1*c1 - 9*e0sq)/24);
	phi	= phi + d*d*d*d*d*d*(61 + 90*t1 + 298*c1 + 45*t1*t1 -252*e0sq - 3*c1*c1)/720;
	phi	= phi1 - (n1*tan(phi1)/r1)*phi;
	lat 	= ( 1000000 * phi / drad)/1000000;
	lng	= d*(1 + d*d*((-1 -2*t1 -c1)/6 + d*d*(5 - 2*c1 + 28*t1 - 3*c1*c1 +8*e0sq + 24*t1*t1)/120))/c(phi1);
	lngd	= zcm+lng/drad;
	lon	= (1000000*lngd)/1000000;


	latd = lat - i(lat); 
	lond = lon - i(lon); 

	if ( latd > 0.5 ) { 
		latd = 1.0 - latd;
		nlat = lat + 1.0; 
	} else 	nlat = lat;

	if ( lond > 0.5 ) {
		lond = 1.0 - lond;
		nlon = lon + 1.0;
	} else  nlon = lon;
	
	if ( abs( latd ) < $tolerance )  lat = i(nlat);
	if ( abs( lond ) < $tolerance )  lon = i(nlon);

	scale = $scale;

	if ( ( lat >= $UpperLeftLat - 1 ) && ( lat <= $UpperLeftLat ) && ( lon >= $UpperLeftLon ) && ( lon <= ( $UpperLeftLon + 1 ) ) ) {
		lon /= 1;
		lat /= 1;
		print lon, "," , lat, " ";
	} else	print " , " ;
	
}

r = main($x, $y, $zone);

EOM
		((cnt++))
	done
}


downloadTexture(){
	local xoffset="$1"
	local yoffset="$2"
	local LEVEL="$3"
	local file="$4"
	local cnt="0"
	local x=""
	local y=""

	[ -f "$file" ] && return
	log "Downloading texture for $xoffset $yoffset ..."
	for y in {0..7} ; do
	       yT="$[ $yoffset + $y ]"
	       for x in {0..7} ; do
	               xT="$[ $xoffset + $x ]"
	               log "$cnt / 64"
	               downloadTile "${xT}" "${yT}" "$LEVEL" "$OUTPUT_DIR/tmp/raw-${xT}-${yT}.png"
	               convert -page +$[ 256 * $x  ]+$[ 256 * $y ] "$OUTPUT_DIR/tmp/raw-${xT}-${yT}.png" -channel RGB -format PNG32 "$OUTPUT_DIR/tmp/tile-${xT}-${yT}.png"
	               imageList[$cnt]="$OUTPUT_DIR/tmp/tile-${xT}-${yT}.png"
	               rm -f "$OUTPUT_DIR/tmp/tmp-${xT}-${yT}.png"
	               cnt=$[ $cnt + 1 ]
	       done
	done
	convert -channel ALL -normalize -layers mosaic ${imageList[*]} "$file"
	rm -f "$OUTPUT_DIR/tmp/tile-"*
	echo -n "$file"
	

}

# 0 CC
# 1 UL
# 2 UR
# 3 LR
# 4 LL



pointsTextureLatLng(){
	local xoffset="$1"
	local yoffset="$2"
	local ZUTM="$3"
	local LEVEL="$4"
	local padfGeoTransform=( ${5} ${6} ${7} ${8} ${9} ${10} )
	local x=""
	local y=""


	log "Generating texture vertex coordintaes for $xoffset $yoffset ..."
	for y in {0..7} ; do
		for x in {0..7} ; do
			local east="$(  echo "scale = 6; ${padfGeoTransform[0]} + (256 * $x) * ${padfGeoTransform[1]} + (256 * $y) * ${padfGeoTransform[2]}" | bc )"
			local north="$( echo "scale = 6; ${padfGeoTransform[3]} + (256 * $x) * ${padfGeoTransform[4]} + (256 * $y) * ${padfGeoTransform[5]}" | bc )"

			padfGeoTransformNew=( $east ${GeoTransform[1]} ${GeoTransform[2]} $north ${GeoTransform[4]} ${GeoTransform[5]} )

			UTMimageInfo=(  $( imageGeoInfo 	${padfGeoTransformNew[*]} )     )
			imageInfo=( 	$( imageGeoInfoToLatLng "$ZUTM" "${UTMimageInfo[*]}" ) 	)
			imageInfoTest=( ${imageInfo[*]/,/} )
			[ "${#imageInfoTest[*]}" -ne "5" ] && return 1
			echo "${imageInfo[*]}" 
		done
	done
	return 0
}

createTerFile(){
	local file="$1"
	[ -f "${file/.png/.ter}" ] && return
	local name="$( basename "$file")"
	log "Creating Ter file for $name ..."	

# LOAD_CENTER 42.70321 -72.34234 4000 1024
cat > "${file/.png/.ter}" << EOF
A
800
TERRAIN
BASE_TEX_NOWRAP ../images/$name
EOF

}

dsfFileWrite(){
	local args=( $* )

	local n="8"
	local xtoken=( $( seq 0 $( echo "scale = 6; 1 / $n" | bc ) 1 		 ) )
	local ytoken=( $( seq 0 $( echo "scale = 6; 1 / $n" | bc ) 1 | sort -r ) )

	local xsize="${xtoken[1]}"
	local ysize="${xtoken[1]}"
	local patchNum="$1"

	local CC=()
	local LL=()
	local LR=()
	local UR=()
	local UL=()
	local x=""
	local y=""

	local cnt="1"
	local i="0"
	last=$[ ${#args[*]} - 1 ] ; [ "${args[$last]}" -ne "0" ] && return ${args[$last]}
	unset args[$last]

	srtm="srtm_39_04.tif"
	echo "BEGIN_PATCH $patchNum   0.0 -1.0     1 7"
	echo "BEGIN_PRIMITIVE 0"
	while [ ! -z "${args[$cnt]}" ] ; do			
		x="$[ $i % $n ]"
		y="$[ $i / $n ]"
		
 		CC=( $( awk 'BEGIN { printf "%f %f", '${args[$cnt]}'	}' ) ) 
 		UL=( $( awk 'BEGIN { printf "%f %f", '${args[$cnt+1]}'	}' ) ) 
 		UR=( $( awk 'BEGIN { printf "%f %f", '${args[$cnt+2]}'	}' ) ) 
 		LR=( $( awk 'BEGIN { printf "%f %f", '${args[$cnt+3]}'	}' ) ) 
 		LL=( $( awk 'BEGIN { printf "%f %f", '${args[$cnt+4]}'	}' ) ) 
		cnt="$[ $cnt + 5 ]"	


		alt=( $( $WD/dem/getalt $WD/dem/$srtm ${CC[*]} ${UL[*]} ${UR[*]} ${LR[*]} ${LL[*]} ) )
		[ "${#alt[*]}" -ne "5" ] && cnt="$[ $cnt + 5 ]" && continue


		CC[${#CC[*]}]="${alt[0]}"
		UL[${#UL[*]}]="${alt[1]}"
		UR[${#UR[*]}]="${alt[2]}"
		LR[${#LR[*]}]="${alt[3]}"
		LL[${#LL[*]}]="${alt[4]}"

 		local xstart="${xtoken[$x]}"
 		local ystart="${ytoken[$y]}"

                CC[${#CC[*]}]="$( awk 'BEGIN { printf "%f", '$xstart' + '$xsize' / 2 }'	)"
		CC[${#CC[*]}]="$( awk 'BEGIN { printf "%f", '$ystart' - '$ysize' / 2 }'	)" 
                LL[${#LL[*]}]="$( awk 'BEGIN { printf "%f", '$xstart' }' 		)"
		LL[${#LL[*]}]="$( awk 'BEGIN { printf "%f", '$ystart' - '$ysize'  }' 	)" 
                UL[${#UL[*]}]="$( awk 'BEGIN { printf "%f", '$xstart' }' 		)"
		UL[${#UL[*]}]="$( awk 'BEGIN { printf "%f", '$ystart' }' 		)" 
                UR[${#UR[*]}]="$( awk 'BEGIN { printf "%f", '$xstart' + '$xsize' }'	)"
		UR[${#UR[*]}]="$( awk 'BEGIN { printf "%f", '$ystart' }'		)" 
                LR[${#LR[*]}]="$( awk 'BEGIN { printf "%f", '$xstart' + '$xsize' }'	)"
		LR[${#LR[*]}]="$( awk 'BEGIN { printf "%f", '$ystart' - '$ysize'  }'	)" 

echo "
PATCH_VERTEX ${UL[0]} ${UL[1]} ${UL[2]} 0 0 ${UL[3]} ${UL[4]}
PATCH_VERTEX ${UR[0]} ${UR[1]} ${UR[2]} 0 0 ${UR[3]} ${UR[4]}
PATCH_VERTEX ${CC[0]} ${CC[1]} ${CC[2]} 0 0 ${CC[3]} ${CC[4]}
PATCH_VERTEX ${UR[0]} ${UR[1]} ${UR[2]} 0 0 ${UR[3]} ${UR[4]}
PATCH_VERTEX ${LR[0]} ${LR[1]} ${LR[2]} 0 0 ${LR[3]} ${LR[4]}
PATCH_VERTEX ${CC[0]} ${CC[1]} ${CC[2]} 0 0 ${CC[3]} ${CC[4]}
PATCH_VERTEX ${LR[0]} ${LR[1]} ${LR[2]} 0 0 ${LR[3]} ${LR[4]}
PATCH_VERTEX ${LL[0]} ${LL[1]} ${LL[2]} 0 0 ${LL[3]} ${LL[4]}
PATCH_VERTEX ${CC[0]} ${CC[1]} ${CC[2]} 0 0 ${CC[3]} ${CC[4]}
PATCH_VERTEX ${LL[0]} ${LL[1]} ${LL[2]} 0 0 ${LL[3]} ${LL[4]}
PATCH_VERTEX ${UL[0]} ${UL[1]} ${UL[2]} 0 0 ${UL[3]} ${UL[4]}
PATCH_VERTEX ${CC[0]} ${CC[1]} ${CC[2]} 0 0 ${CC[3]} ${CC[4]}"

	
		((i++))
	done
	echo "END_PRIMITIVE"
	echo "END_PATCH"
	echo
	return 0
}

dsfFileOpen(){
	local args=( $* )

cat << EOF
A
800
DSF2TEXT

PROPERTY sim/creation_agent $( basename $0 )
PROPERTY sim/west ${args[1]}
PROPERTY sim/east ${args[3]}
PROPERTY sim/north ${args[0]}
PROPERTY sim/south ${args[2]}
PROPERTY sim/planet earth

EOF

#TERRAIN_DEF terrain_Water
#EOF



}


dsfFileClose(){
	local args=( $* )
	file="$OUTPUT_DIR/Earth nav data/$( getDirName ${args[2]} ${args[1]} )/$( getDSFName ${args[2]} ${args[1]} )"
	log "Merging $( getDirName ${args[2]} ${args[1]} )/$( getDSFName ${args[2]} ${args[1]} ) ..."
	# 45 11 44 12

	cat "${file}_header.txt" 
# cat << EOF
# 
# BEGIN_PATCH 0   0.0 -1.0    1   5
# BEGIN_PRIMITIVE 0
# PATCH_VERTEX ${args[1]} ${args[2]} 0   0 0
# PATCH_VERTEX ${args[3]} ${args[0]} 0   0 0
# PATCH_VERTEX ${args[3]} ${args[2]} 0   0 0
# PATCH_VERTEX ${args[1]} ${args[2]} 0   0 0
# PATCH_VERTEX ${args[1]} ${args[0]} 0   0 0
# PATCH_VERTEX ${args[3]} ${args[0]} 0   0 0
# END_PRIMITIVE
# END_PATCH
# 
# EOF

	cat "${file}_body.txt"

}




ZUTM="$( echo "scale = 6; ( ( ${LR[1]} + ${UL[1]} ) / 2  + 180   ) / 6 + 1" | bc )"
ZUTM="${ZUTM%.*}"

ULxy=( $( getXY ${UL[*]} $LEVEL ) )
LRxy=( $( getXY ${LR[*]} $LEVEL ) )


xdim="$[ ${LRxy[0]%.*} - ${ULxy[0]%.*} ]"
ydim="$[ ${LRxy[1]%.*} - ${ULxy[1]%.*} ]"

xdim="$[ ${xdim/-/} - 1 ]"
ydim="$[ ${ydim/-/} - 1 ]"

xdim="24"
ydim="24"

xstart="${ULxy[0]%.*}"
ystart="${ULxy[1]%.*}"

dsfPath="$OUTPUT_DIR/Earth nav data/$( getDirName ${LR[0]} ${UL[1]} )" ; [ ! -d "$dsfPath" ] && mkdir -p "$dsfPath"
dsfName="$( getDSFName ${LR[0]} ${UL[1]} )"


dsfFileOpen ${UL[*]} ${LR[*]} 	> "$dsfPath/${dsfName}_header.txt"
echo -n				> "$dsfPath/${dsfName}_body.txt" 

geoStart=( 	 	$( getXY 			${UL[*]}		$LEVEL ) )
geoStartUTM=( 	 	$( geoRef			${geoStart[*]}		$LEVEL ) )
geoStartLatLong=( 	$( imageGeoInfoToLatLng 	$ZUTM			"${geoStartUTM[0]/,/},${geoStartUTM[3]/,/}" | tr "," " " ) )

xfirst="0"
yfirst="0"

[ "$( echo "${geoStartLatLong[0]} < ${UL[1]}" | bc )" = "1" ] && xfirst="8"
[ "$( echo "${geoStartLatLong[1]} > ${UL[0]}" | bc )" = "1" ] && yfirst="8" 


GeoTransform=( 	$( geoRef 	${geoStart[*]} 		$LEVEL ) 	)
GeoTransform=( ${GeoTransform[*]/,/} )

log "Upper left coordinates: ${GeoTransform[0]}E ${GeoTransform[3]}N, Zone: $ZUTM, Resolution: ${GeoTransform[1]} / ${GeoTransform[5]} ..."

tolerance="$( echo "scale = 20; ( ${GeoTransform[1]/-/} + ${GeoTransform[5]/-/} ) / 2 / 1000" | bc )"

p="0"

Y="$yfirst"

while : ; do 
	X="$xfirst"
	yoffset="$[ $ystart + $Y ]"

	while : ; do 

		# 2048x2048
		log "$X, $Y ..."
		xoffset="$[ $xstart + $X ]"
		north="$( echo "scale = 6; ${GeoTransform[3]} + (256 * $X) * ${GeoTransform[4]} + (256 * $Y) * ${GeoTransform[5]}" | bc )"
		east="$(  echo "scale = 6; ${GeoTransform[0]} + (256 * $X) * ${GeoTransform[1]} + (256 * $Y) * ${GeoTransform[2]}" | bc )"

		point=( $xoffset $yoffset )
	
		GeoTransformNew=( $east ${GeoTransform[1]} ${GeoTransform[2]} $north ${GeoTransform[4]} ${GeoTransform[5]} )

		dsfFileWrite "$p" $( time pointsTextureLatLng ${point[*]} $ZUTM $LEVEL ${GeoTransformNew[*]}; echo -n " $?" )	>> "$dsfPath/${dsfName}_body.txt"
		if [ "$?" -eq "0" ] ; then
			echo "TERRAIN_DEF ter/texture-$xoffset-$yoffset.ter"		>> "$dsfPath/${dsfName}_header.txt"
			[ ! -f "$OUTPUT_DIR/images/texture-$xoffset-$yoffset.png" ] 	&& downloadTexture	$xoffset $yoffset $LEVEL 	"$OUTPUT_DIR/images/texture-$xoffset-$yoffset.png" 	> /dev/null
			[ ! -f "$OUTPUT_DIR/ter/texture-$xoffset-$yoffset.ter" ] 	&& createTerFile 					"$OUTPUT_DIR/ter/texture-$xoffset-$yoffset.png"		> /dev/null

			((p++))
		fi

		northNext="$( echo "scale = 6; ${GeoTransform[3]} + (256 * ($X+8)) * ${GeoTransform[4]} + (256 * $Y) * ${GeoTransform[5]}" | bc )"
		eastNext="$(  echo "scale = 6; ${GeoTransform[0]} + (256 * ($X+8)) * ${GeoTransform[1]} + (256 * $Y) * ${GeoTransform[2]}" | bc )"
		[ -z "$( imageGeoInfoToLatLng $ZUTM "$eastNext,$northNext" | tr -d ", " )" ]  && break


		X="$[ $X + 8 ]"

	done

	northNext="$( echo "scale = 6; ${GeoTransform[3]} + (256 * $X) * ${GeoTransform[4]} + (256 * ($Y+8)) * ${GeoTransform[5]}" | bc )"
	eastNext="$(  echo "scale = 6; ${GeoTransform[0]} + (256 * $X) * ${GeoTransform[1]} + (256 * ($Y+8)) * ${GeoTransform[2]}" | bc )"
	[ -z "$( imageGeoInfoToLatLng $ZUTM "$eastNext,$northNext" | tr -d ", " )" ] && break

	Y="$[ $Y + 8 ]"
done


dsfFileClose ${UL[*]} ${LR[*]} > "$dsfPath/${dsfName}.txt"


exit 0


 



