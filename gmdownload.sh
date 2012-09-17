#!/bin/bash


if [ "$( uname -s )" = "Darwin" ] ; then
	export LC_ALL="us"
	export LANG="us"
	export LC_NUMERIC="us"
	export LC_COLLATE="us"
	export LC_CTYPE="us"
	export LC_MESSAGES="us"
	export LC_MONETARY="us"
	export LC_NUMERIC="us"
	export LC_TIME="us"     
else
	export LANG="en_US.UTF-8"
	export LC_ALL="en_US.UTF-8"
fi


servers_tile=( khm0.google.com khm1.google.com khm2.google.com khm3.google.com )
servers_maps=( mt0.google.com  mt1.google.com  mt2.google.com  mt3.google.com  )
OSM="no"
server_index="0"
SLEEP_TIME="1"
MAX_PERC_COVER="1"


pi="$( echo "scale=10; 4*a(1)" | bc -l )"
tiles_dir="$( dirname -- "$0" )/cache"
UL_LABEL="UL"
LR_LABEL="LR"
PLANE_LABEL="PLANE"
AIRPORT_LABEL="AIRPORT"
PLANE_LABEL_ROT="PLANE_ROT"
AIRPORT_LABEL_ROT="AIRPORT_ROT"
ZOOM_REFERENCE_LABEL="ZOOM_REFERENCE"
MAPS_VERSION=()
XPLANE_CMD_VERSION="920"
TER_DIR="terrain"
TEX_DIR="texture"
MESH_LEVEL="2"
output_index="0"
REMAKE_TILE="no"
TMPFILE="tmp$$"
output=()


DEM_SERVER="ftp://xftp.jrc.it/pub/srtmV4/arcasci/"
DemInMemory=""
DEM_LINE_OFFSET="6"
padfTransform=()
padfTransformInv=()

COOKIES=""
COOKIES_FILE="$( dirname -- "$0" )/cookies.txt"

point_lat="$1"
point_lon="$2"
dim_x="$3"
dim_y="$4"
lowright_lat="$3"
lowright_lon="$4"
output_dir="$5"




file="$1"


# Input is a KML file
if [ -f "$file" ] ; then
	ext="$( echo "$file" | rev | awk -F. {'print $1'} | rev | tr [A-Z] [a-z] )"
	if [ "$ext" = "kmz" ] ; then
		echo "Searching information in the KMZ file \"$( basename -- "$file" )\"..."
		kml=( $( unzip -p "$file" | tr -d " " | tr "\n" " " ) )
	else
		echo "Searching information in the KML file \"$( basename -- "$file" )\"..."
		kml=( $( cat "$file" | tr -d " " | tr "\n" " " ) )
	fi
	cnt="0"
	while [ ! -z "${kml[$cnt]}" ] ; do

		i="0"	
	        for label in $UL_LABEL $LR_LABEL $PLANE_LABEL $AIRPORT_LABEL $PLANE_LABEL_ROT $AIRPORT_LABEL_ROT $ZOOM_REFERENCE_LABEL ; do
	                if [ "${kml[$cnt]}" = "<name>$label</name>" ] ; then
				echo "Found label $label..."
	                        while [ ! -z "${kml[$cnt]}" ] ; do
	                                if [ ! -z  "$( echo "${kml[$cnt]}" | grep "<coordinates>" )" ] ; then
	                             		coord[$i]="$( echo "${kml[$cnt]}" | sed -e s/"<*.coordinates>"/""/g  | awk -F, {'print $2" "$1'} )"
						break;
	        
	                                fi
	                                cnt=$[ $cnt + 1 ]
	                        done
	                fi
			i=$[ $i + 1 ]
	        done
	
	        cnt=$[ $cnt + 1 ]
	done

	point_lat="$( 	 echo "${coord[0]}" | awk {'print $1'} )"
	point_lon="$( 	 echo "${coord[0]}" | awk {'print $2'} )"

	lowright_lat="$( echo "${coord[1]}" | awk {'print $1'} )"
	lowright_lon="$( echo "${coord[1]}" | awk {'print $2'} )"

	zoom_reference_lat="$( echo "${coord[6]}" | awk {'print $1'} )"
	zoom_reference_lon="$( echo "${coord[6]}" | awk {'print $2'} )"

	if [ -z "$point_lat" ] || [ -z "$point_lon" ] || [ -z "$lowright_lat" ] || [ -z "$lowright_lon" ] ; then
		echo "Unable to find Upper left and Lower right corners..."
		if [ "$ext" = "kmz" ] ; then
			kml=( $( unzip -p "$file" | tr "\n" " " ) )
		else
			kml=( $( cat "$file" | tr "\n" " " ) )
		fi

		echo -n "Searching polygon definitions: "
		cnt="0"
		num="0"
		i="0"
		while [ ! -z "${kml[$cnt]}" ] ; do
			if [ "${kml[$cnt]}" = "<LinearRing>" ] ; then
				echo -n "Found $num... "
				rec="stop"
	                        while [ ! -z "${kml[$cnt]}" ] ; do
					[ "${kml[$cnt]}" = "</coordinates>" ] && break
	                             	if [ "$rec" = "start" ] ; then
						poly[$i]="${num},${kml[$cnt]%,*}"
						i=$[ $i + 1 ]
					fi
	                                [ "${kml[$cnt]}" = "<coordinates>"  ] && rec="start"
	                                cnt=$[ $cnt + 1 ]
	                        done
				num="$[ $num + 1 ]"
			fi
			cnt=$[ $cnt + 1 ]
		done
	fi
	echo
	if [ ! -z "${poly[*]}" ] ; then
		point_lat="$( echo "${poly[0]}" | awk -F, {'print $3'} )"
		point_lon="$( echo "${poly[0]}" | awk -F, {'print $2'} )"

		lowright_lat="$( echo "${poly[0]}" | awk -F, {'print $3'} )"
		lowright_lon="$( echo "${poly[0]}" | awk -F, {'print $2'} )"

		for xy in ${poly[*]} ; do
			x="$( echo "$xy" | awk -F, {'print $2'} )"
			y="$( echo "$xy" | awk -F, {'print $3'} )"
			
			[ "$( echo "scale = 8;  $y > $point_lat"    | bc -l )" == 1 ] && point_lat="$y"
			[ "$( echo "scale = 8;  $y < $lowright_lat" | bc -l )" == 1 ] && lowright_lat="$y"
	
			[ "$( echo "scale = 8;  $x < $point_lon"    | bc -l )" == 1 ] && point_lon="$x"
			[ "$( echo "scale = 8;  $x > $lowright_lon" | bc -l )" == 1 ] && lowright_lon="$x"
		done
	fi
	lat_plane="$(	 echo "${coord[2]}" | awk {'print $1'} )"
	lon_plane="$( 	 echo "${coord[2]}" | awk {'print $2'} )"


	lat_runwa="$(	 echo "${coord[3]}" | awk {'print $1'} )"
	lon_runwa="$(	 echo "${coord[3]}" | awk {'print $2'} )"


	lat_plane_rot="$(	 echo "${coord[4]}" | awk {'print $1'} )"
	lon_plane_rot="$(	 echo "${coord[4]}" | awk {'print $2'} )"

	lat_runwa_rot="$(	 echo "${coord[5]}" | awk {'print $1'} )"
	lon_runwa_rot="$(	 echo "${coord[5]}" | awk {'print $2'} )"


	if [ "$lat_plane"     != "" ] && [ "$lon_plane"     != "" ]  && [ "$lon_runwa"     != "" ] && [ "$lon_runwa"     != "" ] && \
	   [ "$lat_plane_rot" != "" ] && [ "$lon_plane_rot" != "" ]  && [ "$lon_runwa_rot" != "" ] && [ "$lon_runwa_rot" != "" ] ; then

		lat_fix="$( echo "scale = 8; $lat_plane - $lat_runwa" | bc -l | awk {'printf "%.8f", $1'} )"
		lon_fix="$( echo "scale = 8; $lon_plane - $lon_runwa" | bc -l | awk {'printf "%.8f", $1'} )"

		[ "$( echo "scale = 8;  $lat_fix >= 0"    | bc -l )" == 1 ] && lat_fix="$( echo "scale = 8; $lat_runwa - $lat_plane" | bc -l | awk {'printf "%.8f", $1'} )"
		[ "$( echo "scale = 8;  $lon_fix >= 0"    | bc -l )" == 1 ] && lon_fix="$( echo "scale = 8; $lon_runwa - $lon_plane" | bc -l | awk {'printf "%.8f", $1'} )"


		m_plane="$( echo "scale = 8; ( $lat_plane + $lat_fix - $lat_plane_rot ) / ( $lon_plane + $lon_fix - $lon_plane_rot )" | bc -l | awk {'printf "%.8f", $1'} )"
		m_runwa="$( echo "scale = 8; ( $lat_runwa + $lat_fix - $lat_runwa_rot ) / ( $lon_runwa + $lon_fix - $lon_runwa_rot )" | bc -l | awk {'printf "%.8f", $1'} )"
		rot_fix="$( echo "scale = 8; (a( ($m_plane -  $m_runwa)/(1+($m_plane + $m_runwa)) ) * ( 180 / $pi ))" | bc -l | awk {'printf "%.8f", $1'} )"
	else
		rot_fix="$3"
	fi


	output_dir="$2"


	
else
	if [ "$1" = "DSF" ] && [ ! -z "$2" ] && [ ! -z "$3" ] && [ ! -z "$4" ] ; then
		lowright_lat="$2"
		point_lon="$3"

		lowright_lon="$[ $point_lon + 1 ]"
		point_lat="$[ $lowright_lat + 1 ]"
		output_dir="$4"
		DSF_CREATION="true"
	fi


	# Input is CLI arguments
	if [ "$DSF_CREATION" != "true" ] ; then 
		if [ -z "$5" ] ; then
			echo "Usage $( basename -- "$0" ) UpperLeft_Lat UpperLeft_Lon LowRight_Lat LowRight_Lon output_directory"
			exit 1
		fi

		#  44.789748
		lat_plane="$( echo "$6" | awk -F, {'print $1'} )"
		#  11.664939
		lon_plane="$( echo "$6" | awk -F, {'print $2'} )"
		#  44.791528
		lat_runwa="$( echo "$7" | awk -F, {'print $1'} )"
		#  11.668357
		lon_runwa="$( echo "$7" | awk -F, {'print $2'} )"
		#  10
		rot_fix="$8"
	fi
fi



if [ "$lat_plane" != "" ] && [ "$lon_plane" != "" ]  && [ "$lon_runwa" != "" ] && [ "$lon_runwa" != "" ] ; then
	lat_fix="$( echo "scale = 8; $lat_plane - $lat_runwa" | bc -l | awk {'printf "%.8f", $1'} )"
	lon_fix="$( echo "scale = 8; $lon_plane - $lon_runwa" | bc -l | awk {'printf "%.8f", $1'} )"
else
	lat_plane="0"
	lon_plane="0"
	lat_runwa="0"
	lon_runwa="0"	
	lat_plane_rot="0"
	lon_plane_rot="0"
	lat_runwa_rot="0"
	lon_runwa_rot="0"
fi

[ -z "$lat_fix" ] && lat_fix="0"
[ -z "$lon_fix" ] && lon_fix="0"
[ -z "$rot_fix" ] && rot_fix="0"


if [ -z "$point_lat" ] || [ -z "$point_lon" ] || [ -z "$lowright_lat" ] || [ -z "$lowright_lon" ] ; then
	echo "Insufficient input paramters..."
	exit 2
fi
echo "Input:"
echo "  - Upper Left corner : $point_lat $point_lon"
echo "  - Lower Right corner: $lowright_lat $lowright_lon"

[ ! -z "$zoom_reference_lat" ] && [ ! -z "$zoom_reference_lon" ] && echo "  - Zoom Reference Point: $zoom_reference_lat $zoom_reference_lon"

echo "Input corrections:"
echo "  - Coord plane :  Lat $lat_plane / Lon $lon_plane | Lat $lat_plane_rot / Lon $lon_plane_rot"
echo "  - Coord runway:  Lat $lat_runwa / Lon $lon_runwa | Lat $lat_runwa_rot / Lon $lon_runwa_rot"
echo "  - Coord correc:  Lat $lat_fix / Lon $lon_fix"
echo "  - Rotation    :  $rot_fix"


osm_center_lat="$( echo "scale = 8; ( $point_lat + $lowright_lat ) / 2 " | bc )"
osm_center_lon="$( echo "scale = 8; ( $point_lon + $lowright_lon ) / 2 " | bc )"

if [  "$DSF_CREATION" = "true" ] ; then
	echo "Creation of a complete DSF file ..."
fi
nfo_file="$tiles_dir/tile_"$point_lat"_"$point_lon"_"$lowright_lat"_"$lowright_lon".nfo"

################################################################################################################33

# Compatibilty for macosx
dsftool=""
ddstool=""
if [ "$( uname -s )" = "Darwin" ] ; then
	# Dsf tool
	dsftool="$( dirname -- "$0" )/ext_app/mac/tools/DSFTool"
	ddstool="$( dirname -- "$0" )/ext_app/mac/tools/DDSTool"
	

	# wget command
	export PATH="$( dirname -- "$0" )/ext_app/wget:$PATH"

	# convert command
	export MAGICK_HOME="$( dirname -- "$0" )/ext_app/ImageMagick-6.4.2"
	export PATH="$MAGICK_HOME/bin:$PATH"
	export DYLD_LIBRARY_PATH="$MAGICK_HOME/lib"

	#  MD5 checksums
	md5sum(){
		md5 $*	
	}

	# sed command
	seq(){
		cnt="$1"
		end=$[ $2 + 1 ]

		[  -z "$2" ] && end="$[ $1 + 1 ]" && cnt="1"

		while [ "$cnt" != "$end" ] ; do
			echo "$cnt"
			cnt="$[ $cnt + 1 ]"	
		done
	
	}
fi	


