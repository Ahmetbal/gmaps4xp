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

UL=( 44 11 )
LR=( 43 12 )
LEVEL="4"
OUTPUT_DIR="$1"

log "Directory Tree creation ..."

[ ! -d "$OUTPUT_DIR" ] 		&& mkdir "$OUTPUT_DIR"
[ ! -d "$OUTPUT_DIR/images" ] 	&& mkdir "$OUTPUT_DIR/images"
[ ! -d "$OUTPUT_DIR/ter" ] 	&& mkdir "$OUTPUT_DIR/ter"
[ ! -d "$OUTPUT_DIR/tmp" ] 	&& mkdir "$OUTPUT_DIR/tmp"














downloadTile(){
	local xcoord="$1"
	local ycoord="$2"
	local zcoord="$3"
	local file="$4"
	local server="$[ ( $xcoord % 4 )  + 1 ]"
	wget -q "http://visualimages${server}.paginegialle.it/xml.php/europa-orto.imgi?cmd=tile&format=png&x=${xcoord}&y=${ycoord}&z=${zcoord}&extra=2&ts=256&q=100&rdr=0&sito=visual"		-O "$file"
}

# http://visualimages3.paginegialle.it/xml.php/europa-orto.imgi?cmd=tile&format=jpeg&x=1&y=1&z=32768&extra=2&ts=256&q=65&rdr=0&sito=visual
# http://visualimages3.paginegialle.it/xmlvisual.php/europa.imgi?cmd=tile&format=jpeg&x=8422&y=10628&z=8&extra=2&ts=256&q=60&rdr=0&sito=visual&v=1
# http://visualimages1.paginegialle.it/xml.php/europa-orto.imgi?cmd=tile&format=jpeg&x=8432&y=10648&z=8&extra=2&ts=256&q=65&rdr=0&sito=visual
 
getXY(){
	local lat="$1"
	local lon="$2"
	local zoom="$3"
 	local zone="$( echo "scale = 6; ( $lon   + 180   ) / 6 + 1" | bc )"
	zone="${zone%.*}"

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
        lat="$1"
        lon="$2"
        [ -z "$lat" ] && log "getDirName Latitude is empty"     && exit 1
        [ -z "$lon" ] && log "getDirName Longitude is empty"    && exit 1



        [  "$( echo "$lat < 0" | bc -l )" = 1 ] && lat="$( echo "scale = 8; $lat - 10.0" | bc -l )"

        int="${lat%.*}"
        [ -z "$int" ] && int="0"
        lat="$( echo  "$int - ( $int % 10 )" | bc )"
        [ -z "$( echo "${lat%.*}" | tr -d "-" )" ] && lat="$( echo "$lat" | sed -e s/"\."/"0\."/g )"
        [ "$( echo "$lat > 0" | bc -l )" = 1  ] && lat="+$lat"

        [ "$( echo -n "$lat" | tr -d "+-" | wc -c | awk {'print $1'} )" = "1" ] && lat="$( echo "$lat" | sed -e s/"+"/"+0"/g |  sed -e s/"-"/"-0"/g )"


        [  "$( echo "$lon < 0" | bc -l )" = 1 ] && lon="$( echo "scale = 8; $lon - 10.0" | bc -l )"

        int="${lon%.*}"
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
        lat="$1"
        lon="$2"
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
	

	x="$( echo "$x" | awk -F. {'print "0."$2'} )"
	y="$( echo "$y" | awk -F. {'print "0."$2'} )"

	local ULx="$( echo "scale = 6; $E - ( $pixelRes * $x )" | bc )"
	local ULy="$( echo "scale = 6; $N + ( $pixelRes * $y )" | bc )"
	pixelRes="$( echo "scale = 6; 4709238.7 / ${TILE_LEVEL[$zoom]} / 256" | bc )"

	echo -n "$ULx, $pixelRes, 0.0, $ULy, 0.0, $pixelRes"

}

