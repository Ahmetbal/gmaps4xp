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





downloadTile(){
	xcoord="$1"
	ycoord="$2"
	zcoord="$3"
	file="$4"
	server="$[ ( $xcoord % 4 )  + 1 ]"
	wget -q "http://visualimages${server}.paginegialle.it/xml.php/europa-orto.imgi?cmd=tile&format=png&x=${xcoord}&y=${ycoord}&z=${zcoord}&extra=2&ts=256&q=100&rdr=0&sito=visual"		-O "$file"
}

# http://visualimages3.paginegialle.it/xml.php/europa-orto.imgi?cmd=tile&format=jpeg&x=1&y=1&z=32768&extra=2&ts=256&q=65&rdr=0&sito=visual
# http://visualimages3.paginegialle.it/xmlvisual.php/europa.imgi?cmd=tile&format=jpeg&x=8422&y=10628&z=8&extra=2&ts=256&q=60&rdr=0&sito=visual&v=1
# http://visualimages1.paginegialle.it/xml.php/europa-orto.imgi?cmd=tile&format=jpeg&x=8432&y=10648&z=8&extra=2&ts=256&q=65&rdr=0&sito=visual
 
getXY(){
	lat="$1"
	lon="$2"
	zoom="$3"
	zone="$( echo "scale = 6; ( $lon   + 180   ) / 6 + 1" | bc )"
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


geoRef(){
	x="$1"
	y="$2"
	E="$3"
	N="$4"

	zoom="$5"

	pixelRes="$( echo "scale = 6; 4709238.7 / ${TILE_LEVEL[$zoom]}" | bc )"
	

	x="$( echo "$x" | awk -F. {'print "0."$2'} )"
	y="$( echo "$y" | awk -F. {'print "0."$2'} )"

	ULx="$( echo "scale = 6; $E - ( $pixelRes * $x )" | bc )"
	ULy="$( echo "scale = 6; $N + ( $pixelRes * $y )" | bc )"
	pixelRes="$( echo "scale = 6; 4709238.7 / ${TILE_LEVEL[$zoom]} / 256" | bc )"

	echo -n "$ULx, $pixelRes, 0.0, $ULy, 0.0, $pixelRes"

}

imageGeoInfo(){
	padfGeoTransform=( $( echo "$*" | tr "," " " ) )

	dfPixel="128"
	dfLine="128"
	pdfGeoX="$( echo "scale = 6; ${padfGeoTransform[0]} + $dfPixel * ${padfGeoTransform[1]} + $dfLine * ${padfGeoTransform[2]}" | bc )"
	pdfGeoY="$( echo "scale = 6; ${padfGeoTransform[3]} + $dfPixel * ${padfGeoTransform[4]} + $dfLine * ${padfGeoTransform[5]}" | bc )"
	echo -n "$pdfGeoX,$pdfGeoY "

	dfPixel="0"
	dfLine="0"
	pdfGeoX="$( echo "scale = 6; ${padfGeoTransform[0]} + $dfPixel * ${padfGeoTransform[1]} + $dfLine * ${padfGeoTransform[2]}" | bc )"
	pdfGeoY="$( echo "scale = 6; ${padfGeoTransform[3]} + $dfPixel * ${padfGeoTransform[4]} + $dfLine * ${padfGeoTransform[5]}" | bc )"
	echo -n "$pdfGeoX,$pdfGeoY "

	dfPixel="255"
	dfLine="0"
	pdfGeoX="$( echo "scale = 6; ${padfGeoTransform[0]} + $dfPixel * ${padfGeoTransform[1]} + $dfLine * ${padfGeoTransform[2]}" | bc )"
	pdfGeoY="$( echo "scale = 6; ${padfGeoTransform[3]} + $dfPixel * ${padfGeoTransform[4]} + $dfLine * ${padfGeoTransform[5]}" | bc )"
	echo -n "$pdfGeoX,$pdfGeoY "

	dfPixel="255"
	dfLine="255"
	pdfGeoX="$( echo "scale = 6; ${padfGeoTransform[0]} + $dfPixel * ${padfGeoTransform[1]} + $dfLine * ${padfGeoTransform[2]}" | bc )"
	pdfGeoY="$( echo "scale = 6; ${padfGeoTransform[3]} + $dfPixel * ${padfGeoTransform[4]} + $dfLine * ${padfGeoTransform[5]}" | bc )"
	echo -n "$pdfGeoX,$pdfGeoY "

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
	cnt="0"
	for y in $( seq 0  7 ) ; do
	       yT="$[ $yoffset + $y ]"
	       for x in $( seq 0  7 ) ; do
	               xT="$[ $xoffset + $x ]"
	               echo  "$cnt / 64"
	               downloadTile "${xT}" "${yT}" "$LEVEL" "raw-${xT}-${yT}.png"
	               convert -page +$[ 256 * $x  ]+$[ 256 * $y ] "raw-${xT}-${yT}.png" -format PNG32 "tile-${xT}-${yT}.png"
	               imageList[$cnt]="tile-${xT}-${yT}.png"
	               rm -f "tmp-${xT}-${yT}.png"
	               cnt=$[ $cnt + 1 ]
	       done
	done
	convert  -layers mosaic ${imageList[*]} "texture-$xoffset-$yoffset.png"
	

}
geoRef 16540 21933 4

pointsTextureLatLng(){
	xoffset="$1"
	yoffset="$2"
	LEVEL="$3"
	ZUTM="$4"
	cnt="0"
	echo $xoffset= $yoffset= $LEVEL= $ZUTM=
	for y in $( seq 0  7 ) ; do
		yT="$[ $yoffset + $y ]"
		for x in $( seq 0  7 ) ; do
			xT="$[ $xoffset + $x ]"
			echo geoRef               ${xT} ${yT} $LEVEL
			GeoTransform=(  $( geoRef       	${xT} ${yT} $LEVEL )            )
			#UTMimageInfo=(  $( imageGeoInfo 	${GeoTransform[*]} )            )
			#imageInfo=( 	$( imageGeoInfoToLatLng "$ZUTM" "${UTMimageInfo[*]}" ) 	)
			#echo "${imageInfo[*]}"
			cnt=$[ $cnt + 1 ]
			exit 0
		done
	done
	

}


#UL=( 44.854227 11.597803 )
#LR=( 44.824209 11.636779 )
#UL=( 44.875188 11.575790 )
#LR=( 44.849834 11.607900 )
#UL=( 44.906861 11.609939 )
#LR=( 44.671381 11.808416 )

UL=( 44 11 )
LR=( 42 12 )
LEVEL="4"




ZUTM="$( echo "scale = 6; ( ( ${LR[1]} + ${UL[1]} ) / 2  + 180   ) / 6 + 1" | bc )"
ZUTM="${ZUTM%.*}"

ULxy=( $( getXY ${UL[*]} $LEVEL ) )
LRxy=( $( getXY ${LR[*]} $LEVEL ) )
xsize="$[ ${LRxy[0]%.*} - ${ULxy[0]%.*} ]"
ysize="$[ ${LRxy[1]%.*} - ${ULxy[1]%.*} ]"
xoffset="${ULxy[0]%.*}"
yoffset="${ULxy[1]%.*}"

# 2048x2048
# downloadTexture		$xoffset $yoffset $LEVEL
pointsTextureLatLng 	$xoffset $yoffset $LEVEL $ZUTM



exit 0


lat="44.688468"
lng="11.764775"


point=( 	$( getXY  	$lat $lng $LEVEL ) 	)
GeoTransform=( 	$( geoRef 	${point[*]} $LEVEL ) 		)
UTMimageInfo=( 	$( imageGeoInfo ${GeoTransform[*]} ) 		)

imageInfo=( $( imageGeoInfoToLatLng "$ZUTM" "${UTMimageInfo[*]}" ) )



echo "${imageInfo[*]}"




downloadTile ${point[0]%.*} ${point[1]%.*} "$LEVEL" "tmp.png"

exit


xoffset="${ULxy[0]%.*}"
yoffset="${ULxy[1]%.*}"

 
yT="$[ $yoffset + $y ]"
xT="$[ $xoffset + $x ]"
 
 
 
 