if [ "$( uname -s )" = "Linux" ] ; then
	# Dsf tool
	if [ -z "$( which convert 2> /dev/null )" ] ; then
		echo "ERROR: Utility missing, you must install the ImageMagick package"
		exit 3
	fi
	if [ -z "$( which wget 2> /dev/null )" ] ; then
		echo "ERROR: Utility missing, you must install the Wget package"
		exit 3
	fi
	dsftool="$( dirname -- "$0" )/ext_app/linux/tools/DSFTool"
	ddstool="$( dirname -- "$0" )/ext_app/linux/tools/DDSTool"
	if [ "$( uname -m )" = "x86_64" ] ; then
		echo "ERROR! Your architecture x86_64 is not supported!"
		exit 3
	fi
fi	

################################################################################################################33

log(){
	if [ -z "$1" ] ; then
		log "Invalid paramters for function log (usage: log \"blabla...\""
		exit 40
	fi	
	echo "$(date) - $1" 1>&2
}

#
# Wrapper for wget command
#




getCookies(){

	indexContent="$( wget   --header='Connection: keep-alive' \
			--header='User-Agent: Mozilla/5.0 (X11; Linux i686) AppleWebKit/537.1 (KHTML, like Gecko) Chrome/21.0.1180.81 Safari/537.1' \
			--header='Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8' \
			--header='Accept-Encoding: deflate,sdch' \
			--header='Accept-Language: en-US,en;q=0.8,it;q=0.6' \
			--header='Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.3' -q -O- --server-response "http://maps.google.com"  2>&1  )"


	khcookie="khcookie=$(   echo "$indexContent" | tr "[]" "\n"  | grep "Map data" | rev | awk -F "\"" {'print $2'} | rev | tr -d " " )"
	PREF="$(                echo "$indexContent" | grep " Set-Cookie: PREF" | cut -f 2- -d ":" | awk -F\; {'print $1'}  | tr -d " " )"

	indexContent="$( wget	--header='Connection: keep-alive' \
				--header='User-Agent: Mozilla/5.0 (X11; Linux i686) AppleWebKit/537.1 (KHTML, like Gecko) Chrome/21.0.1180.81 Safari/537.1' \
				--header='Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8' \
				--header='Accept-Encoding: deflate,sdch' \
				--header='Accept-Language: en-US,en;q=0.8,it;q=0.6' \
				--header='Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.3' \
				--header="Cookie: $khcookie;$PREF" -q -O- --server-response "http://maps.google.com/maps/vp?spn=$1&t=h&z=4&vpsrc=6&vp=$2"  2>&1  )"

	NID="$( echo "$indexContent" | grep " Set-Cookie: NID" | cut -f 2- -d ":" | awk -F\; {'print $1'}  | tr -d " " )"

	COOKIES="$khcookie;$PREF;$NID"

}



ewget(){
	out="$1"
	url="$2"
	if [ -z "$( which wget 2> /dev/null )" ] ; then
		log "ERROR: Utility missing, maybe BUG."
		exit 3
	fi

	if [ -z "$COOKIES" ] ; then
		log "ERROR: Cookies not found!"
		exit 3
	fi

	result="$( wget	--header='Connection: keep-alive' \
			--header='User-Agent: Mozilla/5.0 (X11; Linux i686) AppleWebKit/537.1 (KHTML, like Gecko) Chrome/21.0.1180.81 Safari/537.1' \
			--header='Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8' \
			--header='Accept-Encoding: deflate,sdch' \
			--header='Accept-Language: en-US,en;q=0.8,it;q=0.6' \
			--header='Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.3' \
			--header="Cookie: $COOKIES" -q -O "$out" "$url" )"
	
	if [ ! -z "$( echo $result | grep -i "sorry.google.com" )" ] ; then
		log "Google Maps forbids download of image... Maybe you have to refresh your cookie file!"
		exit 2
	fi
}

swget(){
	url="$1"
	if [ -z "$( which wget 2> /dev/null )" ] ; then
		log "ERROR: Utility missing, maybe BUG."
		exit 3
	fi

	if [ -z "$COOKIES" ] ; then
		log "ERROR: Cookies not found!"
		exit 3
	fi


	result="$( wget	--header='Connection: keep-alive' \
			--header='User-Agent: Mozilla/5.0 (X11; Linux i686) AppleWebKit/537.1 (KHTML, like Gecko) Chrome/21.0.1180.81 Safari/537.1' \
			--header='Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8' \
			--header='Accept-Encoding: deflate,sdch' \
			--header='Accept-Language: en-US,en;q=0.8,it;q=0.6' \
			--header='Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.3' \
			--header="Cookie: $COOKIES" -q -S --spider "$url" )"
	
	if [ ! -z "$( echo $result | grep -i "sorry.google.com" )" ] ; then
		log "Google Maps forbids download of image... Maybe you have to refresh your cookie file!"
		exit 2
	fi

	if [ -z "$( which wget 2> /dev/null )" ] ; then
		log "ERROR: Utility missing, maybe BUG."
		exit 3
	fi
}




addLine(){                                                                                                                                                                       
        line="$1"
        [ -z "$line" ] && line=" "

        output[$output_index]="$line"
        output_index=$[ $output_index + 1 ]
}


isNumber(){
	number="$1"
	bctest="$( echo  "$number"  | bc 2> /dev/null )"
	[ "$bctest" = "$number" ] && echo -n "$number"
}


# 
# Convert Lat lon to UTM

getXY(){
        lon="$1"
        lat="$2"
        zone="$( echo "scale = 6; ( $lon   + 180   ) / 6 + 1" | bc )"
        zone="${zone%.*}"

cat << EOM | bc -l 
mapwidthlevel1pixel     = 33554432
mapwidthmeters          = 4709238.7
mapcentreutmeasting     = 637855.35
mapcentreutmnorthing    = 5671353.65
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

        s
        r
}

a = latlongxy($lon, $lat, $zone)
EOM

}



#
# This funciont return the middle point between two points
#