imageGeoInfo(){
	local padfGeoTransform=( $( echo "$*" | tr "," " " ) )


	# Center
	local dfPixel="128"
	local dfLine="128"
	local pdfGeoX="$( echo "scale = 6; ${padfGeoTransform[0]} + $dfPixel * ${padfGeoTransform[1]} + $dfLine * ${padfGeoTransform[2]}" | bc )"
	local pdfGeoY="$( echo "scale = 6; ${padfGeoTransform[3]} + $dfPixel * ${padfGeoTransform[4]} + $dfLine * ${padfGeoTransform[5]}" | bc )"
	echo -n "$pdfGeoX,$pdfGeoY "

	# Upper left
	dfPixel="0"
	dfLine="0"
	pdfGeoX="$( echo "scale = 6; ${padfGeoTransform[0]} + $dfPixel * ${padfGeoTransform[1]} + $dfLine * ${padfGeoTransform[2]}" | bc )"
	pdfGeoY="$( echo "scale = 6; ${padfGeoTransform[3]} + $dfPixel * ${padfGeoTransform[4]} + $dfLine * ${padfGeoTransform[5]}" | bc )"
	echo -n "$pdfGeoX,$pdfGeoY "


	# Upper right
	dfPixel="255"
	dfLine="0"
	pdfGeoX="$( echo "scale = 6; ${padfGeoTransform[0]} + $dfPixel * ${padfGeoTransform[1]} + $dfLine * ${padfGeoTransform[2]}" | bc )"
	pdfGeoY="$( echo "scale = 6; ${padfGeoTransform[3]} + $dfPixel * ${padfGeoTransform[4]} + $dfLine * ${padfGeoTransform[5]}" | bc )"
	echo -n "$pdfGeoX,$pdfGeoY "


	# Lower right
	dfPixel="255"
	dfLine="255"
	pdfGeoX="$( echo "scale = 6; ${padfGeoTransform[0]} + $dfPixel * ${padfGeoTransform[1]} + $dfLine * ${padfGeoTransform[2]}" | bc )"
	pdfGeoY="$( echo "scale = 6; ${padfGeoTransform[3]} + $dfPixel * ${padfGeoTransform[4]} + $dfLine * ${padfGeoTransform[5]}" | bc )"
	echo -n "$pdfGeoX,$pdfGeoY "

	# Lower left
	dfPixel="0"
	dfLine="255"
	pdfGeoX="$( echo "scale = 6; ${padfGeoTransform[0]} + $dfPixel * ${padfGeoTransform[1]} + $dfLine * ${padfGeoTransform[2]}" | bc )"
	pdfGeoY="$( echo "scale = 6; ${padfGeoTransform[3]} + $dfPixel * ${padfGeoTransform[4]} + $dfLine * ${padfGeoTransform[5]}" | bc )"
	echo -n "$pdfGeoX,$pdfGeoY"



}


imageGeoInfoToLatLng(){
	args=( $* )

	zone="${args[0]}"

	cnt="1"
	while [ ! -z "${args[$cnt]}" ] ; do
		x="${args[$cnt]%,*}"
		y="${args[$cnt]#*,}"
cat << EOM | bc -l 
define i(xt) 		{  auto s ; s = scale; scale = 0; xt /= 1; scale = s; return (xt); }
scale = 20
define tan(xt) 		{ xt = s(xt) / c(xt); return (xt); }
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
	c1 	= e0sq * pow(c(phi1),2);
	t1 	= pow(tan(phi1),2);
	n1 	= a / sqrt(1 - pow(e*s(phi1),2));
	r1 	= n1*(1-e*e)/(1-pow(e*s(phi1),2));
	d 	= (x-500000)/(n1*k0);
	phi	= (d*d)*(1/2 - d*d*(5 + 3*t1 + 10*c1 - 4*c1*c1 - 9*e0sq)/24);
	phi	= phi + pow(d,6)*(61 + 90*t1 + 298*c1 + 45*t1*t1 -252*e0sq - 3*c1*c1)/720;
	phi	= phi1 - (n1*tan(phi1)/r1)*phi;
	lat 	= ( 1000000 * phi / drad)/1000000;
	lng	= d*(1 + d*d*((-1 -2*t1 -c1)/6 + d*d*(5 - 2*c1 + 28*t1 - 3*c1*c1 +8*e0sq + 24*t1*t1)/120))/c(phi1);
	lngd	= zcm+lng/drad;
	lon	= (1000000*lngd)/1000000;


	/*
	if ( lat > ${UL[0]} ) lat = i(lat);
	if ( lat < ${LR[0]} ) lat = i(lat) + 1;

	if ( lon < ${UL[1]} ) lon = i(lon) + 1;
	if ( lon > ${LR[1]} ) lon = i(lon);
	*/
	print	lon, "," , lat, " "
}

r = main($x, $y, $zone)

EOM
		cnt="$[ $cnt + 1 ]"
	done
}



