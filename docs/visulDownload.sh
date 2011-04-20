#!/bin/bash



downloadTile(){
	xcoord="$1"
	ycoord="$2"
	file="$3"
	wget -q "http://visualimages1.paginegialle.it/xmlvisual.php/europa.imgi?cmd=tile&format=png&x=${xcoord}&y=${ycoord}&z=32&extra=2&ts=256&q=100&rdr=0&sito=visual&v=1" -O "$file"
}

downloadTileZ(){
	xcoord="$1"
	ycoord="$2"
	zcoord="$3"
	file="$4"
	wget -q "http://visualimages1.paginegialle.it/xmlvisual.php/europa.imgi?cmd=tile&format=png&x=${xcoord}&y=${ycoord}&z=${zcoord}&extra=2&ts=256&q=100&rdr=0&sito=visual&v=1" -O "$file"
}

# http://visualimages3.paginegialle.it/xml.php/europa-orto.imgi?cmd=tile&format=jpeg&x=1&y=1&z=32768&extra=2&ts=256&q=65&rdr=0&sito=visual
# http://visualimages3.paginegialle.it/xmlvisual.php/europa.imgi?cmd=tile&format=jpeg&x=8422&y=10628&z=8&extra=2&ts=256&q=60&rdr=0&sito=visual&v=1

# http://visualimages1.paginegialle.it/xml.php/europa-orto.imgi?cmd=tile&format=jpeg&x=8432&y=10648&z=8&extra=2&ts=256&q=65&rdr=0&sito=visual

 
# 16384 x 16384
# 
# 
# 2	65536	1x1
# 4	32768	
# 8	16384	20
# 16	8192	
# 32	4096	
# 64	2048	
# 128	1024
# 256	512
# 512	256
# 1024	128
# 2048	64
# 4096	32
# 8192	16
# 16384	8
# 32768	4
# 

cat << EOM | bc -l


mapwidthlevel1pixel 	= 33554432
mapwidthmeters		= 4709238.7
mapcentreutmeasting	= 637855.35
mapcentreutmnorthing	= 5671353.65




define tan(x) { x = s(x) / c(x); return (x); }

define latlongutm(e,a,t){

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
	h = b / n;
          
	l
	h


}



a = latlongutm(11.617954, 44.811688, 32)


EOM
echo "
x = 8432
y = 10648
z = 8

"

exit 0

# http://visualimages1.paginegialle.it/xml.php/europa-orto.imgi?cmd=tile&format=jpeg&x=8432&y=10648&z=8&extra=2&ts=256&q=65&rdr=0&sito=visual
xoffset="0"
yoffset="0"

pi="$( echo "scale=32; 4*a(1)" | bc -l )"

lat="44.811688"
lon="11.617954"

cnt="0"
for y in $( seq 0  1 ) ; do
	yT="$[ $yoffset + $y ]"
	for x in $( seq 0  1 ) ; do
		xT="$[ $xoffset + $x ]"

		echo "${xT} ${yT}"
		downloadTileZ  "$xT" "$yT" 65536  "tmp-${xT}-${yT}.png"
		# downloadTileZ  "$xT" "$yT" 32768 "tmp-${xT}-${yT}.png"
		# downloadTile   "$xT" "$yT" "tmp-${xT}-${yT}.png"
		convert -page +$[ 256 * $x  ]+$[ 256 * $y ] "tmp-${xT}-${yT}.png" -format PNG32 "tile-${xT}-${yT}.png"
		imageList[$cnt]="tile-${xT}-${yT}.png"
		rm -f "tmp-${xT}-${yT}.png"
		cnt=$[ $cnt + 1 ]
	done
done

convert  -layers mosaic ${imageList[*]} map.png