middlePoint(){
        points=( $* )
	awk 'BEGIN {  printf "%.8f,%.8f ", ( '${points[0]%,*}' + '${points[1]%,*}' ) / 2.0, ( '${points[0]#*,}' + '${points[1]#*,}' ) / 2.0 }'
}



#
# From a square to a sub four square
#

divideSquare(){
        coorners=( $* )
        
	awk 'BEGIN {  printf "%.8f,%.8f ", '${coorners[0]%,*}', '${coorners[0]#*,}' }'
        middlePoint ${coorners[0]} ${coorners[1]}                                
        middlePoint ${coorners[1]} ${coorners[3]}                                
        middlePoint ${coorners[3]} ${coorners[0]}                                
                                                                                 
        middlePoint ${coorners[0]} ${coorners[1]}	                         
	awk 'BEGIN {  printf "%.8f,%.8f ", '${coorners[1]%,*}', '${coorners[1]#*,}' }'
        middlePoint ${coorners[1]} ${coorners[2]}                                
        middlePoint ${coorners[1]} ${coorners[3]}                                
                                                                                 
        middlePoint ${coorners[1]} ${coorners[3]}                                
        middlePoint ${coorners[1]} ${coorners[2]}                                
	awk 'BEGIN {  printf "%.8f,%.8f ", '${coorners[2]%,*}', '${coorners[2]#*,}' }'
        middlePoint ${coorners[2]} ${coorners[3]}                                
                                                                                 
        middlePoint ${coorners[3]} ${coorners[0]}                                
        middlePoint ${coorners[1]} ${coorners[3]}                                
        middlePoint ${coorners[2]} ${coorners[3]}                                
	awk 'BEGIN {  printf "%.8f,%.8f ", '${coorners[3]%,*}', '${coorners[3]#*,}' }'

}



#
# Return the distance between two points in degree
#

pointsDist(){
        a=(  ${1#*,} ${1%,*} ) 
        b=(  ${2#*,} ${2%,*} ) 
                
        dist="$( echo "scale = 8; sqrt( ( ( ${b[1]} - ${a[1]} ) * ( ${b[1]} - ${a[1]} ) ) + ( ( ${b[0]} - ${a[0]} ) * ( ${b[0]} - ${a[0]} ) ) )" | bc -l | awk {'printf "%.8f", $1'} )"
        echo -n "$dist"
}


#
# mostNearPoint "point" "list of points.."
# 
# return the point of the list most near the referement point

mostNearPoint(){
        from="${1#*,}"
        list=( $( echo $2 ) )

        cnt="0"
        index="$cnt"
        dist="$( pointsDist "$from" "${list[$cnt]}" )"
        while [ ! -z "${list[$cnt]}" ] ; do
                new_dist="$( pointsDist "$from" "${list[$cnt]}" )"
                [ "$( echo "scale = 8; $new_dist < $dist" | bc )" = "1" ] && dist="$new_dist" && index="$cnt"
                cnt="$[ $cnt + 1 ]"
        done
        echo -n "${list[$index]}"
}


#
# Function to create KML file for debug the code
#

createKMLoutput(){
	ACT="$1"
	file="$2"
	if [ -z "$file" ] ; then
		log "ERROR: missing file name"
		return
	fi
	if [ "$ACT" = "HEAD" ] ; then
		title="$3"
		[ -z "$title" ] && title="Untitled"
		echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" > "$file"
		echo "<kml xmlns=\"http://www.opengis.net/kml/2.2\" xmlns:gx=\"http://www.google.com/kml/ext/2.2\" xmlns:kml=\"http://www.opengis.net/kml/2.2\" xmlns:atom=\"http://www.w3.org/2005/Atom\">" >> "$file" 
		echo "<Folder>" >> "$file" 
		echo -ne "\t<name>$title</name>\n" >> "$file" 

		echo -ne "\t<Style id=\"yellowLineGreenPoly\">\n" >> "$file"
		echo -ne "\t\t<LineStyle>\n" >> "$file"
		echo -ne "\t\t\t<color>7f00ffff</color>\n" >> "$file"
		echo -ne "\t\t\t<width>4</width>\n" >> "$file"
		echo -ne "\t\t</LineStyle>\n" >> "$file"
		echo -ne "\t\t<PolyStyle>\n" >> "$file"
		echo -ne "\t\t\t<color>7f00ff00</color>\n" >> "$file"
		echo -ne "\t\t</PolyStyle>\n" >> "$file"
		echo -ne "\t</Style>\n" >> "$file"


		#echo -ne "\t<open>1</open>\n" >> "$file" 

	fi
	if [ "$ACT" = "ADD" ] ; then
		if [ "$#" -lt 7 ] ; then
			log "ERROR: missing arguments"
		fi
		image="$3"
		north="$4"
		south="$5"
		east="$6"
		west="$7"

		rotation="$8" 
		[ -z "$rotation" ] && rotation="0"

		name="$( basename -- "$image" | sed -e s/".png"/""/g )"

		echo -ne "\t<GroundOverlay>\n" >> "$file"
		echo -ne "\t\t<name>$name</name>\n" >> "$file"
		#echo -ne "\t\t<Icon>\n"  >> "$file"
		#echo -ne "\t\t\t<href>$image</href>\n"  >> "$file"
				#<viewBoundScale>0.75</viewBoundScale>
		#echo -ne "\t\t</Icon>\n"  >> "$file"

		echo -ne "\t\t<LatLonBox>\n"  >> "$file"

		echo -ne "\t\t\t<north>$north</north>\n"  >> "$file"
		echo -ne "\t\t\t<south>$south</south>\n"  >> "$file"
		echo -ne "\t\t\t<east>$east</east>\n"  >> "$file"
		echo -ne "\t\t\t<west>$west</west>\n"  >> "$file"
		echo -ne "\t\t\t<rotation>$rotation</rotation>\n"  >> "$file"


		echo -ne "\t\t</LatLonBox>\n"  >> "$file"
		echo -ne "\t</GroundOverlay>\n">> "$file"
		echo -ne "\t<Placemark>\n"  >> "$file"
		echo -ne "\t\t<name>$name</name>\n" >> "$file"
      		echo -ne "\t\t<styleUrl>#yellowLineGreenPoly</styleUrl>\n"  >> "$file"
		echo -ne "\t\t<LineString>\n"  >> "$file"
        	echo -ne "\t\t\t<coordinates>$west,$north,100 $east,$north,100 $east,$south,100 $west,$south,100 $west,$north,100</coordinates>\n"  >> "$file"

		echo -ne "\t\t</LineString>\n"  >> "$file"
		echo -ne "\t</Placemark>\n"  >> "$file"


	fi

        if [ "$ACT" = "TRI" ] ; then
                if [ "$#" -lt 5 ] ; then
                        log "ERROR: missing arguments"
                fi
                args=( $* )
		last_arg="$[ ${#args[@]} - 1 ]"
		tri_color="yellowLineGreenPoly"
		if [ "$( echo "${args[$last_arg]}" | awk -F: {'print $1'} )" = "color" ] ; then
			tri_color="$( echo "${args[$last_arg]}" | awk -F: {'print $2'} )"
			unset args[$last_arg]
		fi
                i="2"
                j="0"
                while [ ! -z "${args[$i]}" ] ; do
                        k="$[ $i + 1 ]"
                        gmapspoly[$j]="${args[$i]},${args[$k]},0"
                        j="$[ $j + 1 ]"
                        i="$[ $i + 2 ]"
                done
                echo -ne "\t<Placemark>\n"  >> "$file"
                echo -ne "\t\t<name>Triangle</name>\n" >> "$file"
                echo -ne "\t\t<styleUrl>#$tri_color</styleUrl>\n"  >> "$file"
                echo -ne "\t\t<LineString>\n"  >> "$file"
                echo -ne "\t\t\t<coordinates>${gmapspoly[@]} ${gmapspoly[0]}</coordinates>\n"  >> "$file"

                echo -ne "\t\t</LineString>\n"  >> "$file"
                echo -ne "\t</Placemark>\n"  >> "$file"


        fi

        if [ "$ACT" = "PNT" ] ; then
                lat="${3#*,}" 
                lon="${3%,*}"

                echo -ne "\t<Placemark>\n"  >> "$file"
                #echo -ne "\t\t<name>Point</name>\n" >> "$file"
                echo -ne "\t\t<Point>\n"  >> "$file"
                echo -ne "\t\t\t<coordinates>$lon,$lat,0</coordinates>\n"  >> "$file"
                echo -ne "\t\t</Point>\n"  >> "$file"
                echo -ne "\t</Placemark>\n"  >> "$file"


        fi

	if [ "$ACT" = "END" ] ; then
	
		echo "</Folder>"  >> "$file"
		echo "</kml>"  >> "$file" 
	fi

}

#
# Function return  -crop arguments for convert utility 
#

findWhereIcut(){
	ori="$1"
	sub="$2"

	zoom="$[ $( echo -n "$ori" | wc -c  ) - $( echo -n "$sub" | wc -c  ) ]"
	x_size="$( echo "256 / ( 2^$zoom )" | bc -l | awk -F. {'print $1'} )"
	y_size="$( echo "256 / ( 2^$zoom )" | bc -l | awk -F. {'print $1'} )"
	str="$( echo -n "$ori" | rev | cut -c -$zoom | rev )"
#
# Position of the letter for any quarter of one square
#
#  q | r
# ---+---
#  t | s

	cnt="0"
	x="0"
	y="0"
	i="1"
	while [ ! -z "${str:$cnt:1}" ] ; do
		c="${str:$cnt:1}"

		if [ "$c" = "t" ] ; then
			y="$( echo "scale = 8; $y + 256/( 2^$i )" | bc -l | awk -F. {'print $1'} )"
		fi

		if [ "$c" = "r" ] ; then
			x="$( echo "scale = 8; $x + 256/( 2^$i )" | bc -l | awk -F. {'print $1'} )"
		fi
		if [ "$c" = "s" ] ; then
			x="$( echo "scale = 8; $x + 256/( 2^$i )" | bc -l | awk -F. {'print $1'} )"
			y="$( echo "scale = 8; $y + 256/( 2^$i )" | bc -l | awk -F. {'print $1'} )"
		fi


		i=$[ $i + 1 ]
		cnt=$[ $cnt + 1 ]

	done
	[ "$x" != "0" ] && x=$[ $x - 1 ]
	[ "$y" != "0" ] && y=$[ $y - 1 ]

	echo -n "${x_size}x${y_size}+$x+$y"

}


#
# Check if a point is in o out a ring of points
# 
# return: 	in 	-> inside
#		out 	-> outside


pointInPolygon(){
	x="$1"
	y="$2"
	polvectorSides=( $( echo $3 ) )

	i="0"
	for xy in  ${polvectorSides[*]} ; do
		polvectorX[$i]="polvectorx[$i]=${xy%,*};" 
		polvectorY[$i]="polvectory[$i]=${xy#*,};"
		i=$[ $i + 1 ]
	done

	j="$[ ${#polvectorX[*]} - 1 ]"
	if [ "${polvectorX[0]#*=}" = "${polvectorX[$j]#*=}" ] && [ "${polvectorY[0]#*=}" = "${polvectorY[$j]#*=}" ] ; then
		unset polvectorX[$j]
		unset polvectorY[$j]
		j="$[ ${#polvectorX[*]} - 1 ]"

	fi

cat << EOM | bc -l
	scale 	 = 16;
	x	 = $x;
	y	 = $y;
	oddnodes = 0;
	j	 = ${#polvectorX[*]} - 1;

	${polvectorX[*]}
	${polvectorY[*]}

	for (i = 0; i < ${#polvectorX[*]} ;) {
		if ( polvectory[i] < y && polvectory[j] >= y  || polvectory[j] < y && polvectory[i] >= y ){
			if ( polvectorx[i] + ( y - polvectory[i]) / ( polvectory[j] - polvectory[i] ) * ( polvectorx[j] - polvectorx[i] ) < x ) {
				if ( oddnodes == 0 ) {
					oddnodes = 1;
				}else{
					oddnodes = 0;
				}

			}

		}
		j = i;
		i = i + 1;
	}
	if ( oddnodes == 0 ) {
		print "out";
	}else{
		print "in";
	}

EOM
	
}

MercatorToNormal(){
	y="$1"
# Start BC 
bc -l << EOF | awk '{ printf "%.8f", $1 }'
scale   = 8
y 	= $y
y = s( -1 * y * 4*a(1) / 180 )
y = (1 + y ) / ( 1 - y )
y = 0.5 * l(y)
y = y * 1.0 / (2 * 4*a(1))
y + 0.5
EOF

}




NormalToMercator(){
	y="$1"
# Start BC 
bc -l << EOF | awk '{ printf "%.8f", $1 }'
scale 	= 8
y 	= $y
y = y - 0.5
y = y * (2 * 4*a(1))
y = e(y *2 )
y = ( y - 1 ) / ( y  + 1 )
y = a( y / sqrt( -1 * y * y + 1 ) )
y * -180/(4*a(1))
EOF
# End BC

}

#
# Conversion from lat lon to Google qrst-string
#

GetQuadtreeAddress(){
	lon="$1"
	lat="$2"
	quad="t"
	lookup=( q r t s )
	x="$( echo "scale = 8 ; ( 180 + $lon ) / 360" | bc )"
	y="$( MercatorToNormal $lat )"	
	for i in $( seq 24 ) ; do
		b="0"
		b="$( awk 'BEGIN {  printf "%d", ( 0.'${x#*.}' >= 0.5 ) ? '$b' + 1 : '$b' }' )"
		b="$( awk 'BEGIN {  printf "%d", ( 0.'${y#*.}' >= 0.5 ) ? '$b' + 2 : '$b' }' )"

		quad="$quad${lookup[$b]}"
		x="$( awk 'BEGIN {  printf "%.12f", 0.'${x#*.}' * 2 }' )"
		y="$( awk 'BEGIN {  printf "%.12f", 0.'${y#*.}' * 2 }' )"
	done
	echo "$quad"
}

#
# from qrst-string get the qrst-string next tile on X
#

GetNextTileX(){
	addr="$1"
	forward="$2"
	[ -z "$addr" ]	&& echo "$addr" && return
	i="$[ ${#addr} - 1 ]"
	parent="${addr:0:$i}"
	last="${addr:$i}"
	
	if [ "$last" = "q" ] ; then
		last="r"
		[ "$forward" = 0 ] && parent="$( GetNextTileX $parent $forward )"

	elif [ "$last" = "r" ] ; then
		last="q"
		[ "$forward" = 1 ] && parent="$( GetNextTileX $parent $forward )"


	elif [ "$last" = "s" ] ; then
		last="t"
		[ "$forward" = 1 ] && parent="$( GetNextTileX $parent $forward )"


	elif [ "$last" = "t" ] ; then
		last="s"
		[ "$forward" = 0 ] && parent="$( GetNextTileX $parent $forward )"

	fi
	echo "$parent$last"
}


#
# from qrst-string get the qrst-string next tile on Y
#

GetNextTileY(){
	addr="$1"
	forward="$2"
	[ -z "$addr" ]	&& echo "$addr" && return
	i="$[ ${#addr} - 1 ]"
	parent="${addr:0:$i}"
	last="${addr:$i}"
	
	if [ "$last" = "q" ] ; then
		last="t"
		[ "$forward" = 0 ] && parent="$( GetNextTileY $parent $forward )"

	elif [ "$last" = "r" ] ; then
		last="s"
		[ "$forward" = 0 ] && parent="$( GetNextTileY $parent $forward )"


	elif [ "$last" = "s" ] ; then
		last="r"
		[ "$forward" = 1 ] && parent="$( GetNextTileY $parent $forward )"


	elif [ "$last" = "t" ] ; then
		last="q"
		[ "$forward" = 1 ] && parent="$( GetNextTileY $parent $forward )"

	fi
	echo "$parent$last"
}



qrst2xyz(){
	str="$1"

	# get normalized coordinate first
	x=0
	y=0
	#z=17
	z=0
	gal="Galileo"

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
		z=$[ $z + 1 ]
		cnt=$[ $cnt + 1 ]

	done
	gal="$( echo "$gal" | cut -c -$[ (($x*3+$y)%8)+1 ] )"

	echo -n "x=$x&y=$y&z=$z&s=$gal"
}


GetCoordinatesFromAddress(){
	str="$1"
	ori_str="tile-$str.crd" 

	if [ -f "$tiles_dir/crd/$ori_str" ] ; then
		crd=( $( cat  "$tiles_dir/crd/$ori_str" ) )

		if [ "${#crd[*]}" = "6" ] ; then
			echo "${crd[*]}"
			return
		fi
	fi
	# get normalized coordinate first
	x="0.0"
	y="0.0"
	scale="1.0"
	str="${str:1}" # skip the first character
	
	prec="16"

	for c  in $( echo "$str" | sed 's/./& /g' ) ; do
		scale="$( awk 'BEGIN { printf "%.'$prec'f", '$scale' * 0.5 }' )"

		[ "$c" = "s" ] && x="$( awk 'BEGIN { printf "%.'$prec'f", '$x' + '$scale' }' )" && y="$( awk 'BEGIN { printf "%.'$prec'f", '$y' + '$scale' }' )" 	&& continue
		[ "$c" = "r" ] && x="$( awk 'BEGIN { printf "%.'$prec'f", '$x' + '$scale' }' )"										&& continue
		[ "$c" = "t" ] 								   	&& y="$( awk 'BEGIN { printf "%.'$prec'f", '$y' + '$scale' }' )" 	&& continue

	done

	lon="$(		awk 'BEGIN { printf "%.8f", ( '$x' + '$scale' * 0.5 	- 0.5 ) * 360 }' )"	
	lon_min="$( 	awk 'BEGIN { printf "%.8f", ( '$x' 		  	- 0.5 ) * 360 }' )"
	lon_max="$( 	awk 'BEGIN { printf "%.8f", ( '$x' + '$scale' 		- 0.5 ) * 360 }' )"

	lat_min="$( 	NormalToMercator $y )"
	lat_max="$( 	NormalToMercator $(  awk 'BEGIN { printf "%.8f", '$y' + '$scale' }' ) )"
	lat="$(		NormalToMercator $(  awk 'BEGIN { printf "%.8f", '$y' + '$scale' * 0.5 }' ) )"

	#	0   1    2       3         4        5
	
	echo "$lon $lat $lon_min $lat_min $lon_max $lat_max" > "$tiles_dir/crd/$ori_str"
	echo "$lon $lat $lon_min $lat_min $lon_max $lat_max"
}



getDirName(){
	lat="$1"
	lon="$2"
	[ -z "$lat" ] && log "getDirName Latitude is empty" 	&& exit 1
	[ -z "$lon" ] && log "getDirName Longitude is empty" 	&& exit 1



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
	[ "$( echo -n "$lon" | tr -d "+-" | wc -c | awk {'print $1'} )" = "2" ] && lon="$( echo "$lon" | sed -e s/"+"/"+0"/g  |  sed -e s/"-"/"-0"/g  )"

	[ "$lat" = "0" ] 	&& lat="+00"
	[ -z "$lon" ] 		&& lon="+000"
	echo "$lat$lon"
}

getDSFName(){
	lat="$1"
	lon="$2"
	[ -z "$lat" ] && log "getDSFName Latitude is empty" 	&& exit 1
	[ -z "$lon" ] && log "getDSFName Longitude is empty" 	&& exit 1

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


	[ "$lat" = "0" ] 	&& lat="+00"
	[ "$lon" = "0" ] 	&& lon="+000"
	[ "$lon" = "-000" ] 	&& lon="-001"

	echo "$lat$lon.dsf"
}


upDateServer(){
	# server=( "http://${servers_tile[$server_index]}/kh/v=104&" "http://${servers_maps[$server_index]}/vt/lyrs=m@169000000&style=3&" )

	if [ "${#MAPS_VERSION[*]}" -ne "2" ] ; then
		log "Downloading and update Map Version ..."
		googleMainContent="$( wget -q -O- http://maps.google.com/ | tr ",\"\[\]" "\n" )"
		MAPS_VERSION[0]="$( echo "$googleMainContent" | grep '/kh/v='		| head -n 1 | sed -e 's/&amp;/=/g' | sed -e 's/\\x26/=/g' | awk -F= {'print $2'} )"
		MAPS_VERSION[1]="$( echo "$googleMainContent" | grep '/vt/lyrs=m@'	| head -n 1 | sed -e 's/&amp;/=/g' | sed -e 's/\\x26/=/g' | awk -F= {'print $2'} )"
		log "Image  Map version: ${MAPS_VERSION[0]}"
		log "Street Map version: ${MAPS_VERSION[1]}"
	fi

	server=( "http://${servers_tile[$server_index]}/kh/v=${MAPS_VERSION[0]}&" "http://${servers_maps[$server_index]}/vt/lyrs=${MAPS_VERSION[1]}&style=3&" )

	server_index=$[ $[ $server_index + 1 ] %  ${#servers_maps[@]} ]	
}


tile_size(){  
	RAGGIO_QUADRATICO_MEDIO="6372.795477598"
	info=( $( GetCoordinatesFromAddress $1 ) )

	# $lon $lat $lon_min $lat_min $lon_max $lat_max

	decLonA="${info[2]}"
	decLatA="${info[3]}"

	decLonB="${info[2]}"
	decLatB="${info[5]}"
   
	radLatA="$( 	echo "scale = 16; $pi * $decLatA / 180" | bc -l )"  
	radLonA="$( 	echo "scale = 16; $pi * $decLonA / 180" | bc -l )"
	radLatB="$( 	echo "scale = 16; $pi * $decLatB / 180" | bc -l )"
	radLonB="$( 	echo "scale = 16; $pi * $decLonB / 180" | bc -l )"

  	phi="$( 	echo "scale = 16;  $radLonA - $radLonB" 						| bc -l | tr -d "-" )"  
	P="$( 		echo "scale = 16; (s($radLatA) * s($radLatB)) +  (c($radLatA) * c($radLatB) * c($phi))" | bc -l )"
	P="$( 		echo "scale = 16; a(-1 * $P / sqrt(-1 * $P * $P + 1)) + 2 * a(1)" 			| bc -l )"


	echo "scale=16; $P * $RAGGIO_QUADRATICO_MEDIO * 1000" | bc -l | awk '{ printf "%.4f", $1 }'
  
}  


pointDist(){  
	RAGGIO_QUADRATICO_MEDIO="6372.795477598"

	decLonA="$1";	decLatA="$2"
	decLonB="$3";	decLatB="$4"
   
	radLatA="$( 	echo "scale = 16; $pi * $decLatA / 180" | bc -l )"  
	radLonA="$( 	echo "scale = 16; $pi * $decLonA / 180" | bc -l )"
	radLatB="$( 	echo "scale = 16; $pi * $decLatB / 180" | bc -l )"
	radLonB="$( 	echo "scale = 16; $pi * $decLonB / 180" | bc -l )"

  	phi="$( 	echo "scale = 16;  $radLonA - $radLonB" 						| bc -l | tr -d "-" )"  
	P="$( 		echo "scale = 16; (s($radLatA) * s($radLatB)) +  (c($radLatA) * c($radLatB) * c($phi))" | bc -l )"
	P="$( 		echo "scale = 16; a(-1 * $P / sqrt(-1 * $P * $P + 1)) + 2 * a(1)" 			| bc -l )"


	awk 'BEGIN { printf "%.8f", '$P' * '$RAGGIO_QUADRATICO_MEDIO' * 1000 }'
  
}




tile_resolution(){
	echo "scale=16; $( tile_size $1 ) / 256" | bc | awk '{ printf "%.8f", $1 }'
}


abs(){

	[ "$( echo "scale = 8; $1 < 0.0" | bc  )" = "1" ] && echo $1 | tr -d "-" && return		
	echo "$1"
}


testImage(){
	img="$1"
	[ ! -f "$img" ] && echo -n "bad" && return
	ext="$(echo "$img" | rev | cut -f -1 -d "." | rev )"
	img_info="$( convert "$img" info:- 2> /dev//null )"
	img_info="$( echo "$img_info" | grep -i "$ext" )"
	if [ -z "$img_info" ] ; then
		echo -n "bad"
	else
		echo -n "good"
	fi
}

InvGeoTransform(){
        args=( $* )
bc << EOM | tr "\n" " "
        scale    = 16;
        gt_in[0] = ${args[0]};
        gt_in[1] = ${args[1]};
        gt_in[2] = ${args[2]};
        gt_in[3] = ${args[3]};
        gt_in[4] = ${args[4]};
        gt_in[5] = ${args[5]};


        det     = gt_in[1] * gt_in[5] - gt_in[2] * gt_in[4];
        inv_det = 1.0 / det;

        gt_out[1] =  gt_in[5] * inv_det;
        gt_out[4] = -gt_in[4] * inv_det;
        gt_out[2] = -gt_in[2] * inv_det;
        gt_out[5] =  gt_in[1] * inv_det;
        gt_out[0] = ( gt_in[2] * gt_in[3] - gt_in[0] * gt_in[5]) * inv_det;
        gt_out[3] = (-gt_in[1] * gt_in[3] + gt_in[0] * gt_in[4]) * inv_det;

        gt_out[0]
        gt_out[1]
        gt_out[2]
        gt_out[3]
        gt_out[4]
        gt_out[5]
EOM
}


setAltitudeEnv(){
	lon="$1"
	lat="$2"
	srtm_x="$( awk 'BEGIN { printf "%02d", int( ( 180 + '$lon'  		  ) / ( 360 / 72 ) ) + 1 }' )"
	srtm_y="$( awk 'BEGIN { printf "%02d", int( ( 60  - '$lat' + ( 120 / 24 ) ) / ( 120 / 24 ) )	 }' )"
	dem="srtm_${srtm_x}_${srtm_y}"

	if [ "${DemInMemory}" != "$dem" ] ; then
		if [ ! -f "$tiles_dir/dem/${dem}.asc" ] ; then
			log "Missing DEM file $dem ..."

			cnt="1"
			while [  "$( unzip -t -q "$tiles_dir/dem/${dem}.zip" &> /dev/null ; echo -n $? )" -ne "0" ] ; do
				log "Downloading attempt $cnt ..."
				wget  --timeout 10 -c "ftp://xftp.jrc.it/pub/srtmV4/arcasci/${dem}.zip" -O "$tiles_dir/dem/${dem}.zip"
				cnt=$[ $cnt + 1 ]
			done
			log "Uncompress $dem Zip archive ..."
			unzip -o -q "$tiles_dir/dem/${dem}.zip" -d "$tiles_dir/dem/"

		fi

		DemInMemory="${dem}"
		log "Load DEM $dem in memory ..."
		cnt="0"

		while read DEM[$cnt] ; do cnt="$[ $cnt + 1 ]"; done < "$tiles_dir/dem/${dem}.asc"

		info=( $( cat "$tiles_dir/dem/${dem}.asc" | head -n "$DEM_LINE_OFFSET" | tr -d "\r" | awk '{ print $2 }' | tr "\n" " " ) )
		info[3]="$( awk 'BEGIN { printf "%d", '${info[3]}' + ( 120 / 24 ) }' )"
		padfTransform=( ${info[2]} ${info[4]} 0 ${info[3]} 0 -${info[4]}  )

                padfTransform[1]="${info[4]}"  	# Pixel X size 
                padfTransform[5]="-${info[4]}"	# Pixel Y size
                padfTransform[0]="${info[2]}"	# Lon upper left
                padfTransform[3]="${info[3]}"	# Lat upper left
                padfTransform[2]="0"		# Rotation zero
		padfTransform[4]="0"
		padfTransformInv=( $( InvGeoTransform ${padfTransform[*]} ) )
	fi
}


getAltitude(){
	lon="$1"
	lat="$2"


	Xp="$( awk 'BEGIN { printf "%f", '${padfTransformInv[0]}' + '$lon' * '${padfTransformInv[1]}' + '$lat' * '${padfTransformInv[2]}' 			}' )"
	Yp="$( awk 'BEGIN { printf "%f", '${padfTransformInv[3]}' + '$lon' * '${padfTransformInv[4]}' + '$lat' * '${padfTransformInv[5]}' + '$DEM_LINE_OFFSET' 	}' )"

	xCoords=( $( awk 'BEGIN { printf "%d %d %d %d", '$Xp', '$Yp', '$Xp' + 1, '$Yp' + 1 }' ) )
 	x0=( ${DEM[${xCoords[1]}]} )
 	x1=( ${DEM[${xCoords[3]}]} )


	alt="$( awk 'BEGIN { printf "%f", '${x0[${xCoords[0]}]}' + 0.'${Xp#*.}' * ( '${x0[${xCoords[2]}]}' - '${x0[${xCoords[0]}]}' ) + 0.'${Yp#*.}' * ( '${x1[${xCoords[0]}]}' - '${x0[${xCoords[0]}]}') + 0.'${Xp#*.}' * 0.'${Yp#*.}' * ( '${x1[${xCoords[2]}]}' + '${x0[${xCoords[0]}]}' - '${x1[${xCoords[0]}]}' - '${x0[${xCoords[2]}]}' ) }' )"


	if [ -z "$alt" ] ; then
		log "SEVERE ERROR! This is a BUG!"
		exit 5

	fi

	awk 'BEGIN { printf "%f", '$alt' }' 
}

# setAltitudeEnv 12.000000 44.995882
# getAltitude 12.000000 44.995882
# exit 0

#########################################################################3


r2(){

	a=( $1 )
	b=( $2 )
	[ -z "$2" ] && b=( ${a[*]} ) && a=( $( seq ${#b[*]} ) )

	x="${#a[*]}"
	y="${#b[*]}"
	[ "$x" -ne "$y" ] && return 1


	aa="0.0"; bb="0.0"; cc="0.0"; dd="0.0"; ee="0.0"

	y="0"
	while [ ! -z "${a[$y]}" ] ; do
	        aa="$( awk 'BEGIN { printf "%f",  '$aa' + '${a[$y]}' }' )"
	        bb="$( awk 'BEGIN { printf "%f",  '$bb' + '${b[$y]}' }' )"
	        cc="$( awk 'BEGIN { printf "%f",  '$cc' + ( '${a[$y]}' * '${b[$y]}' ) }' )"
	        dd="$( awk 'BEGIN { printf "%f",  '$dd' + ( '${a[$y]}' * '${a[$y]}' ) }' )"
	        ee="$( awk 'BEGIN { printf "%f",  '$ee' + ( '${b[$y]}' * '${b[$y]}' ) }' )"

	        f="$( awk 'BEGIN { printf "%f",  (( '$x' * '$dd') - ( '$aa' * '$aa' )) * (( '$x' * '$ee' ) - ( '$bb' * '$bb'))  }' )"
	        if [ "$( awk 'BEGIN { printf "%d", ('$f' == 0 ) ? 0 : 1 }' )" -eq "0" ]  ; then
			echo "cacca"
	                ff="0.0"
	                ff2="0.0"
	                break
	        fi
	        ff="$(  awk 'BEGIN { printf "%f", ( ( '$x' * '$cc' ) - ( '$aa' * '$bb' )) / sqrt('$f') }' )"
	        ff2="$( awk 'BEGIN { printf "%f", '$ff' * '$ff' }' )"

	        [ "$ff"  = "nan" ] && ff="0.0" && ff2="0.0" && break
	        [ "$ff2" = "nan" ] && ff="0.0" && ff2="0.0" && break

	        [ "$( awk 'BEGIN { printf "%d", ('$ff'  == 0 ) ? 0 : 1 }' )" -eq "0"  ] && ff="0.0" && ff2="0.0" && break
	        [ "$( awk 'BEGIN { printf "%d", ('$ff2' == 0 ) ? 0 : 1 }' )" -eq "0"  ] && ff="0.0" && ff2="0.0" && break

	        y=$[ $y + 1 ]
	done
	awk 'BEGIN { printf "%.2f", '$ff2' }'

}


#########################################################################3

if [ -z "$output_dir" ] ; then
	log "Output directory missing..."
	exit 1
fi	

if [ -d "$output_dir" ] ; then
	log "Directory \"$output_dir\" already exists..."
else
	log "Create directory \"$output_dir\"..."
	mkdir "$output_dir"
fi


if [ -d "$tiles_dir" ] ; then
	log "Directory \"$tiles_dir\" already exists..."
else
	log "Create directory \"$tiles_dir\"..."
	mkdir "$tiles_dir"
fi


for d in crd map tile mask dds dem ; do
	if [ ! -d "$tiles_dir/$d" ] ; then
		log "Create directory \"$tiles_dir/$d\"..."
		mkdir -p "$tiles_dir/$d"
	fi
done




#########################################################################3

output_sub_dir="Earth nav data"
if [ -d "$output_dir/$output_sub_dir" ] ; then
	log "Sub directory \"$output_sub_dir\" already exists..."
else
	log "Create sub directory \"$output_sub_dir\"..."
	mkdir "$output_dir/$output_sub_dir"
fi



#########################################################################3

log "Creating path to coordinates..."


cursor="$( GetQuadtreeAddress $point_lon $point_lat )"

RESTORE="no" 
if [ -f "$nfo_file" ] ; then
	while : ; do
		echo -n "Found input parameters for this scenery, do you want to restore this section? (y/n) [CTRL+C to abort]: "
		read -n 1 x
                echo
                [ "$x" = "n" ] && RESTORE="no" && break
                [ "$x" = "y" ] && RESTORE="yes" && break
        done
fi

log "Getting Cookies from Google Maps ..."
getCookies "$point_lat,$point_lon" "$lowright_lat,$lowright_lon"

if [ "$RESTORE" = "no" ] ; then
	if [ ! -z "$zoom_reference_lat" ] && [ ! -z "$zoom_reference_lon" ] ; then

		pnt_zoom_ref_lat="$zoom_reference_lat"
		pnt_zoom_ref_lon="$zoom_reference_lon"
		cursor_reference="$( GetQuadtreeAddress $pnt_zoom_ref_lon $pnt_zoom_ref_lat )"
		log "Point for zoom reference from KML file: $pnt_zoom_ref_lat Lat, $pnt_zoom_ref_lon Lon..."

		reference_test="out"
		for i in $( echo ${poly[*]} | tr " " "\n" | awk -F, {'print $1'} | tr "\n" " " ) ; do
			if [ "$(  pointInPolygon "$pnt_zoom_ref_lon" "$pnt_zoom_ref_lat"  "$( echo ${poly[*]} | tr " " "\n" | grep "^${i}," | awk -F, {'print $2","$3'} | tr "\n" " " )" )" = "in" ] ; then
				reference_test="in" && break
			fi
		done
		if [ "$reference_test" = "out" ] ; then
			log "ERROR: Zoom reference point is outside of AOT!"
			exit 2
		fi
	else
		pnt_zoom_ref_lat="$( echo "scale = 8; ( $point_lat + $lowright_lat ) / 2" | bc )"
		pnt_zoom_ref_lon="$( echo "scale = 8; ( $point_lon + $lowright_lon ) / 2" | bc )"
		cursor_reference="$( GetQuadtreeAddress $pnt_zoom_ref_lon $pnt_zoom_ref_lat )"
		log "Point for zoom reference default center image: $pnt_zoom_ref_lat Lat, $pnt_zoom_ref_lon Lon..."
	fi
	while : ; do
		upDateServer
		remote="$( swget "${server[0]}$( qrst2xyz ${cursor_reference} )" 2>&1 )"
		if [ ! -z "$( echo "$remote" | grep "403 Forbidden" )" ] || [ ! -z "$( echo "$remote" | grep "503 Service Unavailable" )" ]  ; then
			log "ERROR from Google Maps: Forbidden! You must wait one day!"
			exit 4
	
		fi
		[ -z "$( echo "$remote" | grep "404 Not Found" )" ] && break
		log "Layer does not exist, dezooming one step..."
		cursor_reference="$( echo "$cursor_reference"  | rev | cut -c 2- | rev  )"

	done
	
	while : ; do
		log "-----------------------------------------------------------"
		log "Tile size: $( tile_resolution $cursor_reference ) meters ( Level: $( echo -n "$cursor_reference" | wc -c ) )..."
		log "Use this URL to view an example: ${server}$( qrst2xyz ${cursor_reference} )"
		echo
		while : ; do
			echo -n "Press [ENTER] to continue or \"-\" to decrease zoom (less tiles) [CTRL+C to abort]: "
			read -n 1 x
			echo
			[ -z "$x" ] 	&& break
			[ "$x" = "-" ] 	&& break
				
		done
		[ -z "$x" ] && break	
		echo "Dezooming one step..."
		cursor_reference="$( echo "$cursor_reference"  | rev | cut -c 2- | rev  )"
	done
	log "Searching ROI size and calculating elaboration time..."
	while : ; do
		log "Getting upper left coordinates..."
		cursor="$( echo $cursor | cut -c -$( echo -n "$cursor_reference" | wc -c | awk {'print $1'} ) )"

		info=( $( GetCoordinatesFromAddress $cursor ) )
		UL_lon=${info[2]}
		UL_lat=${info[3]}


		echo -n "Searching X size..."
	
		dim_x="0"

		cursor_tmp="$cursor"
		while : ; do
			echo -n "."
			c2="$cursor_tmp"
			cursor_tmp="$( GetNextTileX $cursor_tmp 1 )"
	
			info=( $( GetCoordinatesFromAddress $c2 ) )
			x_lon=${info[4]}
	
			[  "$( echo "$x_lon > $lowright_lon" | bc )" = 1 ] && break 
			dim_x=$[ $dim_x + 1 ]
		done
		
		echo
		echo -n "Searching Y size..."
	

		dim_y="0"

		cursor_tmp="$cursor"
		while : ; do
			echo -n "."	
			c2="$cursor_tmp"
			cursor_tmp="$( GetNextTileY $cursor_tmp 1 )"
	
			info=( $( GetCoordinatesFromAddress $c2 ) )
			y_lat=${info[5]}

			[  "$( echo "$y_lat < $lowright_lat" | bc )" = 1 ] && break 
			dim_y=$[ $dim_y + 1 ]
		done
		echo

		if [ "$dim_x" -eq "0" ] || [ "$dim_y" -eq "0" ] ; then
			echo "AOI selected is smaller than one tile, I take the entire tile to create texture..."
		fi
		[ "$dim_x" -le "1" ] && dim_x="8"
		[ "$dim_y" -le "1" ] && dim_y="8"
	
		log "Size of tiles $dim_x x $dim_y ..."

		 [ "$( uname -s )" = "Linux" ]  && end_date="$( date --date=@$[ $(  date +%s ) +  ( $dim_x * $dim_y * $SLEEP_TIME ) ] )"
		 [ "$( uname -s )" = "Darwin" ] && end_date="$( date -v+$[ $dim_x * $dim_y * $SLEEP_TIME ]S )"
		
		log "Estimated end date for download tiles: $end_date..."
		log "Tile site: $( tile_resolution $cursor_reference ) meters ( Level: $( echo -n "$cursor_reference" | wc -c ) )..."
		log "Use this URL to view an example:  ${server}$( qrst2xyz ${cursor_reference} )"
		echo
	
	
		while : ; do
			echo -n "Press [ENTER] to continue or \"-\" to decrease zoom (less tiles) [CTRL+C to abort]: "
			read -n 1 x
			echo
			[ -z "$x" ] 	&& break
			[ "$x" = "-" ] 	&& break
			
		done
		[ -z "$x" ] && break	
		log "Dezooming one step..."
		cursor_reference="$( echo "$cursor_reference"  | rev | cut -c 2- | rev  )"
	done
	echo "dim_x=$dim_x" 	>  "$nfo_file"
	echo "dim_y=$dim_y" 	>> "$nfo_file"
	echo "cursor=$cursor"	>> "$nfo_file"


	while : ; do
		echo -n "Do you want create a simple \"o\"verlay or complete a scenery \"m\"esh (o/m)? [CTRL+C to abort]: "
		read -n 1 x
                echo
                [ "$x" = "m" ] && MASH_SCENARY="yes" && break
                [ "$x" = "o" ] && MASH_SCENARY="no" && break
        done
	echo "MASH_SCENARY=$MASH_SCENARY" >> "$nfo_file"

	if [ "$MASH_SCENARY" = "yes" ] ; then
		log "Force to use Water Mask..."
		WATER_MASK="yes"

		while : ; do
			log "Set MESH LEVEL: $MESH_LEVEL -> $( echo "(4^$MESH_LEVEL) * 2" | bc )  triangles for tile"
			echo -n "Press [ENTER] to continue or \"+/-\" to in/de-crease mesh level [CTRL+C to abort]: "
			read -n 1 x
			echo
			[ -z "$x" ] 			&& break
			[ "$x" = "-" ] 			&& MESH_LEVEL=$[ $MESH_LEVEL - 1 ] 
			[ "$x" = "+" ] 			&& MESH_LEVEL=$[ $MESH_LEVEL + 1 ]
			[ "$x" = "=" ] 			&& MESH_LEVEL=$[ $MESH_LEVEL + 1 ]
			[ "$MESH_LEVEL" = "0" ] 	&& MESH_LEVEL="1"
			[ "$MESH_LEVEL" = "6" ] 	&& MESH_LEVEL="5"	
		done
	else

		while : ; do
			echo -n "Do you want to use water mask? (y/n) [CTRL+C to abort]: "
			read -n 1 x
	                echo
	                [ "$x" = "n" ] && WATER_MASK="no" && break
	                [ "$x" = "y" ] && WATER_MASK="yes" && break
	        done
	fi

	echo "MESH_LEVEL=$MESH_LEVEL" >> "$nfo_file"
	echo "WATER_MASK=$WATER_MASK" >> "$nfo_file"
	log "Creating tiles list..."

	tot=$[ $dim_x * $dim_y ]

	dim_x=$[ $dim_x - 1 ]
	dim_y=$[ $dim_y - 1 ]


	log "Randomizing tile list..."
	log "Step 1 ..."
	tile_index=( $( seq 0 $[ $tot - 1 ] | sort -R | tr "\n" " " ) )

	i="0"
	cnt=1
	cursor_tmp="$cursor"
	for x in $( seq 0 $dim_x ) ; do	
		c2="$cursor_tmp"
		cursor_tmp="$( GetNextTileX $cursor_tmp 1 )"

		log "Step 2: $cnt / $tot, found ${#good_tile[*]} good tiles ..."
		for y in $( seq 0 $dim_y  ) ; do
			tile_check="in"

			if [ ! -z "${poly[*]}" ] ; then	
				for j in $( echo ${poly[*]} | tr " " "\n" | awk -F, {'print $1'}  | sort -u | tr "\n" " " ) ; do
					tmp_poly="$( echo ${poly[*]} | tr " " "\n" | grep "^${j}," | awk -F, {'print $2","$3'} | tr "\n" " " )"
						info=( $( GetCoordinatesFromAddress $c2 ) )
						# $lon $lat $lon_min $lat_min $lon_max $lat_max
	
						tile_check="$( pointInPolygon "${info[2]}" "${info[3]}" "$tmp_poly" )"
						if [ "$tile_check" = "out" ] ; then tile_check="$( pointInPolygon "${info[4]}" "${info[5]}" "$tmp_poly" )" ; else break ; fi
						if [ "$tile_check" = "out" ] ; then tile_check="$( pointInPolygon "${info[2]}" "${info[5]}" "$tmp_poly" )" ; else break ; fi
						if [ "$tile_check" = "out" ] ; then tile_check="$( pointInPolygon "${info[4]}" "${info[3]}" "$tmp_poly" )" ; else break ; fi
				done
			fi

			[ "$tile_check" = "in" ] && good_tile[${tile_index[$i]}]="$c2"

			c_last="$c2"
			c2="$( GetNextTileY $c2 1 )"
			cnt=$[ $cnt + 1 ]
			i=$[ $i + 1 ]
		done
	done
	
	echo
	echo "good_tile=( ${good_tile[@]} )"  >> "$nfo_file"
fi


if [ "$RESTORE" = "yes" ] ; then
	log "Restoring section $nfo_file..."
	. "$nfo_file"
	if 	[ -z "$dim_x" ] 	|| \
	 	[ -z "$dim_y" ] 	|| \
	 	[ -z "$good_tile" ] 	|| \
	 	[ -z "$cursor" ] 	|| \
		[ -z "$MASH_SCENARY" ]	|| \
		[ -z "$MESH_LEVEL" ]	|| \
	 	[ -z "$WATER_MASK" ] 	; then
		log "Input file is corrupted, I must remove it."
		rm -f "$nfo_file"
		exit 2
	fi
	echo
	if [ "$MASH_SCENARY" = "no" ] ; then
		while : ; do
			echo -n "The water mask is set \"$( echo "$WATER_MASK" | tr [a-z] [A-Z] )\", do you want change it? (y/n) [CTRL+C to abort]: "
			read -n 1 x
	                echo
	                [ "$x" = "n" ] && REMAKE_TILE="no"  && break
	                [ "$x" = "y" ] && REMAKE_TILE="yes" && break
	        done
	
		if [ "$REMAKE_TILE" = "yes" ] ; then
			if [ "$WATER_MASK" = "yes" ] ; then
				WATER_MASK="no"
				echo "WATER_MASK=$WATER_MASK" >> "$nfo_file"
			else
				WATER_MASK="yes"
				echo "WATER_MASK=$WATER_MASK" >> "$nfo_file"
			fi
		fi
	fi
fi


#########################################################################3


log "Download tiles..."
cnt="1"
tot="${#good_tile[@]}"

SHIT_COLOR="E4E3DF"

for c2 in ${good_tile[@]} ; do
	# break # TO BE REMOVED
	log  "$cnt / $tot"

	[ "$( testImage "$tiles_dir/tile/tile-$c2.png" )" != "good" ] && rm -f "$tiles_dir/tile/tile-$c2.png"
	
	if [ ! -f "$tiles_dir/tile/tile-$c2.png" ] ; then
		upDateServer
		ewget "$tiles_dir/${TMPFILE}.jpg" "${server[0]}$( qrst2xyz "$c2" )" 
		if [ ! -f "$tiles_dir/${TMPFILE}.jpg" ] ; then
			log "Elaboration problem!!"
			exit 6
		fi
		if [ "$( du -s "$tiles_dir/${TMPFILE}.jpg" | awk {'print $1'} )" != "0" ] ; then
			blank="$( convert  "$tiles_dir/${TMPFILE}.jpg"  -crop 1x255+0+0 txt:- | grep -v "^#" | grep -i "$SHIT_COLOR"  | wc -l )"
			if [  "$( echo "scale = 8; ( $blank > 10 )" | bc )" = "1" ] ; then
				echo -n "" > "$tiles_dir/${TMPFILE}.jpg"
			fi
		fi
		if [ "$( du -s "$tiles_dir/${TMPFILE}.jpg" | awk {'print $1'} )" = "0" ] ; then
			log "In this area I didn't find same tile for this zoom..."
			rm -f "$tiles_dir/${TMPFILE}.jpg"
			upDateServer
			subc2="$c2"
			while [ ! -z "$subc2" ] ; do
				log "Try to zoom out one step..."
				subc2="$( echo "$subc2" | rev | cut -c 2- | rev )"

				ewget  "$tiles_dir/${TMPFILE}.jpg" "${server[0]}$( qrst2xyz "$subc2" )"

				if [ "$( du -s "$tiles_dir/${TMPFILE}.jpg" | awk {'print $1'} )" != "0" ] ; then
					blank="$( convert  "$tiles_dir/${TMPFILE}.jpg"   -crop 1x255+0+0 txt:- | grep -v "^#" | grep -i "$SHIT_COLOR"  | wc -l )"
					if [  "$( echo "scale = 8; ( $blank < 10 )" | bc )" = "1" ] ; then
						break
					else
						rm "$tiles_dir/${TMPFILE}.jpg"
					fi
				fi

				sleep 1
				rm -f "$tiles_dir/${TMPFILE}.jpg"
				upDateServer
			done
			if [ -f "$tiles_dir/${TMPFILE}.jpg" ] ; then
				if  [ "$( du -s "$tiles_dir/${TMPFILE}.jpg" | awk {'print $1'} )" != "0" ] ; then
					convert "$tiles_dir/${TMPFILE}.jpg" -format PNG32 "$tiles_dir/tile/tile-$subc2-ori.png"
					rm -f "$tiles_dir/${TMPFILE}.jpg"
				fi
			fi

			
			if [ ! -z "$subc2" ] ; then
				if  [ "$( du -s "$tiles_dir/tile/tile-$subc2-ori.png" | awk {'print $1'} )" != "0" ]	; then
					log "Found tile with less zoom..."
					convert "$tiles_dir/tile/tile-$subc2-ori.png" -channel RGB -format PNG32 -crop $( findWhereIcut $c2 $subc2 )  -resize 256x256 "$tiles_dir/tile/tile-$c2.png"
				else
					log "Not found file with same zoom... Hole in scenery for tile ${server[0]}$( qrst2xyz "$c2") !"
				fi
			else
				log "Could dot find file with the same zoom... Hole in scenery for tile ${server[0]}$( qrst2xyz "$c2") !"
			fi
			rm -f "$tiles_dir/${TMPFILE}.jpg"
		else
			convert "$tiles_dir/${TMPFILE}.jpg" -channel RGB -format PNG32  "$tiles_dir/tile/tile-$c2.png"
			rm -f "$tiles_dir/${TMPFILE}.jpg"
		fi

		sleep 1
	fi
	cnt=$[ $cnt + 1 ]
done
rm -f "$tiles_dir/${TMPFILE}.jpg"

log "Screnary creation...."
good_tile=( $( echo "${good_tile[@]}" | tr " " "\n" | rev | cut -c 4- | rev | sort -u | tr "\n" " " ) )



####################################################################################################################


log "Merging tiles into 2048x2048 texture..."
[ "$WATER_MASK" = "yes" ] && log "Water mask Enabled..."
tile_seq="$( seq 0 7 )"
prog="1"
tot="${#good_tile[@]}"

# REMAKE_TILE="yes"

for cursor_huge in ${good_tile[@]} ; do
	# break # TO BE REMOVED
	cursor_tmp="${cursor_huge}qqq"

	log "$prog / $tot"

	[ "$REMAKE_TILE" = "yes" ] && [ -f "${tiles_dir}/tile/tile-${cursor_huge}.png" ] 	&& rm -f "${tiles_dir}/tile/tile-${cursor_huge}.png" 
	[ "$( testImage "${tiles_dir}/tile/tile-${cursor_huge}.png" )" != "good" ] 		&& rm -f "${tiles_dir}/tile/tile-${cursor_huge}.png"


	if  [ ! -f "$tiles_dir/tile/tile-$cursor_huge.png" ] ; then
		if [ "$WATER_MASK" = "yes" ] ; then
			[ "$REMAKE_TILE" = "yes" ] && [ -f "${tiles_dir}/mask/mask-${cursor_huge}.png" ] && rm -f "${tiles_dir}/mask/mask-${cursor_huge}.png"

			if  [ ! -f "${tiles_dir}/mask/mask-${cursor_huge}.png" ] ; then
				if [ ! -f "${tiles_dir}/map/map-${cursor_huge}.png" ] ; then
					upDateServer
					ewget "${tiles_dir}/map/map-${cursor_huge}.png" "${server[1]}$( qrst2xyz "$cursor_huge" )"
		                	sleep 1
				fi

				echo -n "Analizing tiles ... "
				# WATER_COLOR="#99b3cc"
				WATER_COLOR="#a5bfdd"
				content="$( convert  "${tiles_dir}/map/map-${cursor_huge}.png" txt:- | grep -v "^#" | grep -i "$WATER_COLOR" | wc -l | tr -d "\n" )" ; [ -z "$content" ] && content="0"

				water_percent="$( awk 'BEGIN { printf "%.2f",  ( '${content}' /  ( 256 * 256 ) ) * 100 }' )"
		
				if [  "$( echo "scale = 8; $water_percent >= $MAX_PERC_COVER" | bc )" = 1 ] ; then
					echo -n " Water found (${water_percent}%) ... "
					convert  -fuzz 8%  "${tiles_dir}/map/map-${cursor_huge}.png" -format PNG32 -transparent "$WATER_COLOR" -filter Cubic -resize 2048x2048 "${tiles_dir}/mask/mask-${cursor_huge}.png"
				else
					echo -n ""  >  "${tiles_dir}/mask/mask-${cursor_huge}.png"	
				fi

				echo -n "Done "
				

			fi
		fi


		cnt="0"
		for x in $tile_seq ; do
			c2="$cursor_tmp"
			cursor_tmp="$( GetNextTileX $cursor_tmp 1 )"
			for y in $tile_seq ; do
				in_file="$( dirname -- "$0" )/ext_app/images/trans.png"

				[ -f "$tiles_dir/tile/tile-$c2.png" ] && in_file="${tiles_dir}/tile/tile-${c2}.png"
					
	                        convert -page +$[ 256 * $x  ]+$[ 256 * $y ] "$in_file" "${tiles_dir}/tile/tile-${cursor_huge}-${x}-${y}.png"
				texture_tile[$cnt]="tile-${cursor_huge}-${x}-${y}.png"
				echo -ne "."
				cnt=$[ $cnt + 1 ]
	
		                c_last="$c2"
		                c2="$( GetNextTileY $c2 1 )"
		        done
		done
		if [ "$WATER_MASK" = "yes" ] ;then
			if [ "$( du -k  "$tiles_dir/mask/mask-$cursor_huge.png" | awk {'print $1'} )" != "0" ] ; then
				convert  -background transparent -layers mosaic "$tiles_dir/tile/{$( echo ${texture_tile[@]} | tr " " ",")}"  -format PNG32 "$tiles_dir/tile/tile-ww-$cursor_huge.png"
				composite -compose Dst_In "$tiles_dir/mask/mask-$cursor_huge.png" "$tiles_dir/tile/tile-ww-$cursor_huge.png" "$tiles_dir/${TMPFILE}.png"
				rm -f "$tiles_dir/tile/tile-ww-$cursor_huge.png"
				convert "$tiles_dir/${TMPFILE}.png" -format PNG32 -transparent "#000000" "$tiles_dir/tile/tile-$cursor_huge.png"
				rm -f "$tiles_dir/${TMPFILE}.png"
			else
				convert -background transparent  -layers mosaic "$tiles_dir/tile/{$( echo ${texture_tile[@]} | tr " " ",")}"  -format PNG32 "$tiles_dir/tile/tile-$cursor_huge.png"
			fi
		else
			convert -background transparent -layers mosaic "$tiles_dir/tile/{$( echo ${texture_tile[@]} | tr " " ",")}" -format PNG32 "$tiles_dir/tile/tile-$cursor_huge.png"
		fi
	

		for r in  ${texture_tile[@]} ; do rm -f "$tiles_dir/tile/$r"; done
	
		unset texture_tile
	
		echo
	fi
	prog=$[ $prog + 1 ]
done
rm -f "$tiles_dir/${TMPFILE}.png"



TER_DIR="$output_dir/$TER_DIR"
TEX_DIR="$output_dir/$TEX_DIR"

if [ ! -d  "$TEX_DIR" ] ; then
        log "Creating directory $TEX_DIR..."
        mkdir -p -- "$TEX_DIR"
else
        log "Directory $TEX_DIR already exists..."
fi


if [ "$MASH_SCENARY" = "yes" ] ; then
	if [ ! -d  "$TER_DIR" ] ; then
	        log "Creating directory $TER_DIR..."
	        mkdir -p -- "$TER_DIR"
	else
	        log "Directory $TER_DIR already exists..."
	fi

	log "Creating MESH grid using level $MESH_LEVEL ..."
	square=( "0,0"  "1,0"  "1,1"  "0,1"  )
	step="1"
	while [ "$step" -lt "$MESH_LEVEL" ] ; do
		square=( $( cnt="0"; while [ ! -z "${square[$cnt]}" ] ; do
					a=$[ $cnt + 1 ]; b=$[ $cnt + 2 ]; c=$[ $cnt + 3 ];
					divideSquare "${square[$cnt]} ${square[$a]} ${square[$b]} ${square[$c]}"; cnt=$[ $cnt + 4 ];
					done ) )
		step=$[ $step + 1 ] 
	done
	cnt="0"
	PATCH_VERTEX=( $( while [ ! -z "${square[$cnt]}" ] ; do
				ll="$cnt"; lr=$[ $cnt + 1 ]; ur=$[ $cnt + 2 ]; ul=$[ $cnt + 3 ]
				echo -n "${square[$ll]} ${square[$ur]} ${square[$lr]} ${square[$ll]} ${square[$ul]} ${square[$ur]} "
				cnt=$[ $cnt + 4 ];
			done ) )
	log "Found ${#PATCH_VERTEX[*]} vertex, $[ ${#PATCH_VERTEX[*]} / 3 ] triangles ..."
fi


KML_FILE="$output_dir/scenary.kml"
createKMLoutput HEAD "$KML_FILE" "$( echo "$output_dir" | tr -d "/" )"


dim_x=$[  ( $dim_x + ( 8 % $dim_x ) ) / 8 ]
dim_y=$[  ( $dim_y + ( 8 % $dim_y ) ) / 8 ]

[ "$dim_x" = "0" ] && dim_x="1"
[ "$dim_y" = "0" ] && dim_y="1"

tot="${#good_tile[@]}"
dfs_index="0"
dfs_file=""
index_triangle="0"
cnt="0"
prog="1"
cursor_tmp="$( echo "$cursor"  | rev | cut -c 4- | rev )"


for x in $( seq 0 $dim_x ) ; do
        c2="$cursor_tmp"
        cursor_tmp="$( GetNextTileX $cursor_tmp 1 )"

        for y in $( seq 0 $dim_y  ) ; do
		if [ !  -f "$tiles_dir/tile/tile-$c2.png" ] ; then
                	c_last="$c2"
                	c2="$( GetNextTileY $c2 1 )"
			continue
		fi

		info=( $( GetCoordinatesFromAddress $c2 ) )	
		point_lon="${info[0]}"
		point_lat="${info[1]}"


		ori_ul_lon="$( awk 'BEGIN { printf "%.8f", '${info[2]}' + '$lon_fix' }' )"
		ori_ul_lat="$( awk 'BEGIN { printf "%.8f", '${info[3]}' + '$lat_fix' }' )"
		ori_lr_lon="$( awk 'BEGIN { printf "%.8f", '${info[4]}' + '$lon_fix' }' )"
		ori_lr_lat="$( awk 'BEGIN { printf "%.8f", '${info[5]}' + '$lat_fix' }' )"	


		if [ "$rot_fix" = "0" ] ; then
			# Without rotation 
			ul_lat="$ori_ul_lat"
			ul_lon="$ori_ul_lon"
	
			ur_lat="$ori_ul_lat"
			ur_lon="$ori_lr_lon"

			lr_lat="$ori_lr_lat"
			lr_lon="$ori_lr_lon"

			ll_lat="$ori_lr_lat"
			ll_lon="$ori_ul_lon"
		else
			# With rotation...
			ul_lat="$( echo "scale = 8; $ori_ul_lat - $lat_plane" | bc -l )"
			ul_lon="$( echo "scale = 8; $ori_ul_lon - $lon_plane" | bc -l )"
			ul_lon="$( echo "scale = 8; $ul_lon * c( ($pi/180) * $rot_fix ) - $ul_lat * s( ($pi/180) * $rot_fix )" | bc -l )"
			ul_lat="$( echo "scale = 8; $ul_lon * s( ($pi/180) * $rot_fix ) + $ul_lat * c( ($pi/180) * $rot_fix )" | bc -l )"
			ul_lat="$( echo "scale = 8; $ul_lat + $lat_plane" | bc -l )"
			ul_lon="$( echo "scale = 8; $ul_lon + $lon_plane" | bc -l )"

			ur_lat="$( echo "scale = 8; $ori_ul_lat - $lat_plane" | bc -l )"
			ur_lon="$( echo "scale = 8; $ori_lr_lon - $lon_plane" | bc -l )"
			ur_lon="$( echo "scale = 8; $ur_lon * c( ($pi/180) * $rot_fix ) - $ur_lat * s( ($pi/180) * $rot_fix )" | bc -l )"
			ur_lat="$( echo "scale = 8; $ur_lon * s( ($pi/180) * $rot_fix ) + $ur_lat * c( ($pi/180) * $rot_fix )" | bc -l )"
			ur_lat="$( echo "scale = 8; $ur_lat + $lat_plane" | bc -l )"
			ur_lon="$( echo "scale = 8; $ur_lon + $lon_plane" | bc -l )"

			lr_lat="$( echo "scale = 8; $ori_lr_lat - $lat_plane" | bc -l )"
			lr_lon="$( echo "scale = 8; $ori_lr_lon - $lon_plane" | bc -l )"
			lr_lon="$( echo "scale = 8; $lr_lon * c( ($pi/180) * $rot_fix ) - $lr_lat * s( ($pi/180) * $rot_fix )" | bc -l )"
			lr_lat="$( echo "scale = 8; $lr_lon * s( ($pi/180) * $rot_fix ) + $lr_lat * c( ($pi/180) * $rot_fix )" | bc -l )"
			lr_lat="$( echo "scale = 8; $lr_lat + $lat_plane" | bc -l )"
			lr_lon="$( echo "scale = 8; $lr_lon + $lon_plane" | bc -l )"


			ll_lat="$( echo "scale = 8; $ori_lr_lat - $lat_plane" | bc -l )"
			ll_lon="$( echo "scale = 8; $ori_ul_lon - $lon_plane" | bc -l )"
			ll_lon="$( echo "scale = 8; $ll_lon * c( ($pi/180) * $rot_fix ) - $ll_lat * s( ($pi/180) * $rot_fix )" | bc -l )"
			ll_lat="$( echo "scale = 8; $ll_lon * s( ($pi/180) * $rot_fix ) + $ll_lat * c( ($pi/180) * $rot_fix )" | bc -l )"
			ll_lat="$( echo "scale = 8; $ll_lat + $lat_plane" | bc -l )"
			ll_lon="$( echo "scale = 8; $ll_lon + $lon_plane" | bc -l )"

		fi

		ul_lat="$( awk 'BEGIN { printf "%f", '$ul_lat' }' )"
		ul_lon="$( awk 'BEGIN { printf "%f", '$ul_lon' }' )"
                                                      
		ur_lat="$( awk 'BEGIN { printf "%f", '$ur_lat' }' )"
		ur_lon="$( awk 'BEGIN { printf "%f", '$ur_lon' }' )"
                                                      
		lr_lat="$( awk 'BEGIN { printf "%f", '$lr_lat' }' )"
		lr_lon="$( awk 'BEGIN { printf "%f", '$lr_lon' }' )"
                                                      
		ll_lat="$( awk 'BEGIN { printf "%f", '$ll_lat' }' )"
		ll_lon="$( awk 'BEGIN { printf "%f", '$ll_lon' }' )"

		
		POL_FILE="poly_${point_lat}_${point_lon}.pol"
		TEXTURE="img_${point_lat}_${point_lon}.dds"
		TER="ter_${point_lat}_${point_lon}.ter"


		[ "$REMAKE_TILE" = "yes" ] && [ -f "$tiles_dir/dds/tile-$c2.dds" ] && rm -f "$tiles_dir/dds/tile-$c2.dds"

	        if [ ! -f "$TEX_DIR/$TEXTURE" ] ; then
			[ ! -f "$tiles_dir/dds/tile-$c2.dds" ] && "$ddstool" --png2dxt args1 args2 "$tiles_dir/tile/tile-$c2.png" "$tiles_dir/dds/tile-$c2.dds"
			#"$ddstool" --png2dxt "$tiles_dir/tile/tile-$c2.png" "$tiles_dir/dds/tile-$c2.dds"
			cp -f "$tiles_dir/dds/tile-$c2.dds" "$TEX_DIR/$TEXTURE"
			
		fi


		createKMLoutput ADD  "$KML_FILE" "$TEXTURE" $ori_ul_lat $ori_lr_lat $ori_lr_lon $ori_ul_lon $rot_fix

		DSF_LIST="$( for p in "$ul_lon,$ul_lat" "$ur_lon,$ur_lat" "$ll_lon,$ll_lat" "$lr_lon,$ll_lat" ; do getDSFName "${p#*,}" "${p%,*}" ; done | sort -u  )"


		for REFERENCE_POINT in "$ul_lon,$ul_lat" "$ur_lon,$ur_lat" "$ll_lon,$ll_lat" "$lr_lon,$ll_lat" ; do
			REFERENCE_POINT_LON="${REFERENCE_POINT%,*}"
			REFERENCE_POINT_LAT="${REFERENCE_POINT#*,}"
			########################################################3

			dfs_file="$( getDSFName "$REFERENCE_POINT_LAT" "$REFERENCE_POINT_LON" )" 
			dfs_dir="$(  getDirName "$REFERENCE_POINT_LAT" "$REFERENCE_POINT_LON" )"
			[ -z "$( echo "$DSF_LIST" | grep "$dfs_file" )" ] && continue

			# [ "$dfs_file" != "+44+011.dsf" ] && continue # TO BE REMOVED
			########################################################3

			if [ ! -d "$output_dir/$output_sub_dir/$dfs_dir" ] ; then
				log "Create DSF directory \"$dfs_dir\" ..."
				mkdir "$output_dir/$output_sub_dir/$dfs_dir"
			fi

			DSF_LIST="$( echo "$DSF_LIST" | grep -v "$dfs_file" )"
			dfs_list[$dfs_index]="${dfs_dir}/${dfs_file}"	
			dfs_index="$[ $dfs_index + 1 ]"

			########################################################3

			[ "$( echo "$REFERENCE_POINT_LAT < 0" | bc )" = 1  ] && \
				max_lat="$( awk 'BEGIN { printf "%d", '$REFERENCE_POINT_LAT'		}' )" && \
				min_lat="$( awk 'BEGIN { printf "%d", '$REFERENCE_POINT_LAT' - 1	}' )"

			[ "$( echo "$REFERENCE_POINT_LAT > 0" | bc )" = 1  ] && 
				max_lat="$( awk 'BEGIN { printf "%d", '$REFERENCE_POINT_LAT' + 1	}' )" && \
				min_lat="$( awk 'BEGIN { printf "%d", '$REFERENCE_POINT_LAT' 		}' )"

			[ "$( echo "$REFERENCE_POINT_LON < 0" | bc )" = 1  ] && \
				max_lon="$( awk 'BEGIN { printf "%d", '$REFERENCE_POINT_LON' 		}' )" && \
				min_lon="$( awk 'BEGIN { printf "%d", '$REFERENCE_POINT_LON' - 1	}' )"

			[ "$( echo "$REFERENCE_POINT_LON > 0" | bc )" = 1  ] && 
				max_lon="$( awk 'BEGIN { printf "%d", '$REFERENCE_POINT_LON' + 1	}' )" && \
				min_lon="$( awk 'BEGIN { printf "%d", '$REFERENCE_POINT_LON' 		}' )"


			if [ ! -f "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file.txt" ] ; then
				log "Creating file $dfs_file ..."

 				echo "PROPERTY sim/west $min_lon" 				>> "$output_dir/$output_sub_dir/$dfs_dir/${dfs_file}.txt"
				echo "PROPERTY sim/east $max_lon" 				>> "$output_dir/$output_sub_dir/$dfs_dir/${dfs_file}.txt"
				echo "PROPERTY sim/north $max_lat" 				>> "$output_dir/$output_sub_dir/$dfs_dir/${dfs_file}.txt"
				echo "PROPERTY sim/south $min_lat" 				>> "$output_dir/$output_sub_dir/$dfs_dir/${dfs_file}.txt"
				echo 								>> "$output_dir/$output_sub_dir/$dfs_dir/${dfs_file}.txt"
				echo "PROPERTY sim/planet earth" 				>> "$output_dir/$output_sub_dir/$dfs_dir/${dfs_file}.txt"
				echo "PROPERTY sim/creation_agent $( basename -- "$0" )"	>> "$output_dir/$output_sub_dir/$dfs_dir/${dfs_file}.txt"
[ "$MASH_SCENARY" = "no" ]  && 	echo "PROPERTY sim/overlay 1" 					>> "$output_dir/$output_sub_dir/$dfs_dir/${dfs_file}.txt"
                                                                                                                                                       
				echo 								>> "$output_dir/$output_sub_dir/$dfs_dir/${dfs_file}.txt"
[ "$MASH_SCENARY" = "yes" ] &&	echo "TERRAIN_DEF terrain_Water" 				>> "$output_dir/$output_sub_dir/$dfs_dir/${dfs_file}.txt"
				echo 								>> "$output_dir/$output_sub_dir/$dfs_dir/${dfs_file}.txt"


				BEGIN_POLYGON_CNT="0"
				BEGIN_PATCH_CNT="1"
			else
[ "$MASH_SCENARY" = "no" ]  &&	BEGIN_POLYGON_CNT="$( 	cat "$output_dir/$output_sub_dir/$dfs_dir/${dfs_file}.txt" 	| grep "BEGIN_POLYGON" 	| tail -n 1 | awk {'print $2'} )" && BEGIN_POLYGON_CNT="$[ $BEGIN_POLYGON_CNT + 1 ]"	
[ "$MASH_SCENARY" = "yes" ] && 	BEGIN_PATCH_CNT="$(	cat "$output_dir/$output_sub_dir/$dfs_dir/${dfs_file}_body.txt" | grep "BEGIN_PATCH" 	| tail -n 1 | awk {'print $2'} )" && BEGIN_PATCH_CNT="$[   $BEGIN_PATCH_CNT   + 1 ]"

			fi



			CROSS_CHECK="ok"
			lr_lon_px="1"; ur_lon_px="1"; ul_lon_px="0"; ll_lon_px="0"
			lr_lat_px="0"; ur_lat_px="1"; ul_lat_px="1"; ll_lat_px="0"

			ul_lat_dsf="$ul_lat";	ul_lon_dsf="$ul_lon"                                           
			ur_lat_dsf="$ur_lat";	ur_lon_dsf="$ur_lon"
			lr_lat_dsf="$lr_lat";	lr_lon_dsf="$lr_lon"
			ll_lat_dsf="$ll_lat";	ll_lon_dsf="$ll_lon"


			########################################################3

			for p in "ul:$ul_lon,$ul_lat" "ur:$ur_lon,$ur_lat" "ll:$ll_lon,$ll_lat" "lr:$lr_lon,$ll_lat" ; do
				corner="${p:0:2}"
				p="${p:3}"
				out="$( pointInPolygon  ${p/,/ } "$min_lon,$max_lat $max_lon,$max_lat $max_lon,$min_lat $min_lon,$min_lat" )"


				CROSS_CHECK_FIXED="no"
				if [ "$out" = "out" ] ; then
					if [ "$corner" = "ll" ] ; then
						if [ "$( echo "$ll_lat < $min_lat" | bc )" = 1  ] ; then
							ll_lat_px="$( echo "scale = 8; $( pointDist $ll_lon $ll_lat $ll_lon $min_lat ) / $( pointDist $ll_lon $ll_lat $ul_lon $ul_lat  )" | bc )"
							ll_lat_dsf="${min_lat}.000000"
							[ "$MASH_SCENARY" = "yes" ] &&  ll_lat_dsf="${min_lat}.000002"
							CROSS_CHECK_FIXED="yes"
						fi
						
						if [ "$( echo "$ll_lon < $min_lon" | bc )" = 1  ] ; then
							ll_lon_px="$( echo "scale = 8; $( pointDist $ll_lon $ll_lat $min_lon $ll_lat ) / $( pointDist $ll_lon $ll_lat $lr_lon $lr_lat  )" | bc )"
							ll_lon_dsf="${min_lon}.000000"
							CROSS_CHECK_FIXED="yes"
						fi
						
					fi


					if [ "$corner" = "lr" ] ; then
						if [ "$( echo "$lr_lat < $min_lat" | bc )" = 1  ] ; then
							lr_lat_px="$( echo "scale = 8; $( pointDist $lr_lon $lr_lat $lr_lon $min_lat ) / $( pointDist $lr_lon $lr_lat $ur_lon $ur_lat  )" | bc )"
							lr_lat_dsf="${min_lat}.000000"
							[ "$MASH_SCENARY" = "yes" ] && lr_lat_dsf="${min_lat}.000002"
							CROSS_CHECK_FIXED="yes"
						fi

						if [ "$( echo "$lr_lon > $max_lon" | bc )" = 1  ] ; then
							lr_lon_px="$( echo "scale = 8; 1.0 - $( pointDist $lr_lon $lr_lat $max_lon $lr_lat ) / $( pointDist $lr_lon $lr_lat $ll_lon $ll_lat  )" | bc )"
							lr_lon_dsf="${max_lon}.000000"
							CROSS_CHECK_FIXED="yes"
						fi
	
					fi

					if [ "$corner" = "ul" ] ; then
						 if [ "$( echo "$ul_lat > $max_lat" | bc )" = 1  ] ; then
							ul_lat_px="$( echo "scale = 8; 1.0 - $( pointDist $ul_lon $ul_lat $ul_lon $max_lat ) / $( pointDist $ul_lon $ul_lat $ll_lon $ll_lat  )" | bc )"
							ul_lat_dsf="${max_lat}.000000"
							CROSS_CHECK_FIXED="yes"
						fi


						if [ "$( echo "$ul_lon < $min_lon" | bc )" = 1  ] ; then
							ul_lon_px="$( echo "scale = 8; $( pointDist $ul_lon $ul_lat $min_lon $ul_lat ) / $( pointDist $ul_lon $ul_lat $ur_lon $ur_lat  )" | bc )"
							ul_lon_dsf="${min_lon}.000000"
							CROSS_CHECK_FIXED="yes"
						fi
					fi

					if [ "$corner" = "ur" ] ; then
						 if [ "$( echo "$ur_lat > $max_lat" | bc )" = 1  ] ; then
							ur_lat_px="$( echo "scale = 8; 1.0 - $( pointDist $ur_lon $ur_lat $ur_lon $max_lat ) / $( pointDist $ur_lon $ur_lat $lr_lon $lr_lat  )" | bc )"
							ur_lat_dsf="${max_lat}.000000"
							CROSS_CHECK_FIXED="yes"
						fi

						if [ "$( echo "$ur_lon > $max_lon" | bc )" = 1  ] ; then
							ur_lon_px="$( echo "scale = 8; 1.0 - $( pointDist $ur_lon $ur_lat $max_lon $ur_lat ) / $( pointDist $ur_lon $ur_lat $ul_lon $ul_lat  )" | bc )"
							ur_lon_dsf="${max_lon}.000000"
							CROSS_CHECK_FIXED="yes"
						fi
	


					fi


					if [ "$CROSS_CHECK_FIXED" = "no" ] ; then
						echo "$corner"
						echo "$min_lon $max_lat $max_lon $max_lat $max_lon $min_lat $min_lon $min_lat"
						echo "$lr_lon  $lr_lat  $ur_lon  $ur_lat  $ul_lon  $ul_lat  $ll_lon  $ll_lat"
					fi

				fi
				CROSS_CHECK="cross" 
			done


			ul_lat_px="$( awk 'BEGIN { printf "%.8f", '$ul_lat_px' }' )"
			ul_lon_px="$( awk 'BEGIN { printf "%.8f", '$ul_lon_px' }' )"
	                                                
			ur_lat_px="$( awk 'BEGIN { printf "%.8f", '$ur_lat_px' }' )"
			ur_lon_px="$( awk 'BEGIN { printf "%.8f", '$ur_lon_px' }' )"
	                                                
			lr_lat_px="$( awk 'BEGIN { printf "%.8f", '$lr_lat_px' }' )"
			lr_lon_px="$( awk 'BEGIN { printf "%.8f", '$lr_lon_px' }' )"
	                                                
			ll_lat_px="$( awk 'BEGIN { printf "%.8f", '$ll_lat_px' }' )"
			ll_lon_px="$( awk 'BEGIN { printf "%.8f", '$ll_lon_px' }' )"

			

	
			if [ "$MASH_SCENARY" = "no" ] && [ ! -f "$output_dir/$POL_FILE" ] ; then
				echo "$prog / $tot: Creating polygon (.pol) file \"$POL_FILE\"..."
				LC_lat_center="$( awk 'BEGIN { printf "%.8f", ( '$ul_lat' + '$lr_lat' ) / 2 }' )"
				LC_lon_center="$( awk 'BEGIN { printf "%.8f", ( '$ul_lon' + '$lr_lon' ) / 2 }' )"
				LC_dim="$(  tile_size $c2 | awk -F. {'print $1'} )"
				LC_size="$( identify "$tiles_dir/tile/tile-$c2.png" | awk {'print $3'} | awk -Fx {'print $1'} )"

				echo "A"								>  "$output_dir/$POL_FILE"
				echo "850"								>> "$output_dir/$POL_FILE"
				echo "DRAPED_POLYGON"							>> "$output_dir/$POL_FILE"
				echo 									>> "$output_dir/$POL_FILE"
				echo "LAYER_GROUP airports -1"						>> "$output_dir/$POL_FILE"
				echo "LOAD_CENTER $LC_lat_center $LC_lon_center $LC_dim $LC_size"       >> "$output_dir/$POL_FILE"	
				echo "TEXTURE_NOWRAP $( basename -- $TEX_DIR)/$TEXTURE"			>> "$output_dir/$POL_FILE"
				echo "SCALE 25 25"							>> "$output_dir/$POL_FILE"




			fi

			if [ "$MASH_SCENARY" = "yes" ] && [ ! -f "$TER_DIR/$TER" ] ; then
				log "$prog / $tot: Creating terrain (.ter) file \"$TER\"..."
				LC_lat_center="$( awk 'BEGIN { printf "%.8f", ( '$ul_lat' + '$lr_lat' ) / 2 }' )"
				LC_lon_center="$( awk 'BEGIN { printf "%.8f", ( '$ul_lon' + '$lr_lon' ) / 2 }' )"
				LC_dim="$(  tile_size $c2 | awk -F. {'print $1'} )"
				LC_size="$( identify "$tiles_dir/tile/tile-$c2.png" | awk {'print $3'} | awk -Fx {'print $1'} )"

				echo "A"                                                                >  "$TER_DIR/$TER"
				echo "800"                                                              >> "$TER_DIR/$TER"
				echo "TERRAIN"                                                          >> "$TER_DIR/$TER"
				echo                                                                    >> "$TER_DIR/$TER"
				echo "LOAD_CENTER $LC_lat_center $LC_lon_center $LC_dim $LC_size"       >> "$TER_DIR/$TER"
				echo "BASE_TEX_NOWRAP ../$( basename -- $TEX_DIR)/$TEXTURE"		>> "$TER_DIR/$TER"

                        
                        fi



			if [ "$MASH_SCENARY" = "no" ] ; then			
				################################
				# create dsf file ....
				echo "POLYGON_DEF $POL_FILE"							>> "$output_dir/$output_sub_dir/$dfs_dir/${dfs_file}.txt"
				echo "BEGIN_POLYGON $BEGIN_POLYGON_CNT 65535 4"					>> "$output_dir/$output_sub_dir/$dfs_dir/${dfs_file}.txt"
				echo "BEGIN_WINDING"								>> "$output_dir/$output_sub_dir/$dfs_dir/${dfs_file}.txt"
				echo "POLYGON_POINT $lr_lon_dsf	$lr_lat_dsf	$lr_lon_px	$lr_lat_px"	>> "$output_dir/$output_sub_dir/$dfs_dir/${dfs_file}.txt"
				echo "POLYGON_POINT $ur_lon_dsf	$ur_lat_dsf	$ur_lon_px	$ur_lat_px"	>> "$output_dir/$output_sub_dir/$dfs_dir/${dfs_file}.txt"
				echo "POLYGON_POINT $ul_lon_dsf	$ul_lat_dsf	$ul_lon_px	$ul_lat_px"	>> "$output_dir/$output_sub_dir/$dfs_dir/${dfs_file}.txt"
				echo "POLYGON_POINT $ll_lon_dsf	$ll_lat_dsf	$ll_lon_px	$ll_lat_px"	>> "$output_dir/$output_sub_dir/$dfs_dir/${dfs_file}.txt"
				echo "END_WINDING"								>> "$output_dir/$output_sub_dir/$dfs_dir/${dfs_file}.txt"
				echo "END_POLYGON"								>> "$output_dir/$output_sub_dir/$dfs_dir/${dfs_file}.txt"
				echo  										>> "$output_dir/$output_sub_dir/$dfs_dir/${dfs_file}.txt"
				BEGIN_POLYGON_CNT=$[ $BEGIN_POLYGON_CNT + 1 ]
				################################
			fi


			if [ "$MASH_SCENARY" = "yes" ] ; then

				lon_dsf_size="$( awk 'BEGIN { printf "%.8f\n", '$lr_lon_dsf' - '$ll_lon_dsf' }' )"
				lat_dsf_size="$( awk 'BEGIN { printf "%.8f\n", '$ul_lat_dsf' - '$ll_lat_dsf' }' )"
				lon_px_size="$(  awk 'BEGIN { printf "%.8f\n", '$lr_lon_px'  - '$ll_lon_px'  }' )"
				lat_px_size="$(  awk 'BEGIN { printf "%.8f\n", '$ul_lat_px'  - '$ll_lat_px'  }' )"

				ADD_WATER="false"; [ "$( du -k  "$tiles_dir/mask/mask-$c2.png" | awk {'print $1'} )" != "0" ] && ADD_WATER="true"


				echo "BEGIN_PATCH $BEGIN_PATCH_CNT 0.000000 -1.000000  1 7"			>> "$output_dir/$output_sub_dir/$dfs_dir/${dfs_file}_body.txt"
				echo "BEGIN_PRIMITIVE 0"							>> "$output_dir/$output_sub_dir/$dfs_dir/${dfs_file}_body.txt"

				if [ "$ADD_WATER" = "true" ] ; then
  				echo "BEGIN_PATCH 0 0.000000 -1.000000   1   5"					>> "$output_dir/$output_sub_dir/$dfs_dir/${dfs_file}_body_water.txt"
  				echo "BEGIN_PRIMITIVE 0"							>> "$output_dir/$output_sub_dir/$dfs_dir/${dfs_file}_body_water.txt"
				fi

				vex="0"
				triangle_cnt="0"
				primitive_cnt="1"
				while [ ! -z "${PATCH_VERTEX[$vex]}" ] ; do
					v0="$vex"; v1=$[ $vex + 1 ]; v2=$[ $vex + 2 ]

					pLon[0]="$(	awk 'BEGIN { printf "%f\n", '$ll_lon_dsf' + '$lon_dsf_size' * '${PATCH_VERTEX[$v0]%,*}' }' )"
					pLon[1]="$(	awk 'BEGIN { printf "%f\n", '$ll_lon_dsf' + '$lon_dsf_size' * '${PATCH_VERTEX[$v1]%,*}' }' )"
					pLon[2]="$(	awk 'BEGIN { printf "%f\n", '$ll_lon_dsf' + '$lon_dsf_size' * '${PATCH_VERTEX[$v2]%,*}' }' )"

					pLat[0]="$(	awk 'BEGIN { printf "%f\n", '$ll_lat_dsf' + '$lat_dsf_size' * '${PATCH_VERTEX[$v0]#*,}' }' )"
					pLat[1]="$(	awk 'BEGIN { printf "%f\n", '$ll_lat_dsf' + '$lat_dsf_size' * '${PATCH_VERTEX[$v1]#*,}' }' )"
					pLat[2]="$(	awk 'BEGIN { printf "%f\n", '$ll_lat_dsf' + '$lat_dsf_size' * '${PATCH_VERTEX[$v2]#*,}' }' )"

					
					setAltitudeEnv "${pLon[0]}" "${pLat[0]}" ; pAlt[0]="$( 	getAltitude "${pLon[0]}" "${pLat[0]}" )"
					setAltitudeEnv "${pLon[1]}" "${pLat[1]}" ; pAlt[1]="$( 	getAltitude "${pLon[1]}" "${pLat[1]}" )"
					setAltitudeEnv "${pLon[2]}" "${pLat[2]}" ; pAlt[2]="$( 	getAltitude "${pLon[2]}" "${pLat[2]}" )"

					pX[0]="$(	awk 'BEGIN { printf "%.8f\n", '$ll_lon_px'  + '$lon_px_size' * '${PATCH_VERTEX[$v0]%,*}' }' )"
					pX[1]="$(	awk 'BEGIN { printf "%.8f\n", '$ll_lon_px'  + '$lon_px_size' * '${PATCH_VERTEX[$v1]%,*}' }' )"
					pX[2]="$(	awk 'BEGIN { printf "%.8f\n", '$ll_lon_px'  + '$lon_px_size' * '${PATCH_VERTEX[$v2]%,*}' }' )"

					pY[0]="$(	awk 'BEGIN { printf "%.8f\n", '$ll_lat_px'  + '$lat_px_size' * '${PATCH_VERTEX[$v0]#*,}' }' )"
					pY[1]="$(	awk 'BEGIN { printf "%.8f\n", '$ll_lat_px'  + '$lat_px_size' * '${PATCH_VERTEX[$v1]#*,}' }' )"
					pY[2]="$(	awk 'BEGIN { printf "%.8f\n", '$ll_lat_px'  + '$lat_px_size' * '${PATCH_VERTEX[$v2]#*,}' }' )"

					# 0.86745204



					# -0.000015259 -0.000015259
					echo "PATCH_VERTEX ${pLon[0]} ${pLat[0]} ${pAlt[0]} 0 0 ${pX[0]} ${pY[0]}"	>> "$output_dir/$output_sub_dir/$dfs_dir/${dfs_file}_body.txt"
					echo "PATCH_VERTEX ${pLon[1]} ${pLat[1]} ${pAlt[1]} 0 0 ${pX[1]} ${pY[1]}"	>> "$output_dir/$output_sub_dir/$dfs_dir/${dfs_file}_body.txt"
					echo "PATCH_VERTEX ${pLon[2]} ${pLat[2]} ${pAlt[2]} 0 0 ${pX[2]} ${pY[2]}"	>> "$output_dir/$output_sub_dir/$dfs_dir/${dfs_file}_body.txt"


					if [ "$ADD_WATER" = "true" ] ; then				
	  				echo "PATCH_VERTEX  ${pLon[0]} ${pLat[0]} ${pAlt[0]} 0 0"			>> "$output_dir/$output_sub_dir/$dfs_dir/${dfs_file}_body_water.txt"
	  				echo "PATCH_VERTEX  ${pLon[1]} ${pLat[1]} ${pAlt[1]} 0 0"			>> "$output_dir/$output_sub_dir/$dfs_dir/${dfs_file}_body_water.txt"
	  				echo "PATCH_VERTEX  ${pLon[2]} ${pLat[2]} ${pAlt[2]} 0 0"			>> "$output_dir/$output_sub_dir/$dfs_dir/${dfs_file}_body_water.txt"
					fi			

			
  					if [ "$triangle_cnt" -ge  "84" ] ; then
  						echo "END_PRIMITIVE"						>> "$output_dir/$output_sub_dir/$dfs_dir/${dfs_file}_body.txt"
  						echo "BEGIN_PRIMITIVE 0"					>> "$output_dir/$output_sub_dir/$dfs_dir/${dfs_file}_body.txt"
  
  						if [ "$ADD_WATER" = "true" ] ; then
  						echo "END_PRIMITIVE"						>> "$output_dir/$output_sub_dir/$dfs_dir/${dfs_file}_body_water.txt"
  						echo "BEGIN_PRIMITIVE 0"					>> "$output_dir/$output_sub_dir/$dfs_dir/${dfs_file}_body_water.txt"
  						fi
  
  						triangle_cnt="0"
  						#primitive_cnt=$[ $primitive_cnt + 1 ]
  					fi


					triangle_cnt=$[ $triangle_cnt + 1 ]
					vex=$[ $vex + 3 ]

				done
				echo "END_PRIMITIVE"								>> "$output_dir/$output_sub_dir/$dfs_dir/${dfs_file}_body.txt"
				echo "END_PATCH"								>> "$output_dir/$output_sub_dir/$dfs_dir/${dfs_file}_body.txt"
				echo										>> "$output_dir/$output_sub_dir/$dfs_dir/${dfs_file}_body.txt"
				if [ "$ADD_WATER" = "true" ] ; then
				echo "END_PRIMITIVE"								>> "$output_dir/$output_sub_dir/$dfs_dir/${dfs_file}_body_water.txt"
				echo "END_PATCH"								>> "$output_dir/$output_sub_dir/$dfs_dir/${dfs_file}_body_water.txt"
				echo										>> "$output_dir/$output_sub_dir/$dfs_dir/${dfs_file}_body_water.txt"
				fi


				echo "TERRAIN_DEF $( basename -- $TER_DIR)/$TER" >> "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file.txt"
				BEGIN_PATCH_CNT=$[ $BEGIN_PATCH_CNT + 1 ]

			fi
		done
		
		prog=$[ $prog + 1 ]

                c_last="$c2"
                c2="$( GetNextTileY $c2 1 )"
        done
done


################################################################################################################################
#
# Uncomment from following code to enable compatibility with X-Plane 8 (Thanks to Matt)
#

#echo "Converting tiles..."
#for i in $tile_dir/*.dds; do
#	convert -resize 1024x1024 $i ${i/dds/png}
#done



################################################################################################################################

createKMLoutput END  "$KML_FILE"  #&& exit

# Sorting DSF file and remove the duplicate
dfs_list=( $( echo "${dfs_list[@]}" | tr " " "\n" | sort -u | tr "\n" " " ) )


if [  ! -z "$dsftool" ] ; then


	for i in ${dfs_list[@]} ; do

		if [ "$MASH_SCENARY" = "yes" ]  ; then
			log "Merging DSF temporary file ..."
			[ -f "$output_dir/$output_sub_dir/${i}_body_water.txt" ] && cat "$output_dir/$output_sub_dir/${i}_body_water.txt" 	>> "$output_dir/$output_sub_dir/${i}.txt"
			[ -f "$output_dir/$output_sub_dir/${i}_body.txt" ]	 && cat "$output_dir/$output_sub_dir/${i}_body.txt" 		>> "$output_dir/$output_sub_dir/${i}.txt"

			rm -f "$output_dir/$output_sub_dir/${i}_body.txt"
			rm -f "$output_dir/$output_sub_dir/${i}_body_water.txt"
		fi


		log "Create DSF file \"$i\"..."
		"$dsftool" --text2dsf "$output_dir/$output_sub_dir/${i}.txt" "$output_dir/$output_sub_dir/$i"
		log "-------------------------------------------------------"
	done
fi

exit 0