downloadTexture(){
	xoffset="$1"
	yoffset="$2"
	LEVEL="$3"
	file="$4"
	cnt="0"
	[ -f "$file" ] && return
	log "Downloading texture for $xoffset $yoffset ..."
	for y in $( seq 0  7 ) ; do
	       yT="$[ $yoffset + $y ]"
	       for x in $( seq 0  7 ) ; do
	               xT="$[ $xoffset + $x ]"
	               log "$cnt / 64"
	               downloadTile "${xT}" "${yT}" "$LEVEL" "$OUTPUT_DIR/tmp/raw-${xT}-${yT}.png"
	               convert -page +$[ 256 * $x  ]+$[ 256 * $y ] "$OUTPUT_DIR/tmp/raw-${xT}-${yT}.png" -format PNG32 "$OUTPUT_DIR/tmp/tile-${xT}-${yT}.png"
	               imageList[$cnt]="$OUTPUT_DIR/tmp/tile-${xT}-${yT}.png"
	               rm -f "$OUTPUT_DIR/tmp/tmp-${xT}-${yT}.png"
	               cnt=$[ $cnt + 1 ]
	       done
	done
	convert  -layers mosaic ${imageList[*]} "$file"
	rm -f "$OUTPUT_DIR/tmp/tile-"*
	echo -n "$file"
	

}

pointsTextureLatLng(){
	local xoffset="$1"
	local yoffset="$2"
	local E="$3"
	local N="$4"
	local ZUTM="$5"
	local LEVEL="$6"
	local xres="$7"
	local yres="$8"
	log "Generating texture vertex coordintaes for $xoffset $yoffset ..."
	cnt="0"
	for y in $( seq 0  7 ) ; do
		yT="$[ $yoffset + $y ]"
		for x in $( seq 0  7 ) ; do
			xT="$[ $xoffset + $x ]"

			east="$(	echo "scale = 20; $xres * 256 * $x + $E" | bc )"
			north="$( 	echo "scale = 20; $yres * 256 * $y + $N" | bc )"

			GeoTransform=(  $( geoRef ${xT} ${yT} $east $north $LEVEL )   )
			UTMimageInfo=(  $( imageGeoInfo 	${GeoTransform[*]} )            )
			imageInfo=( 	$( imageGeoInfoToLatLng "$ZUTM" "${UTMimageInfo[*]}" ) 	)

			echo "${imageInfo[*]}"
			cnt=$[ $cnt + 1 ]
		done
	done

}

createTerFile(){
	file="$1"
	[ -f "${file/.png/.ter}" ] && return
	name="$( basename "$file")"
	log "Creating Ter file for $name ..."	
cat > "${file/.png/.ter}" << EOF
A
800
TERRAIN
BASE_TEX_NOWRAP ter/$name
EOF

}

checkTheDot(){
	for i in $* ; do
		[ "$i" = "0" ]				 && echo -n "0.000000 "				&& continue
		[ -z "$( echo "${i%.*}" | tr -d "-" )" ] && echo -n "$i " | sed -e s/"\."/"0\."/g 	&& continue
		echo -n "$i "
	done
}

dsfFileWrite(){
	local args=( $* )
	token=( $( seq 0 $( echo "scale = 6; 1 / 8" | bc ) 1 ) )

	xsize="${token[1]}"
	ysize="${token[1]}"
	patchNum="$1"

	local CC=()
	local LL=()
	local LR=()
	local UR=()
	local UL=()

	cnt="1"
	i="0"

	echo "BEGIN_PATCH $patchNum   0.0 -1.0     1 7"
	echo "BEGIN_PRIMITIVE 0"
	while [ ! -z "${args[$cnt]}" ] ; do			
		CC=( ${args[$cnt]/,/ } 0.0 ) ; cnt="$[ $cnt + 1 ]"
		LL=( ${args[$cnt]/,/ } 0.0 ) ; cnt="$[ $cnt + 1 ]"
		LR=( ${args[$cnt]/,/ } 0.0 ) ; cnt="$[ $cnt + 1 ]"
		UR=( ${args[$cnt]/,/ } 0.0 ) ; cnt="$[ $cnt + 1 ]"
		UL=( ${args[$cnt]/,/ } 0.0 ) ; cnt="$[ $cnt + 1 ]"
		
		
		x="$[ $i % 8 ]"
		y="$[ $i / 8 ]"

		local xstart="${token[$x]}"
		local ystart="${token[$y]}"

		CC=( ${CC[*]} $( echo "scale = 6; $xstart + $xsize / 2" 	| bc ) $( echo "scale = 6; $ystart + $ysize / 2" 	| bc ) )
		LL=( ${LL[*]} $( echo "scale = 6; $xstart" 			| bc ) $( echo "scale = 6; $ystart + $ysize" 		| bc ) )
                LR=( ${LR[*]} $( echo "scale = 6; $xstart + $xsize" 		| bc ) $( echo "scale = 6; $ystart + $ysize" 		| bc ) )
                UR=( ${UR[*]} $( echo "scale = 6; $xstart + $xsize" 		| bc ) $( echo "scale = 6; $ystart" 			| bc ) )
		UL=( ${UL[*]} $( echo "scale = 6; $xstart"			| bc ) $( echo "scale = 6; $ystart" 			| bc ) )

		CC=( $( checkTheDot ${CC[*]} ) )
		LL=( $( checkTheDot ${LL[*]} ) )
		LR=( $( checkTheDot ${LR[*]} ) )
		UR=( $( checkTheDot ${UR[*]} ) )
		UL=( $( checkTheDot ${UL[*]} ) )


		echo "PATCH_VERTEX ${UL[0]} ${UL[1]} ${UL[2]} ${UL[3]} ${UL[4]}"
		echo "PATCH_VERTEX ${UR[0]} ${UR[1]} ${UR[2]} ${UR[3]} ${UR[4]}"
		echo "PATCH_VERTEX ${CC[0]} ${CC[1]} ${CC[2]} ${CC[3]} ${CC[4]}"
		echo "PATCH_VERTEX ${UR[0]} ${UR[1]} ${UR[2]} ${UR[3]} ${UR[4]}"
		echo "PATCH_VERTEX ${LR[0]} ${LR[1]} ${LR[2]} ${LR[3]} ${LR[4]}"
		echo "PATCH_VERTEX ${CC[0]} ${CC[1]} ${CC[2]} ${CC[3]} ${CC[4]}"
		echo "PATCH_VERTEX ${LR[0]} ${LR[1]} ${LR[2]} ${LR[3]} ${LR[4]}"
		echo "PATCH_VERTEX ${LL[0]} ${LL[1]} ${LL[2]} ${LL[3]} ${LL[4]}"
		echo "PATCH_VERTEX ${CC[0]} ${CC[1]} ${CC[2]} ${CC[3]} ${CC[4]}"
		echo "PATCH_VERTEX ${LL[0]} ${LL[1]} ${LL[2]} ${LL[3]} ${LL[4]}"
		echo "PATCH_VERTEX ${UL[0]} ${UL[1]} ${UL[2]} ${UL[3]} ${UL[4]}"
		echo "PATCH_VERTEX ${CC[0]} ${CC[1]} ${CC[2]} ${CC[3]} ${CC[4]}"
	
		i="$[ $i + 1 ]"
	echo 
	done
	echo "END_PRIMITIVE"
	echo "END_PATCH"
	echo


# cat << EOF
# A
# 800
# DSF2TEXT
# 
# PROPERTY sim/west -118
# PROPERTY sim/east -117
# PROPERTY sim/north 33
# PROPERTY sim/south 32
# PROPERTY sim/planet earth
# 
# TERRAIN_DEF example1/ortho_1_1.ter
# 
# 
# BEGIN_PATCH 0   0.0 -1.0    1   5
# BEGIN_PRIMITIVE 0
# PATCH_VERTEX -117.5 32.5 0   0 0
# PATCH_VERTEX -117.0 33.0 0   0 0
# PATCH_VERTEX -117.0 32.5 0   0 0
# PATCH_VERTEX -117.5 32.5 0   0 0
# PATCH_VERTEX -117.5 33.0 0   0 0
# PATCH_VERTEX -117.0 33.0 0   0 0
# END_PRIMITIVE
# END_PATCH
# 
# 
# BEGIN_PATCH 1   0.0 -1.0     1 7
# BEGIN_PRIMITIVE 0
# PATCH_VERTEX -118.0  32.0  0    0 0     0  0
# PATCH_VERTEX -117.75 32.25 0    0 0     1  1
# PATCH_VERTEX -117.75 32.0  0    0 0     1  0
# PATCH_VERTEX -118.0  32.0  0    0 0     0  0
# PATCH_VERTEX -118.0  32.25 0    0 0     0  1
# PATCH_VERTEX -117.75 32.25 0    0 0     1  1
# END_PRIMITIVE
# END_PATCH
# EOF
# 

}

dsfFileOpen(){
	local args=( $* )

cat << EOF
A
800
DSF2TEXT

PROPERTY sim/west ${args[1]}
PROPERTY sim/east ${args[3]}
PROPERTY sim/north ${args[0]}
PROPERTY sim/south ${args[2]}
PROPERTY sim/planet earth

TERRAIN_DEF terrain_Water
EOF

}


dsfFileClose(){
	local args=( $* )
	file="$OUTPUT_DIR/Earth nav data/$( getDirName ${args[0]} ${args[1]} )/$( getDSFName ${args[0]} ${args[1]} )"
	log "Merging $( getDirName ${args[0]} ${args[1]} )/$( getDSFName ${args[0]} ${args[1]} ) ..."
	cat "${file}_header.txt"
cat << EOF

BEGIN_PATCH 0   0.0 -1.0    1   5
BEGIN_PRIMITIVE 0
PATCH_VERTEX ${args[1]} ${args[2]} 0   0 0
PATCH_VERTEX ${args[3]} ${args[0]} 0   0 0
PATCH_VERTEX ${args[3]} ${args[2]} 0   0 0
PATCH_VERTEX ${args[1]} ${args[2]} 0   0 0
PATCH_VERTEX ${args[1]} ${args[0]} 0   0 0
PATCH_VERTEX ${args[3]} ${args[0]} 0   0 0
END_PRIMITIVE
END_PATCH

EOF

	cat "${file}_body.txt"

}




ZUTM="$( echo "scale = 6; ( ( ${LR[1]} + ${UL[1]} ) / 2  + 180   ) / 6 + 1" | bc )"
ZUTM="${ZUTM%.*}"

ULxy=( $( getXY ${UL[*]} $LEVEL ) )
LRxy=( $( getXY ${LR[*]} $LEVEL ) )


# 13723.25101555891372982272 22689.35084891281885298688 255466.98059949764000542437 4765182.92750310975742263764
# 16540.51900923035460075520 21933.44691970205869703168 660349.41053324106144621975 4873817.32804392311746190367



xsize="$[ ${LRxy[0]%.*} - ${ULxy[0]%.*} ]"
ysize="$[ ${LRxy[1]%.*} - ${ULxy[1]%.*} ]"
xsize="$[ ${xsize/-/} - 1 ]"
ysize="$[ ${ysize/-/} - 1 ]"

xstart="${ULxy[0]%.*}"
ystart="${ULxy[1]%.*}"

dsfPath="$OUTPUT_DIR/Earth nav data/$( getDirName ${UL[*]} )" ; [ ! -d "$dsfPath" ] && mkdir -p "$dsfPath"
dsfName="$( getDSFName ${UL[*]} )"


dsfFileOpen ${UL[*]} ${LR[*]} 	> "$dsfPath/${dsfName}_header.txt"
echo -n				> "$dsfPath/${dsfName}_body.txt" 

geoStart=( 	$( getXY 	${UL[*]}		$LEVEL ) 	)
GeoTransform=( 	$( geoRef 	${geoStart[*]} 		$LEVEL ) 	)


p="1"
for y in $( seq 0 8 $ysize ) ; do
	for x in $( seq 0 8 $xsize ) ; do
		# 2048x2048
		xoffset="$[ $xstart + $x ]"
		yoffset="$[ $ystart - $y ]"
		[ ! -f "$OUTPUT_DIR/images/texture-$xoffset-$yoffset.png" ] 	&& downloadTexture	$xoffset $yoffset $LEVEL 	"$OUTPUT_DIR/images/texture-$xoffset-$yoffset.png" 	> /dev/null
		[ ! -f "$OUTPUT_DIR/ter/texture-$xoffset-$yoffset.ter" ] 	&& createTerFile 					"$OUTPUT_DIR/ter/texture-$xoffset-$yoffset.png"		> /dev/null


		east="$(	echo "scale = 20; ${geoStart[2]} + ${GeoTransform[1]/,/} * 256 * $x" | bc )"
		north="$( 	echo "scale = 20; ${geoStart[3]} - ${GeoTransform[5]/,/} * 256 * $y" | bc )"
		point=( $xoffset $yoffset $east $north )

		dsfFileWrite "$p" $( pointsTextureLatLng ${point[*]} $ZUTM $LEVEL ${GeoTransform[1]/,/} ${GeoTransform[5]/,/} ) >> "$dsfPath/${dsfName}_body.txt"
		echo "TERRAIN_DEF ter/texture-$xoffset-$yoffset.ter"								>> "$dsfPath/${dsfName}_header.txt"
		p="$[ $p + 1 ]"
		
		[ "$p" -eq "2" ] && break
	done
	[ "$p" -eq "2" ] && break
done


dsfFileClose ${UL[*]} ${LR[*]} > "$dsfPath/${dsfName}.txt"
exit



exit 0


 



