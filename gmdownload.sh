#!/bin/bash


export LC_NUMERIC="us"
export LC_COLLATE="us"
export LC_CTYPE="us"
export LC_MESSAGES="us"
export LC_MONETARY="us"
export LC_NUMERIC="us"
export LC_TIME="us"     


# Q	R
#
# T	S
# Start url...
url="http://khm.google.com/kh?v=3&t="

servers_tile=( khm0.google.com khm1.google.com khm2.google.com khm3.google.com )
servers_maps=( mt0.google.com  mt1.google.com  mt2.google.com  mt3.google.com  )
OSM="yes"
server_index="0"
SLEEP_TIME="20"
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

XPLANE_CMD_VERSION="920"
TER_DIR="terrain" 
MESH_LEVEL="2"
output_index="0"
TMPFILE="tmp$$"
output=()



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

		lat_fix="$( echo "scale = 8; $lat_plane - $lat_runwa" | bc -l )"
		lon_fix="$( echo "scale = 8; $lon_plane - $lon_runwa" | bc -l )"

		[ "$( echo "scale = 8;  $lat_fix >= 0"    | bc -l )" == 1 ] && lat_fix="$( echo "scale = 8; $lat_runwa - $lat_plane" | bc -l )"
		[ "$( echo "scale = 8;  $lon_fix >= 0"    | bc -l )" == 1 ] && lon_fix="$( echo "scale = 8; $lon_runwa - $lon_plane" | bc -l )"


		echo "$lat_fix $lon_fix"

		m_plane="$( echo "scale = 8; ( $lat_plane + $lat_fix - $lat_plane_rot ) / ( $lon_plane + $lon_fix - $lon_plane_rot )" | bc -l  )"

		m_runwa="$( echo "scale = 8; ( $lat_runwa + $lat_fix - $lat_runwa_rot ) / ( $lon_runwa + $lon_fix - $lon_runwa_rot )" | bc -l  )"


		rot_fix="$( echo "scale = 8; (a( ($m_plane -  $m_runwa)/(1+($m_plane + $m_runwa)) ) * ( 180 / $pi ))" | bc -l  )"
	else
		rot_fix="$3"
	fi


	output_dir="$2"


	
else
	# Input is CLI arguments
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



if [ "$lat_plane" != "" ] && [ "$lon_plane" != "" ]  && [ "$lon_runwa" != "" ] && [ "$lon_runwa" != "" ] ; then
	lat_fix="$( echo "scale = 8; $lat_plane - $lat_runwa" | bc -l )"
	lon_fix="$( echo "scale = 8; $lon_plane - $lon_runwa" | bc -l )"
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



nfo_file="$tiles_dir/tile_"$point_lat"_"$point_lon"_"$lowright_lat"_"$lowright_lon".nfo"
################################################################################################################33

# Compatibilty for macosx
dsftool=""
ddstool=""
if [ "$( uname -s )" = "Darwin" ] ; then
	# Dsf tool
	dsftool="$( dirname -- "$0" )/ext_app/xptools_apr08_mac/DSFTool"
	ddstool="$( dirname -- "$0" )/ext_app/xptools_apr08_mac/DDSTool"
	

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

	# set wine env
	export WINE="$( dirname -- "$0" )/ext_app/wine/usr"
	export PATH="$WINE/bin:$PATH"
	export LD_LIBRARY_PATH="$WINE/lib"
	dsftool="$( dirname -- "$0" )/ext_app/xptools_apr08_win/DSFTool.exe"
	ddstool="$( dirname -- "$0" )/ext_app/xptools_apr08_win/DDSTool.exe"
fi	



if [ -f "$( dirname -- "$0" )/cookies.txt" ] ; then
	echo "Found cookie file for wget!"
	[ "$( uname -s )" = "Linux" ]  && coockie_date="$( ls -lact --time-style="+%s"  "$( dirname -- "$0" )/cookies.txt" |awk {'print $6'} )"
	[ "$( uname -s )" = "Darwin" ] && coockie_date="$( stat -f "%a"  "$( dirname -- "$0" )/cookies.txt"  )"
	now_date="$( date +%s )"
	if [ "$( echo "scale = 8;  ( $now_date - $coockie_date )  > ( 24 * 3600 )" | bc -l )" = "1" ] ; then
		echo "Your cookies.txt file is too old, over 24h of life! You must update it. "
		exit 2
	fi
	COOKIES_FILE="$( dirname -- "$0" )/cookies.txt"

	SLEEP_TIME="1"
fi

################################################################################################################33

#
# Wrapper for wget command
#
# http://visualimages2.paginegialle.it/xml.php/europa-orto.imgi?cmd=tile&format=jpeg&x=2113&y=2658&z=32&extra=2&ts=256&q=65&rdr=0&sito=visual
#
# host: 
# format=png
# q= quality in % (1-100)
#

ewget(){
	out="$1"
	url="$2"
	if [ -z "$( which wget 2> /dev/null )" ] ; then
		echo "ERROR: Utility missing, maybe BUG."
		exit 3
	fi
	
	if [ ! -z "$COOKIES_FILE" ] ; then
		wget -q --user-agent=Firefox --load-cookies="$COOKIES_FILE" -O "$out" "$url"
	else
		wget -q --user-agent=Firefox  -O "$out" "$url"
	fi
}

swget(){
	url="$1"
	if [ -z "$( which wget 2> /dev/null )" ] ; then
		echo "ERROR: Utility missing, maybe BUG."
		exit 3
	fi
	
	if [ ! -z "$COOKIES_FILE" ] ; then
		wget --user-agent=Firefox --load-cookies="$COOKIES_FILE" -S --spider "$url"
	else
		wget --user-agent=Firefox -S --spider "$url"
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

fastAltitude(){
	lon="$1"
	lat="$2"
	who="$[ $RANDOM % 3 ]"
	if [ "$who" = "0" ] ; then
		tmp="$( wget --timeout=10 --tries=1 --user-agent=Firefox -q -O- "http://www.earthtools.org/height/${lat}/${lon}" )"
		alt="$( echo "$tmp" | sed -e s/"<meters>"/"%"/g | sed -e s/"<\/meters>"/"%"/g | awk -F% {'print $2'} | tr "[a-z][A-Z]" " " | tr -d "\n " )"
	fi
	if [ "$who" = "1" ] ; then
		alt="$( wget  --timeout=10 --tries=1 --user-agent=Firefox -q -O- "http://ws.geonames.org/srtm3?lat=${lat}&lng=${lon}&style=full" )"
	fi
	if [ "$who" = "2" ] ; then
		alt="$( wget  --timeout=10 --tries=1 --user-agent=Firefox -q -O- "http://ws.geonames.org/gtopo30?lat=${lat}&lng=${lon}"  )"
	fi
	sleep 1
	alt="$( isNumber "$alt" )"		
	echo -n "$alt"
}


#
# getAltitude lartitude longitude -> altitude in meter
#

getAltitude(){
        ori_lon="$1"
       	ori_lat="$2"
	lon="$( echo "$1" | awk '{ printf "%.4f", $1 }')"
	lat="$( echo "$2" | awk '{ printf "%.4f", $1 }')"

	#echo -n "0.00000000"
	#return
	DEBUG="off"	

	#DEBUG="on"	
	#[ -f "$tiles_dir/info_${ori_lon}_${ori_lat}.alt" ] && mv -f "$tiles_dir/info_${ori_lon}_${ori_lat}.alt"  "$tiles_dir/info_${lon}_${lat}.alt"

        if [ -f "$tiles_dir/info_${lon}_${lat}.alt" ] ; then
                out=( $( cat "$tiles_dir/info_${lon}_${lat}.alt" ) )
                if [ -z "$out" ] ; then
			rm -f  "$tiles_dir/info_${lon}_${lat}.alt"
		else
			[ "${out[1]}" != "FIX" ] 		&& [ "${out[0]}" = "0" ] && out="$( checkAltitude $lon $lat $out )"
			[ "${out[0]}"  = "FIX" ] 		&& rm -f  "$tiles_dir/info_${lon}_${lat}.alt"
			[ ${#out[@]} -gt 2 ] 	 		&& rm -f  "$tiles_dir/info_${lon}_${lat}.alt"
			[ -z  "$( isNumber ${out[0]} )" ] 	&& rm -f  "$tiles_dir/info_${lon}_${lat}.alt"
		fi
        fi
        if [ ! -f "$tiles_dir/info_${lon}_${lat}.alt" ] ; then
		if [ "$DEBUG" = "off" ] ; then
			alt_url="http://gisdata.usgs.gov/xmlwebservices2/elevation_service.asmx/getElevation?X_Value=${lon}&Y_Value=${lat}&Elevation_Units=METERS&Source_Layer=-1&Elevation_Only=true"
	       		tmp="$( wget --timeout=10 --tries=1 --user-agent=Firefox -q -O- "$alt_url" )"
        	        out="$( echo "$tmp" | sed -e s/"<double>"/":"/g | sed -e s/"<\/double>"/":"/g | awk -F: {'print $2'} | tr "[a-z][A-Z]" " " | tr -d "\n " )"
			out="$( isNumber "$out" )"		
		else
			out="$( fastAltitude $lon_$lat )"
		fi
                if [ -z "$out" ] ; then
			out="$( checkAltitude $lon $lat $out )"
		else
	                echo -n "$out" > "$tiles_dir/info_${lon}_${lat}.alt" 
		fi
        fi
        if [ "$out" != "${out#*.}" ] ; then
                # out="${out%.*}.$( echo "${out#*.}" | cut -c -8 )"
                # out="$( echo "$out" | awk '{ printf "%.8f", $1 }')"
		out="${out%.*}.00000000"
        else
                out="$out.00000000" 
        fi
        echo -n "$out"
}

#
#  Check if altitude is good. If good return the same altitude, otherwise the use other altitude server
#
#  http://www.earthtools.org/height/46.25870118/9.44685945

checkAltitude(){
        lon="$1"
        lat="$2"
        alt="$3"

	tmp="$( wget --timeout=10 --tries=1 --user-agent=Firefox -q -O- "http://www.earthtools.org/height/${lat}/${lon}" )"
	new_alt="$( echo "$tmp" | sed -e s/"<meters>"/"%"/g | sed -e s/"<\/meters>"/"%"/g | awk -F% {'print $2'} | tr "[a-z][A-Z]" " " | grep "^[0-9]*$" | tr -d "\n " )"
	new_alt="$( isNumber "$new_alt" )"		
	if [ -z "$new_alt" ] ; then 
		new_alt="$( wget  --timeout=10 --tries=1 --user-agent=Firefox -q -O- "http://ws.geonames.org/srtm3?lat=${lat}&lng=${lon}&style=full" )"
		new_alt="$( isNumber "$new_alt" )"		
		if [ "$new_alt" = "-32768" ] ; then
			new_alt="$( wget  --timeout=10 --tries=1 --user-agent=Firefox -q -O- "http://ws.geonames.org/gtopo30?lat=${lat}&lng=${lon}"  )"
			new_alt="$( isNumber "$new_alt" )"
		fi

		[ -z "$new_alt" ]		&& new_alt="0"
	fi
	if [ "$new_alt" = "0" ] ; then
		echo -n "$new_alt"
		echo -n "$new_alt FIX"  > "$tiles_dir/info_${lon}_${lat}.alt"
		return
	fi
	
        disc="$( echo "scale=8; ( $alt - $new_alt ) / $new_alt * 100" | bc )"

        if [ "$new_alt" != "-9999" ] && [ "$( echo "scale = 6; ( ( $disc < 10.0 ) || ( $disc > 10.0 ) )" | bc )" = "1" ] ; then
		echo -n "$new_alt"
                echo -n "$new_alt FIX" 	> "$tiles_dir/info_${lon}_${lat}.alt"
        else
		echo -n "$alt"
                echo -n "$alt FIX" 	> "$tiles_dir/info_${lon}_${lat}.alt"
        fi

}

#
# This funciont reutun the middle point between two points
#

middlePoint(){
        points=( $* )

        points[0]="$( echo "${points[0]}" | tr "_" " " | tr "," "\t" )"
        points[1]="$( echo "${points[1]}" | tr "_" " " | tr "," "\t" )"

        point_one=( $( echo "${points[0]}" | awk {'print $1" "$2'} ) )
        point_two=( $( echo "${points[1]}" | awk {'print $1" "$2'} ) )

        pos_one=( $( echo "${points[0]}" | awk {'print $3" "$4'} ) )
        pos_two=( $( echo "${points[1]}" | awk {'print $3" "$4'} ) )


        point_tree_lon="$( echo "scale = 8; ( ${point_one[0]} + ${point_two[0]} ) / 2" | bc )"
        [ -z "$( echo "${point_tree_lon%.*}" | tr -d "-" )" ] && point_tree_lon="$( echo "$point_tree_lon" | sed -e s/"\."/"0\."/g )"

        point_tree_lat="$( echo "scale = 8; ( ${point_one[1]} + ${point_two[1]} ) / 2" | bc )"
        [ -z "$( echo "${point_tree_lat%.*}" | tr -d "-" )" ] && point_tree_lat="$( echo "$point_tree_lat" | sed -e s/"\."/"0\."/g )"

        pos_tree_x="$( echo "scale = 8; ( ${pos_one[0]} + ${pos_two[0]} ) / 2" | bc )"
        [ -z "$( echo "${pos_tree_x%.*}" | tr -d "-" )" ] && pos_tree_x="$( echo "$pos_tree_x" | sed -e s/"\."/"0\."/g )"
        [ "$pos_tree_x" = "0" ] && pos_tree_x="0.00000000"

        pos_tree_y="$( echo "scale = 8; ( ${pos_one[1]} + ${pos_two[1]} ) / 2" | bc )"
        [ -z "$( echo "${pos_tree_y%.*}" | tr -d "-" )" ] && pos_tree_y="$( echo "$pos_tree_y" | sed -e s/"\."/"0\."/g )"
        [ "$pos_tree_y" = "0" ] && pos_tree_y="0.00000000"

        echo -n "${point_tree_lon},${point_tree_lat}_${pos_tree_x},${pos_tree_y};"
}


#
# From a square to a sub four square
#

divideSquare(){
        coorners=( $* )
        
        echo -n "${coorners[0]};"
        middlePoint ${coorners[0]} ${coorners[1]}
        middlePoint ${coorners[1]} ${coorners[3]}
        middlePoint ${coorners[3]} ${coorners[0]}
        echo -n " "

        middlePoint ${coorners[0]} ${coorners[1]}
        echo -n "${coorners[1]};"
        middlePoint ${coorners[1]} ${coorners[2]}
        middlePoint ${coorners[1]} ${coorners[3]}
        
        echo -n " "
        middlePoint ${coorners[1]} ${coorners[3]}
        middlePoint ${coorners[1]} ${coorners[2]}
        echo -n "${coorners[2]};"
        middlePoint ${coorners[2]} ${coorners[3]}

        echo -n " "
        middlePoint ${coorners[3]} ${coorners[0]}
        middlePoint ${coorners[1]} ${coorners[3]}
        middlePoint ${coorners[2]} ${coorners[3]}
        echo -n "${coorners[3]};"

}


#
# Return the distance between two points in degree
#

pointsDist(){
        a=(  ${1#*,} ${1%,*} ) 
        b=(  ${2#*,} ${2%,*} ) 
                
        dist="$( echo "scale = 8; sqrt( ( ( ${b[1]} - ${a[1]} ) * ( ${b[1]} - ${a[1]} ) ) + ( ( ${b[0]} - ${a[0]} ) * ( ${b[0]} - ${a[0]} ) ) )" | bc -l )"

        [ -z "$( echo "${dist%.*}" | tr -d "-" )" ] && dist="$( echo "$dist" | sed -e s/"\."/"0\."/g )"
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
		echo "ERROR: missing file name"
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
			echo "ERROR: missing arguments"
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
                        echo "ERROR: missing arguments"
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
	oddNodes="out"
	i="0"
	for xy in  ${polvectorSides[*]} ; do
		polvectorX[$i]="${xy%,*}" 
		polvectorY[$i]="${xy#*,}"
		i=$[ $i + 1 ]
	done

	i="0"
	j="$[ ${#polvectorX[*]} - 1 ]"
	if [ "${polvectorX[0]}" = "${polvectorX[$j]}" ] && [ "${polvectorY[0]}" = "${polvectorY[$j]}" ] ; then
		unset polvectorX[$j]
		unset polvectorY[$j]
		j="$[ ${#polvectorX[*]} - 1 ]"

	fi
	
	while [ $i -lt "${#polvectorX[*]}"  ] ;  do
		if [ "$( echo "scale=8;  ${polvectorY[$i]} < $y && ${polvectorY[$j]} >= $y  || ${polvectorY[$j]} < $y && ${polvectorY[$i]} >= $y" | bc -l )" == 1 ] ; then
			if [ "$( echo "scale=8; ${polvectorX[$i]} + ($y - ${polvectorY[$i]})/(${polvectorY[$j]} - ${polvectorY[$i]})*(${polvectorX[$j]} - ${polvectorX[$i]}) < $x" | bc -l )" == 1 ] ; then
				if [ "$oddNodes" = "out" ] ; then
					oddNodes="in"
				else
					oddNodes="out"
				fi
			fi

		fi
		j="$i";
		i=$[ $i + 1 ]
	done
	echo "$oddNodes"
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

#
# from qrst-string get the qrst-string next tile on X
#

GetNextTileX(){
	addr="$1"
	forward="$2"
	[ -z "$addr" ]	&& echo "$addr" && return
	parent="${addr:0:$[ ${#addr} - 1 ]}"
	last="${addr:$[ ${#addr} - 1 ]}"
	
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

	parent="${addr:0:$[ ${#addr} - 1 ]}"
	last="${addr:$[ ${#addr} - 1 ]}"
	
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

MercatorToNormal(){
	y="$1"
# Start BC 
bc -l << EOF
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
bc -l << EOF
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


GetCoordinatesFromAddress(){

	str="$1"
	ori_str="tile-$str.crd" 
	if [ -f "$tiles_dir/$ori_str" ] ; then
		crd=( $( cat  "$tiles_dir/$ori_str" ) )

		if [ "${#crd[*]}" = "6" ] ; then
			echo "${crd[*]}"
			return
		fi
	fi
	# get normalized coordinate first
	x=0.0;
	y=0.0;
	scale=1.0;
	str="${str:1}" # skip the first character
	
	prec="16"
	while [  ${#str} != 0 ] ; do
		scale="$( echo "scale = $prec ; $scale * 0.5" | bc -l )"

		c="${str:0:1}" # remove first character
		if [ $c = "r" ] || [ $c = "s" ] ; then
			x="$( echo "scale = $prec ; $x + $scale" | bc -l )"
		fi
		if [ $c = "t" ] || [ $c = "s" ] ; then
			y="$( echo "scale = $prec ; $y + $scale" | bc -l )"
		fi
		str="${str:1}" 
	done
	
	lon_min="$( echo "scale = $prec ; ($x - 0.5) * 360"  | bc -l 			| awk '{ printf "%.8f", $1 }' )"
	lat_min="$( NormalToMercator $y 						| awk '{ printf "%.8f", $1 }' )"
	lon_max="$( echo "scale = $prec ; ( $x + $scale - 0.5 ) * 360"  | bc -l 	| awk '{ printf "%.8f", $1 }' )"
	lat_max="$( NormalToMercator $(  echo "scale = $prec ; $y + $scale" | bc -l ) 	| awk '{ printf "%.8f", $1 }' )"
	lon="$( echo "scale = $prec ;  ($x + $scale * 0.5 - 0.5) * 360"  | bc -l 	| awk '{ printf "%.8f", $1 }' )"
	lat="$( NormalToMercator $( echo "scale = $prec ;  $y + $scale * 0.5" | bc -l ) | awk '{ printf "%.8f", $1 }' )"

	#	0   1    2       3         4        5
	echo "$lon $lat $lon_min $lat_min $lon_max $lat_max" > "$tiles_dir/$ori_str"
	echo "$lon $lat $lon_min $lat_min $lon_max $lat_max"
}

getDirName(){
	lat="$1"
	lon="$2"


	[  "$( echo "$lat < 0" | bc -l )" = 1 ] && lat="$( echo "scale = 8; $lat - 10.0" | bc -l )"

	int="${lat%.*}"
	lat="$( echo  "$int - ( $int % 10 )" | bc )"
	[ -z "$( echo "${lat%.*}" | tr -d "-" )" ] && lat="$( echo "$lat" | sed -e s/"\."/"0\."/g )"
	[ "$( echo "$lat > 0" | bc -l )" = 1  ] && lat="+$lat"



	[  "$( echo "$lon < 0" | bc -l )" = 1 ] && lon="$( echo "scale = 8; $lon - 10.0" | bc -l )"

	int="${lon%.*}"
	lon="$( echo  "$int - ( $int % 10 )" | bc )"
	[ -z "$( echo "${lon%.*}" | tr -d "-" )" ] && lon="$( echo "$lon" | sed -e s/"\."/"0\."/g )"
	[ "$( echo "$lon >= 0" | bc -l )" = 1  ] && lon="+$lon"



	[ "$( echo -n "$lon" | tr -d "+-" | wc -c | awk {'print $1'} )" = "1" ] && lon="$( echo "$lon" | sed -e s/"+"/"+00"/g |  sed -e s/"-"/"-00"/g )"
	[ "$( echo -n "$lon" | tr -d "+-" | wc -c | awk {'print $1'} )" = "2" ] && lon="$( echo "$lon" | sed -e s/"+"/"+0"/g |  sed -e s/"-"/"-0"/g )"

	[ "$lat" = "0" ] 	&& lat="+00"
	[ -z "$lon" ] 		&& lon="+000"
	echo "$lat$lon"
}

getDSFName(){
	lat="$1"
	lon="$2"

	lat="$( echo "$lat" | awk -F. {'print $1'} )"
	[ -z "$( echo "${lat%.*}" | tr -d "-" )" ] && lat="$( echo "$lat" | sed -e s/"\."/"0\."/g )"

	[ "$( echo "$lat < 0" | bc )" = 1  ] && lat="$( echo "$lat - 1" | bc )"
	[ "$( echo "$lat > 0" | bc )" = 1  ] && lat="+$lat"

	lon="$( echo "$lon" | awk -F. {'print $1'} )"
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
	# http://mt1.google.com/mt/v=app.87&x=4893&y=3428&z=13
	#server=( "http://${servers_tile[$server_index]}/kh?v=3&t=" "http://${servers_maps[$server_index]}/mt/v=app.87&" )

	server=( "http://${servers_tile[$server_index]}/kh?v=3&t=" "http://${servers_maps[$server_index]}/vt/v=w2.97&" )

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


#########################################################################3

if [ -z "$output_dir" ] ; then
	echo "Output directory missing..."
	exit 1
fi	

if [ -d "$output_dir" ] ; then
	echo "Directory \"$output_dir\" already exists..."
else
	echo "Create directory \"$output_dir\"..."
	mkdir "$output_dir"
fi
if [ -d "$tiles_dir" ] ; then
	echo "Directory \"$tiles_dir\" already exists..."
else
	echo "Create directory \"$tiles_dir\"..."
	mkdir "$tiles_dir"
fi


#########################################################################3

output_sub_dir="Earth nav data"
if [ -d "$output_dir/$output_sub_dir" ] ; then
	echo "Sub directory \"$output_sub_dir\" already exists..."
else
	echo "Create sub directory \"$output_sub_dir\"..."
	mkdir "$output_dir/$output_sub_dir"
fi



#########################################################################3

echo "Creating path to coordinates..."


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

if [ "$RESTORE" = "no" ] ; then
	if [ ! -z "$zoom_reference_lat" ] && [ ! -z "$zoom_reference_lon" ] ; then

		pnt_zoom_ref_lat="$zoom_reference_lat"
		pnt_zoom_ref_lon="$zoom_reference_lon"
		cursor_reference="$( GetQuadtreeAddress $pnt_zoom_ref_lon $pnt_zoom_ref_lat )"
		echo "Point for zoom reference from KML file: $pnt_zoom_ref_lat Lat, $pnt_zoom_ref_lon Lon..."

		reference_test="out"
		for i in $( echo ${poly[*]} | tr " " "\n" | awk -F, {'print $1'} | tr "\n" " " ) ; do
			if [ "$(  pointInPolygon "$pnt_zoom_ref_lon" "$pnt_zoom_ref_lat"  "$( echo ${poly[*]} | tr " " "\n" | grep "^${i}," | awk -F, {'print $2","$3'} | tr "\n" " " )" )" = "in" ] ; then
				reference_test="in" && break
			fi
		done
		if [ "$reference_test" = "out" ] ; then
			echo "ERROR: Zoom reference point is outside of AOT!"
			exit 2
		fi
	else
		pnt_zoom_ref_lat="$( echo "scale = 8; ( $point_lat + $lowright_lat ) / 2" | bc )"
		pnt_zoom_ref_lon="$( echo "scale = 8; ( $point_lon + $lowright_lon ) / 2" | bc )"
		cursor_reference="$( GetQuadtreeAddress $pnt_zoom_ref_lon $pnt_zoom_ref_lat )"
		echo "Point for zoom reference default center image: $pnt_zoom_ref_lat Lat, $pnt_zoom_ref_lon Lon..."
	fi
	while : ; do
		upDateServer
		remote="$( swget "${server[0]}${cursor_reference}" 2>&1 )"
		if [ ! -z "$( echo "$remote" | grep "403 Forbidden" )" ] || [ ! -z "$( echo "$remote" | grep "503 Service Unavailable" )" ]  ; then
			echo "ERROR from Google Maps: Forbidden! You must wait one day!"
			exit 4
	
		fi
		[ -z "$( echo "$remote" | grep "404 Not Found" )" ] && break
		echo "Layer does not exist, dezooming one step..."
		cursor_reference="$( echo "$cursor_reference"  | rev | cut -c 2- | rev  )"

	done
	
	while : ; do
		echo "-----------------------------------------------------------"
		echo "Tile size: $( tile_resolution $cursor_reference ) meters ( Level: $( echo -n "$cursor_reference" | wc -c ) )..."
		echo "Use this URL to view an example: ${server}${cursor_reference}"
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
	echo "Searching ROI size and calculating elaboration time..."
	while : ; do
		echo "Getting upper left coordinates..."
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
		echo "Size of tiles $dim_x x $dim_y ..."

		 [ "$( uname -s )" = "Linux" ]  && end_date="$( date --date=@$[ $(  date +%s ) +  ( $dim_x * $dim_y * $SLEEP_TIME ) ] )"
		 [ "$( uname -s )" = "Darwin" ] && end_date="$( date -v+$[ $dim_x * $dim_y * $SLEEP_TIME ]S )"
		
		echo "Estimated end date for download tiles: $end_date..."
		echo "Tile site: $( tile_resolution $cursor_reference ) meters ( Level: $( echo -n "$cursor_reference" | wc -c ) )..."
		echo "Use this URL to view an example: $server$cursor_reference"
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
		echo "Force to use Water Mask..."
		WATER_MASK="yes"

		while : ; do
			echo "Set MESH LEVEL: $MESH_LEVEL -> $( echo "(4^$MESH_LEVEL) * 2" | bc )  triangles for tile"
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
	echo "Creating tiles list..."

	tot=$[ $dim_x * $dim_y ]

	dim_x=$[ $dim_x - 1 ]
	dim_y=$[ $dim_y - 1 ]


	echo "Randomizing tile list..."
	echo "Step 1..."
	in_order=( $( seq 0 $[ $tot - 1 ] | tr "\n" " " ) )
	i="0"
	cnt=1

	while [ "${#in_order[*]}" != "0" ] ; do
		echo -ne "Step 2: $cnt / $tot...\r"
		ran=$[ $RANDOM % ${#in_order[*]} ]
		tile_index[$i]="${in_order[$ran]}"
		unset in_order[$ran] 
		in_order=( ${in_order[*]} )
		i=$[ $i + 1 ]
		cnt=$[ $cnt + 1 ]
	done
	echo

	i="0"
	cnt=1
	cursor_tmp="$cursor"
	for x in $( seq 0 $dim_x ) ; do	
		c2="$cursor_tmp"
		cursor_tmp="$( GetNextTileX $cursor_tmp 1 )"

		for y in $( seq 0 $dim_y  ) ; do
			echo -ne "Step 3: $cnt / $tot...\r"
			if [ ! -z "${poly[*]}" ] ; then	
				info=( $( GetCoordinatesFromAddress $c2 ) )
				# $lon $lat $lon_min $lat_min $lon_max $lat_max

				for j in $( echo ${poly[*]} | tr " " "\n" | awk -F, {'print $1'} | tr "\n" " " ) ; do
					tmp_poly="$( echo ${poly[*]} | tr " " "\n" | grep "^${j}," | awk -F, {'print $2","$3'} | tr "\n" " " )"
					inout="$( pointInPolygon "${info[2]}" "${info[3]}" "$tmp_poly" )"
					[ "$inout" = "out" ] && inout="$( pointInPolygon "${info[4]}" "${info[5]}" "$tmp_poly" )"
					[ "$inout" = "out" ] && inout="$( pointInPolygon "${info[2]}" "${info[5]}" "$tmp_poly" )"
					[ "$inout" = "out" ] && inout="$( pointInPolygon "${info[4]}" "${info[3]}" "$tmp_poly" )"
					[ "$inout" = "in"  ] && break
				done

				if  [ "$inout" = "out" ] ; then
					tile_check="no"
				else
					tile_check="yes"
				fi
			else
					tile_check="yes"
			fi

			[ "$tile_check" = "yes" ] && good_tile[${tile_index[$i]}]="$c2"

			c_last="$c2"
			c2="$( GetNextTileY $c2 1 )"
			cnt=$[ $cnt + 1 ]
			i=$[ $i + 1 ]
		done
	done
	echo
	echo "good_tile=( ${good_tile[@]} )"  >> "$nfo_file"
fi
REMAKE_TILE="no"
if [ "$RESTORE" = "yes" ] ; then
	echo "Restoring section $nfo_file..."
	. "$nfo_file"
	if 	[ -z "$dim_x" ] 	|| \
	 	[ -z "$dim_y" ] 	|| \
	 	[ -z "$good_tile" ] 	|| \
	 	[ -z "$cursor" ] 	|| \
		[ -z "$MASH_SCENARY" ]	|| \
		[ -z "$MESH_LEVEL" ]	|| \
	 	[ -z "$WATER_MASK" ] 	; then
		echo "Input file is corrupted, I must remove it."
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
echo "Download tiles..."
cnt="1"
tot="${#good_tile[@]}"

SHIT_COLOR="E4E3DF"
#[ "$( uname -s )" = "Linux" ]  && SHIT_COLOR="#E4E4E3E3DFDF"

for c2 in ${good_tile[@]} ; do
	echo  "$cnt / $tot"
	if [ -f "$tiles_dir/tile-$c2.png" ] ; then
		[ "$( testImage "$tiles_dir/tile-$c2.png" )" != "good" ] && rm -f "$tiles_dir/tile-$c2.png"
	fi
	if [ ! -f "$tiles_dir/tile-$c2.png" ] ; then
		upDateServer
		ewget "$tiles_dir/${TMPFILE}.jpg" "${server[0]}$c2"  &> /dev/null
		if [ ! -f "$tiles_dir/${TMPFILE}.jpg" ] ; then
			echo "Elaboration problem!!"
			exit 6
		fi
		if [ "$( du -s "$tiles_dir/${TMPFILE}.jpg" | awk {'print $1'} )" != "0" ] ; then
			blank="$( convert  "$tiles_dir/${TMPFILE}.jpg"  -crop 1x255+0+0 txt:- | grep -v "^#" | grep -i "$SHIT_COLOR"  | wc -l )"
			if [  "$( echo "scale = 8; ( $blank > 10 )" | bc )" = "1" ] ; then
				echo -n "" > "$tiles_dir/${TMPFILE}.jpg"
			fi
		fi
		if [ "$( du -s "$tiles_dir/${TMPFILE}.jpg" | awk {'print $1'} )" = "0" ] ; then
			echo "In this area I didn't find same tile for this zoom..."
			rm -f "$tiles_dir/${TMPFILE}.jpg"
			upDateServer
			subc2="$c2"
			while [ ! -z "$subc2" ] ; do
				echo "Try to zoom out one step..."
				subc2="$( echo "$subc2" | rev | cut -c 2- | rev )"

				ewget  "$tiles_dir/${TMPFILE}.jpg" "${server[0]}$subc2" &> /dev/null

				if [ "$( du -s "$tiles_dir/${TMPFILE}.jpg" | awk {'print $1'} )" != "0" ] ; then
					blank="$( convert  "$tiles_dir/${TMPFILE}.jpg"   -crop 1x255+0+0 txt:- | grep -v "^#" | grep -i "$SHIT_COLOR"  | wc -l )"
					if [  "$( echo "scale = 8; ( $blank < 10 )" | bc )" = "1" ] ; then
						break
					else
						rm "$tiles_dir/${TMPFILE}.jpg"
					fi
				fi

				echo -n "Wait: "
				for i in $( seq $SLEEP_TIME ) ; do
					echo -n "$i..."
					sleep 1
				done
				echo
				rm -f "$tiles_dir/${TMPFILE}.jpg"
			done
			if [ -f "$tiles_dir/${TMPFILE}.jpg" ] ; then
				if  [ "$( du -s "$tiles_dir/${TMPFILE}.jpg" | awk {'print $1'} )" != "0" ] ; then
					convert "$tiles_dir/${TMPFILE}.jpg" -format PNG32 "$tiles_dir/tile-$subc2-ori.png"
					rm -f "$tiles_dir/${TMPFILE}.jpg"
				fi
			fi

			
			if [ ! -z "$subc2" ] ; then
				if  [ "$( du -s "$tiles_dir/tile-$subc2-ori.png" | awk {'print $1'} )" != "0" ]	; then
					echo "Found tile with less zoom..."
					convert "$tiles_dir/tile-$subc2-ori.png" -format PNG32 -crop $( findWhereIcut $c2 $subc2 )  -resize 256x256 "$tiles_dir/tile-$c2.png"
				else
					echo "Not found file with same zoom... Hole in scenery for tile ${server[0]}$c2 !"
				fi
			else
				echo "Could dot find file with the same zoom... Hole in scenery for tile ${server[0]}$c2 !"
			fi
			rm -f "$tiles_dir/${TMPFILE}.jpg"
		else
			convert "$tiles_dir/${TMPFILE}.jpg"  -format PNG32  "$tiles_dir/tile-$c2.png"
			rm -f "$tiles_dir/${TMPFILE}.jpg"
		fi

		echo -n "Wait: "
		for i in $( seq $SLEEP_TIME ) ; do
			echo -n "$i..."
			sleep 1
		done
		echo
	fi
	cnt=$[ $cnt + 1 ]
done

echo "Screnary creation...."
[ "$WATER_MASK" = "yes" ] && echo "Water mask Enabled..."
good_tile=( $( echo "${good_tile[@]}" | tr " " "\n" | rev | cut -c 4- | rev | sort -u | tr "\n" " " ) )

echo "Remove across images..."
cnt=0
i=0
while [ ! -z "${good_tile[$cnt]}" ] ; do
	info=( $( GetCoordinatesFromAddress ${good_tile[$cnt]} ) )

        ul_lat="${info[3]}"
        ul_lon="${info[4]}"
        lr_lat="${info[5]}"
        lr_lon="${info[2]}"

	if [ "$[ ${lr_lat%.*} + 1  ]" = "${ul_lat%.*}" ] ; then
		split_tile[$i]="${good_tile[$cnt]}"
		i=$[ $i + 1 ]
		unset good_tile[$cnt]
		cnt=$[ $cnt + 1 ]
		continue
	fi
	if [ "$[ ${lr_lon%.*} + 1  ]" = "${ul_lon%.*}" ] ; then
		split_tile[$i]="${good_tile[$cnt]}"
		i=$[ $i + 1 ]
		unset good_tile[$cnt]
		cnt=$[ $cnt + 1 ]
		continue
	fi
	if [ "$( echo "scale = 8; ( $ul_lat > 0 ) && ( $lr_lat < 0 ) " | bc -l )" = "1" ] ; then
		split_tile[$i]="${good_tile[$cnt]}"
		i=$[ $i + 1 ]
		unset good_tile[$cnt]
		cnt=$[ $cnt + 1 ]
		continue
	fi
	if [ "$( echo "scale = 8; ( $lr_lon > 0 ) && ( $ul_lon < 0 ) " | bc -l )" = "1" ] ; then
		split_tile[$i]="${good_tile[$cnt]}"
		i=$[ $i + 1 ]
		unset good_tile[$cnt]
		cnt=$[ $cnt + 1 ]
		continue
	fi

	cnt=$[ $cnt + 1 ]
done
split_tile=( $( echo "${split_tile[@]}" | tr " " "\n" | sort -u | tr "\n" " " ) )
echo "Removed ${#split_tile[@]} image(s)..."

echo "Merging tiles into 2048x2048 texture..."
tile_seq="$( seq 0 7 )"
prog="1"
tot="${#good_tile[@]}"
for cursor_huge in ${good_tile[@]} ; do

	cursor_tmp=$cursor_huge"qqq"
	echo -n "$prog / $tot "
	[ "$REMAKE_TILE" = "yes" ] && [ -f "$tiles_dir/tile-$cursor_huge.png" ] && rm -f "$tiles_dir/tile-$cursor_huge.png" 

	# Uncommend if you want force recreation
	# rm -fr "$tiles_dir/tile-$cursor_huge.png"

	if [ -f "$tiles_dir/tile-$cursor_huge.png" ] ; then
		[ "$( testImage "$tiles_dir/tile-$cursor_huge.png" )" != "good" ] && rm -f "$tiles_dir/tile-$cursor_huge.png"
	fi

	if  [ ! -f "$tiles_dir/tile-$cursor_huge.png" ] ; then
		if [ "$WATER_MASK" = "yes" ] ; then

			# Uncommend if you want force recreation
			# rm -f "$tiles_dir/map-$cursor_huge.png"

			if [ -f "$tiles_dir/map-$cursor_huge.png" ] ; then
				[ "$( testImage "$tiles_dir/map-$cursor_huge.png" )" != "good" ] && rm -f "$tiles_dir/map-$cursor_huge.png"
			fi

			if  [ ! -f "$tiles_dir/map-$cursor_huge.png" ] ; then
				upDateServer
				ewget "$tiles_dir/${TMPFILE}.png" "${server[1]}$( qrst2xyz "$cursor_huge" )"
				if [ "$( du -s "$tiles_dir/${TMPFILE}.png" | awk {'print $1'} )" = "0" ] ; then
					echo -n ""  >  "$tiles_dir/map-$cursor_huge.png"
				else
					echo -n "Analizing tiles... "
					content="$( convert  "$tiles_dir/${TMPFILE}.png"   txt:- | grep -v "^#" | grep -vi "#99b3cc"  | wc -l )"
					if [  "$( echo "scale = 8; ( $content / (256*256) * 100 ) <= $MAX_PERC_COVER" | bc )" = 1 ] ; then
						echo -n ""  >  "$tiles_dir/map-$cursor_huge.png"	
					else
						convert  -fuzz 8%  "$tiles_dir/${TMPFILE}.png" -format PNG32 -transparent "#99b3cc" -filter Point -resize 2048x2048 "$tiles_dir/map-$cursor_huge.png"
					fi
					echo -n "Done "
				fi
				rm -f "$tiles_dir/${TMPFILE}.png"
		                for i in $( seq $SLEEP_TIME ) ; do
					echo -n "."
		                        sleep 1
				done

			fi
		fi
		cnt="0"
		for x in $tile_seq ; do
			c2="$cursor_tmp"
			cursor_tmp="$( GetNextTileX $cursor_tmp 1 )"
			for y in $tile_seq ; do
				in_file="$( dirname -- "$0" )/ext_app/images/trans.png"

				[ -f "$tiles_dir/tile-$c2.png" ] && in_file="$tiles_dir/tile-$c2.png"
					
	                        convert -page +$[ 256 * $x  ]+$[ 256 * $y ] "$in_file" "$tiles_dir/tile-$cursor_huge-$x-$y.png"
				texture_tile[$cnt]="tile-$cursor_huge-$x-$y.png"
				echo -ne "."
				cnt=$[ $cnt + 1 ]
	
		                c_last="$c2"
		                c2="$( GetNextTileY $c2 1 )"
		        done
		done
		if [ "$WATER_MASK" = "yes" ] ;then
			if [ "$( du -k  "$tiles_dir/map-$cursor_huge.png" | awk {'print $1'} )" != "0" ] ; then
				convert  -layers mosaic "$tiles_dir/{$( echo ${texture_tile[@]} | tr " " ",")}"  -format PNG32 -background transparent "$tiles_dir/tile-ww-$cursor_huge.png"
				composite -compose Dst_In "$tiles_dir/map-$cursor_huge.png" "$tiles_dir/tile-ww-$cursor_huge.png" "$tiles_dir/${TMPFILE}.png"
				rm -f "$tiles_dir/tile-ww-$cursor_huge.png"
				convert "$tiles_dir/${TMPFILE}.png" -format PNG32 -transparent "#000000" "$tiles_dir/tile-$cursor_huge.png"
				rm -f "$tiles_dir/${TMPFILE}.png"
			else
				convert  -layers mosaic "$tiles_dir/{$( echo ${texture_tile[@]} | tr " " ",")}"  -format PNG32 -background transparent "$tiles_dir/tile-$cursor_huge.png"
			fi
		else
			convert  -layers mosaic "$tiles_dir/{$( echo ${texture_tile[@]} | tr " " ",")}"   -format PNG32 -background transparent "$tiles_dir/tile-$cursor_huge.png"
		fi
		
		for r in  ${texture_tile[@]} ; do 
			rm -f "$tiles_dir/$r"
		done
	
		unset texture_tile
	
	fi
	echo
	prog=$[ $prog + 1 ]
done
echo



dim_x=$[  ( $dim_x + ( 8 % $dim_x ) ) / 8 ]
dim_y=$[  ( $dim_y + ( 8 % $dim_y ) ) / 8 ]

[ "$dim_x" = "0" ] && dim_x="1"
[ "$dim_y" = "0" ] && dim_y="1"


cnt="0"
prog="1"
cursor_tmp="$( echo "$cursor"  | rev | cut -c 4- | rev )"



TER_DIR="$output_dir/$TER_DIR"
if [ "$MASH_SCENARY" = "yes" ] ; then
	echo "Mesh level $MESH_LEVEL..."
	if [ ! -d  "$TER_DIR" ] ; then
	        echo "Creating directory $TER_DIR..."
	        mkdir -p -- "$TER_DIR"
	else
	        echo "Directory $TER_DIR already exists..."
	fi
fi



KML_FILE="$output_dir/scenary.kml"
createKMLoutput HEAD "$KML_FILE" "$( echo "$output_dir" | tr -d "/" )"

tot="${#good_tile[@]}"
dfs_index="0"
dfs_file=""
index_triangle="0"
for x in $( seq 0 $dim_x ) ; do
        c2="$cursor_tmp"
        cursor_tmp="$( GetNextTileX $cursor_tmp 1 )"

        for y in $( seq 0 $dim_y  ) ; do

		info=( $( GetCoordinatesFromAddress $c2 ) )	
		point_lon="${info[0]}"
		point_lat="${info[1]}"

		[ -z "$( echo "${point_lon%.*}" | tr -d "-" )" ] && point_lon="$( echo "$point_lon" | sed -e s/"\."/"0\."/g )" 
		[ -z "$( echo "${point_lat%.*}" | tr -d "-" )" ] && point_lat="$( echo "$point_lat" | sed -e s/"\."/"0\."/g )" 

		if [ "$x" = "0" ] ; then
			if [ "$y" = "0" ] ; then
				ori_ul_lon="$( echo "scale = 8; ${info[2]} + $lon_fix" | bc -l )"
				ori_ul_lat="$( echo "scale = 8; ${info[3]} + $lat_fix" | bc -l )"
			else
				ori_ul_lon="$ori_ul_lon"
				ori_ul_lat="$ori_lr_lat"
			fi
		else
			if [ "$y" = "0" ] ; then
				ori_ul_lon="$ori_lr_lon"
				#ori_ul_lat="$ori_ul_lat"
				ori_ul_lat="$zero_line_lat"

			else
				ori_ul_lon="$ori_ul_lon"
				ori_ul_lat="$ori_lr_lat"
			fi
		fi
		[ "$y" = "0" ] && zero_line_lat="$ori_ul_lat"

		ori_lr_lon="$( echo "scale = 8; ${info[4]} + $lon_fix" | bc -l )"
		ori_lr_lat="$( echo "scale = 8; ${info[5]} + $lat_fix" | bc -l )"	

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
			ul_lon="$( echo "scale = 8;  $ul_lon * c( ($pi/180) * $rot_fix ) - $ul_lat * s( ($pi/180) * $rot_fix )" | bc -l )"
			ul_lat="$( echo "scale = 8;  $ul_lon * s( ($pi/180) * $rot_fix ) + $ul_lat * c( ($pi/180) * $rot_fix )" | bc -l )"
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

		ul_lat="$( echo "$ul_lat" | awk '{ printf "%.8f", $1 }')"
		ul_lon="$( echo "$ul_lon" | awk '{ printf "%.8f", $1 }')"

		ur_lat="$( echo "$ur_lat" | awk '{ printf "%.8f", $1 }')"
		ur_lon="$( echo "$ur_lon" | awk '{ printf "%.8f", $1 }')"

		lr_lat="$( echo "$lr_lat" | awk '{ printf "%.8f", $1 }')"
		lr_lon="$( echo "$lr_lon" | awk '{ printf "%.8f", $1 }')"

		ll_lat="$( echo "$ll_lat" | awk '{ printf "%.8f", $1 }')"
		ll_lon="$( echo "$ll_lon" | awk '{ printf "%.8f", $1 }')"

		if [ "${#split_tile[@]}"  = "0" ] ; then
			[ "$( echo "$ul_lat" | awk '{ printf "%0.5f\n", $1 }' | tr -d "-" )" = "0.00001" ] && ul_lat="0.00000000"
			[ "$( echo "$ul_lon" | awk '{ printf "%0.5f\n", $1 }' | tr -d "-" )" = "0.00001" ] && ul_lon="0.00000000"

			[ "$( echo "$ur_lat" | awk '{ printf "%0.5f\n", $1 }' | tr -d "-" )" = "0.00001" ] && ur_lat="0.00000000"
			[ "$( echo "$ur_lon" | awk '{ printf "%0.5f\n", $1 }' | tr -d "-" )" = "0.00001" ] && ur_lon="0.00000000"

			[ "$( echo "$lr_lat" | awk '{ printf "%0.5f\n", $1 }' | tr -d "-" )" = "0.00001" ] && lr_lat="0.00000000"
			[ "$( echo "$lr_lon" | awk '{ printf "%0.5f\n", $1 }' | tr -d "-" )" = "0.00001" ] && lr_lon="0.00000000"

			[ "$( echo "$ll_lat" | awk '{ printf "%0.5f\n", $1 }' | tr -d "-" )" = "0.00001" ] && ll_lat="0.00000000"
			[ "$( echo "$ll_lon" | awk '{ printf "%0.5f\n", $1 }' | tr -d "-" )" = "0.00001" ] && ll_lon="0.00000000"

		fi
		CROSSED_TILE=( ${CROSSED_TILE[@]} ${c2}_${ul_lon},${ul_lat}_${lr_lon},${lr_lat} )


		
		if [ -f "$tiles_dir/tile-$c2.png" ] && [ ! -z "$( echo "${good_tile[@]}" | tr " " "\n" | grep "$c2" )" ] ; then
			POL_FILE="poly_${point_lat}_${point_lon}.pol"
			TEXTURE="img_${point_lat}_${point_lon}.dds"
			TER="ter_${point_lat}_${point_lon}.ter"

			LC_lat_center="$( echo "scale = 8; ( $ul_lat + $lr_lat ) / 2" | bc | awk '{ printf "%.8f", $1 }' )"
			LC_lon_center="$( echo "scale = 8; ( $ul_lon + $lr_lon ) / 2" | bc | awk '{ printf "%.8f", $1 }' )"
			LC_dim="$( tile_size $c2 | awk -F. {'print $1'} )"
			LC_size="$( identify "$tiles_dir/tile-$c2.png" | awk {'print $3'} | awk -Fx {'print $1'} )"



			[ "$MASH_SCENARY" = "yes" ] && TARGET_IMG_DIR="$TER_DIR"
			[ "$MASH_SCENARY" = "no"  ] && TARGET_IMG_DIR="$output_dir"

			[ -f "$TARGET_IMG_DIR/$TEXTURE" ] && [ ! -f "$tiles_dir/tile-$c2.dds" ] && cp -f "$TARGET_IMG_DIR/$TEXTURE" "$tiles_dir/tile-$c2.dds"

		        if [ ! -f "$TARGET_IMG_DIR/$TEXTURE" ] ; then
				if [ ! -f "$tiles_dir/tile-$c2.dds" ] ; then
					if [ "$( uname -s )" = "Linux" ] ; then
						wine "$ddstool" --png2dxt "$tiles_dir/tile-$c2.png" "$TARGET_IMG_DIR/$TEXTURE"
					else
						"$ddstool" --png2dxt "$tiles_dir/tile-$c2.png" "$TARGET_IMG_DIR/$TEXTURE"
					fi
					cp -f "$TARGET_IMG_DIR/$TEXTURE" "$tiles_dir/tile-$c2.dds"
				else
					cp -f "$tiles_dir/tile-$c2.dds" "$TARGET_IMG_DIR/$TEXTURE"
				fi
		        fi


			if [ "$MASH_SCENARY" = "yes" ] ; then
			        if [ ! -f "$TER_DIR/$TER" ] ; then
			                echo "A"                           					>  "$TER_DIR/$TER"
			                echo "800"                              				>> "$TER_DIR/$TER"
			                echo "TERRAIN"                          				>> "$TER_DIR/$TER"
			                echo                                    				>> "$TER_DIR/$TER"
			                echo "BASE_TEX_NOWRAP $TEXTURE"         				>> "$TER_DIR/$TER"
					echo "LOAD_CENTER $LC_lat_center $LC_lon_center $LC_dim $LC_size"	>> "$TER_DIR/$TER"
			       fi
			fi

			[ "$MASH_SCENARY" = "no" ] && createKMLoutput ADD  "$KML_FILE" "$TEXTURE" $ori_ul_lat $ori_lr_lat $ori_lr_lon $ori_ul_lon $rot_fix

			if  [ "$dfs_file" != "$( getDSFName "$point_lat" "$point_lon" )" ] ; then

				if [ "$MASH_SCENARY" = "yes" ] ; then
					if [ "$output_index" != "0" ] && [ -f  "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file.txt" ]; then
						j="0"
						echo "Unload buffer for file $dfs_file..."
						( while [ "$j" != "$output_index" ] ; do                                                                                                                                          
	
						        echo "${output[$j]}"
						        j=$[ $j + 1 ]
						
						done ) >>  "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file.txt"
						output_index="0"
						output=()
					fi
				fi

				dfs_dir="$( getDirName "$point_lat" "$point_lon" )"

				if [ ! -d "$output_dir/$output_sub_dir/$dfs_dir" ] ; then
					echo "Create DSF directory \"$dfs_dir\"...                                             "
					mkdir "$output_dir/$output_sub_dir/$dfs_dir"
				fi

				dfs_file="$( getDSFName "$point_lat" "$point_lon" )"
				dfs_list[$dfs_index]="$dfs_dir/$dfs_file"	
				if [ "$MASH_SCENARY" = "yes" ] ; then
					dfs_tri_count="$dfs_index"	
					dfs_triangle[$dfs_tri_count]=""
				fi

				dfs_index="$[ $dfs_index + 1 ]"

				[ "$( echo "$point_lat < 0" | bc )" = 1  ] && \
					max_lat="$( echo "$point_lat"	  | bc | awk -F. {'print $1'} )" && \
					min_lat="$( echo "$point_lat - 1" | bc | awk -F. {'print $1'} )"

				[ "$( echo "$point_lat > 0" | bc )" = 1  ] && 
					max_lat="$( echo "$point_lat + 1" | bc | awk -F. {'print $1'} )" && \
					min_lat="$( echo "$point_lat" 	  | bc | awk -F. {'print $1'} )"

				[ -z "$min_lat" 	] && min_lat="0"
				[ "$min_lat" = "-" 	] && min_lat="-0"
				[ -z "$max_lat" 	] && max_lat="0"
				[ "$max_lat" = "-" 	] && max_lat="-0"
	
				[ "$( echo "$point_lon < 0" | bc )" = 1  ] && \
					max_lon="$( echo "$point_lon" 	  | bc | awk -F. {'print $1'} )" && \
					min_lon="$( echo "$point_lon - 1" | bc | awk -F. {'print $1'} )"

				[ "$( echo "$point_lon > 0" | bc )" = 1  ] && 
					max_lon="$( echo "$point_lon + 1" | bc | awk -F. {'print $1'} )" && \
					min_lon="$( echo "$point_lon" 	  | bc | awk -F. {'print $1'} )"

				[ -z "$min_lon" 	] && min_lon="0"
				[ "$min_lon" = "-" 	] && min_lon="-0"
				[ -z "$max_lon" 	] && max_lon="0"
				[ "$max_lon" = "-" 	] && max_lon="-0"


				if [ ! -f "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file.txt" ] ; then
					cnt="0"
					echo "Creating file $dfs_file....                                                    "

					echo "A" 							>  "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file".txt 
					#echo "800" 							>> "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file".txt 
					echo "$XPLANE_CMD_VERSION" 					>> "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file".txt 
					echo "DSF2TEXT" 						>> "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file".txt 

					echo "PROPERTY sim/creation_agent $( basename -- "$0" )"	>> "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file".txt 
					echo "PROPERTY sim/planet earth" 				>> "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file".txt 

					[ "$MASH_SCENARY" = "no" ] && echo "PROPERTY sim/overlay 1" 	>> "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file".txt

					echo "PROPERTY sim/west $min_lon" 				>> "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file".txt 
					echo "PROPERTY sim/east $max_lon" 				>> "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file".txt 
					echo "PROPERTY sim/north $max_lat" 				>> "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file".txt 
					echo "PROPERTY sim/south $min_lat" 				>> "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file".txt 
					echo 								>> "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file".txt

					[ "$MASH_SCENARY" = "yes" ] && echo "TERRAIN_DEF terrain_Water" >> "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file".txt 
					echo 								>> "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file".txt


		
				else
					[ "$MASH_SCENARY" = "no"  ] && cnt="$( cat "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file.txt" | grep "BEGIN_POLYGON" | tail -n 1 | awk {'print $2'} )"
					[ "$MASH_SCENARY" = "yes" ] && cnt="$( cat "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file.txt" | grep "TERRAIN_DEF"   | grep -v "terrain_Water" | wc -l | awk {'print $1'} )"
					cnt=$[ $cnt + 1 ]	
				fi

			else
				[ "$MASH_SCENARY" = "no"  ] && cnt="$( cat "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file.txt" | grep "BEGIN_POLYGON" | tail -n 1 | awk {'print $2'} )"
				[ "$MASH_SCENARY" = "yes" ] && cnt="$( cat "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file.txt" | grep "TERRAIN_DEF"   | grep -v "terrain_Water" | wc -l | awk {'print $1'} )"
				cnt=$[ $cnt + 1 ]	
			fi

			if [ "$MASH_SCENARY" = "yes" ] ; then
				last_ter="$( cat "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file.txt" | grep "TERRAIN_DEF" | tail -n 1 | sed -e s/"\/"/":"/g )"
				if [ -z "$last_ter" ] ; then
					echo  "TERRAIN_DEF $( basename -- "$TER_DIR" )/$TER" >>  "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file.txt"
				else
					tmp_content="$( cat  "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file.txt" | sed -e s/"\/"/":"/g  )"
					 [ "$( uname -s )" = "Linux" ]   && echo "$tmp_content" | sed -e s/"$last_ter"/"$last_ter\nTERRAIN_DEF $( basename -- "$TER_DIR" ):$TER\n"/g | sed -e s/":"/"\/"/g > "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file.txt"
					 [ "$( uname -s )" = "Darwin" ]  && echo "$tmp_content" | sed -e s/"$last_ter"/"$last_ter;TERRAIN_DEF $( basename -- "$TER_DIR" ):$TER;"/g | sed -e s/":"/"\/"/g | tr ";" "\n" > "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file.txt"
					
					unset tmp_content

				fi
			fi

#			[ -z "$( echo "${ul_lat%.*}" | tr -d "-" )" ] && ul_lat="$( echo "$ul_lat" | sed -e s/"\."/"0\."/g )" 
#			[ -z "$( echo "${ul_lon%.*}" | tr -d "-" )" ] && ul_lon="$( echo "$ul_lon" | sed -e s/"\."/"0\."/g )" 
#
#			[ -z "$( echo "${ur_lat%.*}" | tr -d "-" )" ] && ur_lat="$( echo "$ur_lat" | sed -e s/"\."/"0\."/g )" 
#			[ -z "$( echo "${ur_lon%.*}" | tr -d "-" )" ] && ur_lon="$( echo "$ur_lon" | sed -e s/"\."/"0\."/g )" 
#
#			[ -z "$( echo "${lr_lat%.*}" | tr -d "-" )" ] && lr_lat="$( echo "$lr_lat" | sed -e s/"\."/"0\."/g )" 
#			[ -z "$( echo "${lr_lon%.*}" | tr -d "-" )" ] && lr_lon="$( echo "$lr_lon" | sed -e s/"\."/"0\."/g )" 
#
#			[ -z "$( echo "${ll_lat%.*}" | tr -d "-" )" ] && ll_lat="$( echo "$ll_lat" | sed -e s/"\."/"0\."/g )" 
#			[ -z "$( echo "${ll_lon%.*}" | tr -d "-" )" ] && ll_lon="$( echo "$ll_lon" | sed -e s/"\."/"0\."/g )" 
#



			if [ "$MASH_SCENARY" = "no" ] ; then
				echo -ne "$prog / $tot: Creating polygon (.pol) file \"$POL_FILE\"...                          \r"
		
				if [ -f "$output_dir/$POL_FILE" ] ; then
					echo "Error! Polygon file already exists!"
					exit 3
				fi
				echo "A"								>  "$output_dir/$POL_FILE"
				echo "850"								>> "$output_dir/$POL_FILE"
				echo "DRAPED_POLYGON"							>> "$output_dir/$POL_FILE"
				echo 									>> "$output_dir/$POL_FILE"
				echo "LAYER_GROUP airports -1"						>> "$output_dir/$POL_FILE"
				echo "TEXTURE_NOWRAP $TEXTURE"						>> "$output_dir/$POL_FILE"
				echo "SCALE 25 25"							>> "$output_dir/$POL_FILE"
				echo "LOAD_CENTER $LC_lat_center $LC_lon_center $LC_dim $LC_size"       >> "$output_dir/$POL_FILE"	

				################################

				# create dsf file ....
				echo "POLYGON_DEF $POL_FILE"				>> "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file.txt"
				echo "BEGIN_POLYGON $cnt 65535 4"			>> "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file.txt"
				echo "BEGIN_WINDING"					>> "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file.txt"
				echo "POLYGON_POINT $lr_lon	$lr_lat		1 0"	>> "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file.txt"
				echo "POLYGON_POINT $ur_lon	$ur_lat		1 1"	>> "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file.txt"
				echo "POLYGON_POINT $ul_lon	$ul_lat		0 1"	>> "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file.txt"
				echo "POLYGON_POINT $ll_lon	$ll_lat		0 0"	>> "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file.txt"
				echo "END_WINDING"					>> "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file.txt"
				echo "END_POLYGON"					>> "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file.txt"
				echo  							>> "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file.txt"
				################################
			fi


			if [ "$MASH_SCENARY" = "yes" ] ; then
				
				mesh_level="0"
			        mesh=""
			        new_vertex=""
				POINTS=( "${lr_lon},${lr_lat}_1.00000000,0.00000000" "${ur_lon},${ur_lat}_1.00000000,1.00000000" "${ul_lon},${ul_lat}_0.00000000,1.00000000" "${ll_lon},${ll_lat}_0.00000000,0.00000000" )
			       	if [ "${#POINTS[@]}" != "4" ] ; then
                			echo "ERROR: POINTS corrupted..."
			                exit 5

			        fi
			        vertex="$( echo "${POINTS[@]}"  | tr " " ";" )"
			        echo -n "$[ ${#FINAL_TRIANGLES[@]} + 1 ] / $tot Create mash "
				md5mesh="$( echo "$MESH_LEVEL ${POINTS[@]}" | md5sum | awk {'print $1'} )"
				mesh_file="$tiles_dir/$md5mesh.msh"	
				if [ -f  "$mesh_file" ] ; then
					mesh_tmp=( $( cat "$mesh_file" ) )
					if [ "$( echo "scale = 8; ${#mesh_tmp[@]} == (4^$MESH_LEVEL)" | bc  )" != "1" ] ; then
						rm -f "$mesh_file"
					else
						echo -n "from cache..."
						mesh="${mesh_tmp[@]}"
					fi
								
				fi
				if [ ! -f  "$mesh_file" ] ; then
				        while [ "$mesh_level" != "$MESH_LEVEL" ] ; do
						echo -n "$mesh_level"
				                for square in $vertex ; do
			        	                POINTS=( $( echo "$square" | tr ";" " " ) )
	                			        new_vertex="$new_vertex $( divideSquare ${POINTS[0]} ${POINTS[1]} ${POINTS[2]} ${POINTS[3]} )"
			                	        echo -n "."
			                	done
			                	vertex="$new_vertex"
						new_vertex=""
			                	mesh_level="$[ $mesh_level + 1 ]"		
				        done
				        mesh="$vertex"
				        echo -n "$mesh" > "$mesh_file"
				fi

				FINAL_TRIANGLES[$index_triangle]="$( echo "$mesh" | tr " " "#" )"
				dfs_triangle[$dfs_tri_count]="${dfs_triangle[$dfs_tri_count]} $index_triangle"
				index_triangle="$[ $index_triangle + 1 ]"

				echo -n " Creating triangles "

				addLine
			        addLine "BEGIN_PATCH 0   0.0 -1.0    1   5"
			        addLine "BEGIN_PRIMITIVE 0"
				pcount="1"
				ptri="0"
			        for square in $mesh ; do
			                vertex=( $( echo "$square" | tr ";" " " ) )

			                vertex[0]="$( echo "${vertex[0]}" | tr "_" " " | tr "," "\t" )"
			                vertex[1]="$( echo "${vertex[1]}" | tr "_" " " | tr "," "\t" )"
			                vertex[2]="$( echo "${vertex[2]}" | tr "_" " " | tr "," "\t" )"
			                vertex[3]="$( echo "${vertex[3]}" | tr "_" " " | tr "," "\t" )"

			                # fetch coordinates
			                COORD[0]="$( echo "${vertex[0]}" | awk {'print $1" "$2'} )"
			                COORD[1]="$( echo "${vertex[1]}" | awk {'print $1" "$2'} )"
			                COORD[2]="$( echo "${vertex[2]}" | awk {'print $1" "$2'} )"
			                COORD[3]="$( echo "${vertex[3]}" | awk {'print $1" "$2'} )"     

			                # Search altitude
			                ALT[0]="$( getAltitude ${COORD[0]} )"
			                ALT[1]="$( getAltitude ${COORD[1]} )"
			                ALT[2]="$( getAltitude ${COORD[2]} )"
			                ALT[3]="$( getAltitude ${COORD[3]} )"

					
					createKMLoutput TRI "$KML_FILE" ${COORD[3]} ${COORD[1]} ${COORD[0]} 

 			                addLine "PATCH_VERTEX ${COORD[3]} ${ALT[3]} 0 0"
			               	addLine "PATCH_VERTEX ${COORD[1]} ${ALT[1]} 0 0"
			                addLine "PATCH_VERTEX ${COORD[0]} ${ALT[0]} 0 0"
					if [ "$ptri" = "84" ] ; then
						addLine "END_PRIMITIVE"
					        addLine "BEGIN_PRIMITIVE $pcount"
						pcount="$[ $pcount + 1 ]"
						ptri="0"
					fi
					ptri="$[ $ptri + 1 ]"

					createKMLoutput TRI "$KML_FILE" ${COORD[3]} ${COORD[2]} ${COORD[1]}

			                addLine "PATCH_VERTEX ${COORD[3]} ${ALT[3]} 0 0"
			                addLine "PATCH_VERTEX ${COORD[2]} ${ALT[2]} 0 0"
			                addLine "PATCH_VERTEX ${COORD[1]} ${ALT[1]} 0 0"
					if [ "$ptri" = "84" ] ; then
						addLine "END_PRIMITIVE"
					        addLine "BEGIN_PRIMITIVE $pcount"
						pcount="$[ $pcount + 1 ]"
						ptri="0"
					fi
					ptri="$[ $ptri + 1 ]"

 
			               echo -n "."
			        done

			       addLine "END_PRIMITIVE"
			       addLine "END_PATCH"
			       addLine

		#		createKMLoutput END  "$KML_FILE"  && exit
			fi
			echo
			cnt=$[ $cnt + 1 ]
			prog=$[ $prog + 1 ]
		else
			[ "$MASH_SCENARY" = "no" ] && echo -ne "$prog / $tot MISS...                                                              \r"
			if [ "$MASH_SCENARY" = "yes" ] ; then	
				if 	[ "$[ ${lr_lat%.*} + 1  ]" != "${ul_lat%.*}" ] 						&& \
					[ "$[ ${lr_lon%.*} + 1  ]" != "${ul_lon%.*}" ] 						&& \
					[ -z "$( echo "${split_tile[@]}" | tr " " "\n" | grep "$c2" )" ] 			&& \
					[ "$dfs_file" = "$( getDSFName "${lr_lat}" "${lr_lon}" )" ]				&& \
					[ "$dfs_file" = "$( getDSFName "${ur_lat}" "${ur_lon}" )" ]				&& \
					[ "$dfs_file" = "$( getDSFName "${ul_lat}" "${ul_lon}" )" ]				&& \
					[ "$dfs_file" = "$( getDSFName "${ll_lat}" "${ll_lon}" )" ]				&& \
					[ "$( echo "scale = 8; ( $ul_lat > 0 ) && ( $lr_lat < 0 ) " | bc -l )" != "1" ] 	&& \
					[ "$( echo "scale = 8; ( $lr_lon > 0 ) && ( $ul_lon < 0 ) " | bc -l )" != "1" ]	 ; then

					echo -n "$[ ${#FINAL_TRIANGLES[@]} + 1 ] / $tot Creating water mesh "


					mesh_level="0"
				        mesh=""
				        new_vertex=""
					POINTS=( "${lr_lon},${lr_lat}_1.00000000,0.00000000" "${ur_lon},${ur_lat}_1.00000000,1.00000000" "${ul_lon},${ul_lat}_0.00000000,1.00000000" "${ll_lon},${ll_lat}_0.00000000,0.00000000" )
				       	if [ "${#POINTS[@]}" != "4" ] ; then
	                			echo "ERROR: POINTS corrupted..."
				                exit 5
	
				        fi
				        vertex="$( echo "${POINTS[@]}"  | tr " " ";" )"
					md5mesh="$( echo "$MESH_LEVEL ${POINTS[@]}" | md5sum | awk {'print $1'} )"
					mesh_file="$tiles_dir/$md5mesh.msh"	
					if [ -f  "$mesh_file" ] ; then
						mesh_tmp=( $( cat "$mesh_file" ) )
						if [ "$( echo "scale = 8; ${#mesh_tmp[@]} == (4^$MESH_LEVEL)" | bc  )" != "1" ] ; then
							rm -f "$mesh_file"
						else
							echo -n "from cache..."
							mesh="${mesh_tmp[@]}"
						fi
								
					fi
					if [ ! -f  "$mesh_file" ] ; then
					        while [ "$mesh_level" != "$MESH_LEVEL" ] ; do
							echo -n "$mesh_level"
					                for square in $vertex ; do
				        	                POINTS=( $( echo "$square" | tr ";" " " ) )
		                			        new_vertex="$new_vertex $( divideSquare ${POINTS[0]} ${POINTS[1]} ${POINTS[2]} ${POINTS[3]} )"
				                	        echo -n "."
				                	done
				                	vertex="$new_vertex"
							new_vertex=""
				                	mesh_level="$[ $mesh_level + 1 ]"		
					        done
					        mesh="$vertex"
					        echo -n "$mesh" > "$mesh_file"
					fi

	
					echo -n " Create triangles "

					addLine
				        addLine "BEGIN_PATCH 0   0.0 -1.0    1   5"
				        addLine "BEGIN_PRIMITIVE 0"
					pcount="1"
					ptri="0"
				        for square in $mesh ; do
				                vertex=( $( echo "$square" | tr ";" " " ) )

				                vertex[0]="$( echo "${vertex[0]}" | tr "_" " " | tr "," "\t" )"
				                vertex[1]="$( echo "${vertex[1]}" | tr "_" " " | tr "," "\t" )"
				                vertex[2]="$( echo "${vertex[2]}" | tr "_" " " | tr "," "\t" )"
				                vertex[3]="$( echo "${vertex[3]}" | tr "_" " " | tr "," "\t" )"

				                # fetch coordinates
				                COORD[0]="$( echo "${vertex[0]}" | awk {'print $1" "$2'} )"
				                COORD[1]="$( echo "${vertex[1]}" | awk {'print $1" "$2'} )"
				                COORD[2]="$( echo "${vertex[2]}" | awk {'print $1" "$2'} )"
				                COORD[3]="$( echo "${vertex[3]}" | awk {'print $1" "$2'} )"     

				                # Search altitude
				                ALT[0]="$( getAltitude ${COORD[0]} )"
				                ALT[1]="$( getAltitude ${COORD[1]} )"
				                ALT[2]="$( getAltitude ${COORD[2]} )"
				                ALT[3]="$( getAltitude ${COORD[3]} )"

					
						createKMLoutput TRI "$KML_FILE" ${COORD[3]} ${COORD[1]} ${COORD[0]} 

 				                addLine "PATCH_VERTEX ${COORD[3]} ${ALT[3]} 0 0"
				               	addLine "PATCH_VERTEX ${COORD[1]} ${ALT[1]} 0 0"
				                addLine "PATCH_VERTEX ${COORD[0]} ${ALT[0]} 0 0"
						if [ "$ptri" = "84" ] ; then
							addLine "END_PRIMITIVE"
						        addLine "BEGIN_PRIMITIVE $pcount"
							pcount="$[ $pcount + 1 ]"
							ptri="0"
						fi
						ptri="$[ $ptri + 1 ]"

						createKMLoutput TRI "$KML_FILE" ${COORD[3]} ${COORD[2]} ${COORD[1]}

				                addLine "PATCH_VERTEX ${COORD[3]} ${ALT[3]} 0 0"
				                addLine "PATCH_VERTEX ${COORD[2]} ${ALT[2]} 0 0"
				                addLine "PATCH_VERTEX ${COORD[1]} ${ALT[1]} 0 0"
						if [ "$ptri" = "84" ] ; then
							addLine "END_PRIMITIVE"
						        addLine "BEGIN_PRIMITIVE $pcount"
							pcount="$[ $pcount + 1 ]"
							ptri="0"
						fi
						ptri="$[ $ptri + 1 ]"

 
				               echo -n "."
				        done
					echo
				       	addLine "END_PRIMITIVE"
				       	addLine "END_PATCH"
				       	addLine

				fi
			fi
		fi
                c_last="$c2"
                c2="$( GetNextTileY $c2 1 )"
        done
done
echo
if [ "$MASH_SCENARY" = "yes" ] ; then
	cnt="0"
	( while [ ! -z "${output[$cnt]}" ] ; do
	        echo "${output[$cnt]}"
	        cnt=$[ $cnt + 1 ]
	done ) >> "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file.txt"
fi


################################################################################################################################


dim_x="7"
dim_y="7"
tot="${#split_tile[@]}"
split_index="1"
if [ ! -z "${split_tile[0]}" ] ; then
	echo "Inserting removed images..."

fi
# Decomend to avoid insert image
# split_tile=()


for cursor in ${split_tile[@]} ; do
	cnt="0"
	prog="0"
	cursor_tmp=$cursor"qqq"
        info=( $( GetCoordinatesFromAddress $cursor_tmp ) )     
        point_lon="${info[2]}"
        point_lat="${info[3]}"
	dfs_file="mariocavicchi"
	dfs_dir="$( getDirName "$point_lat" "$point_lon" )"


	info_big=( $( echo "${CROSSED_TILE[@]}" | tr  " " "\n" | grep "^$cursor" | awk -F_ {'print $2" "$3'} ) )
	info_big_UL="${info_big[0]}"
	info_big_UL_lon="${info_big_UL%,*}"
	info_big_UL_lat="${info_big_UL#*,}" 

	info_big_LR="${info_big[1]}"
	info_big_LR_lon="${info_big_LR%,*}"
	info_big_LR_lat="${info_big_LR#*,}" 


	x_after=""
	y_after=""
	output_index="0"
	output=()


	for x in $( seq 0 $dim_x ) ; do

	        c2="$cursor_tmp"
	        cursor_tmp="$( GetNextTileX $cursor_tmp 1 )"

	        for y in $( seq 0 $dim_y  ) ; do

			info=( $( GetCoordinatesFromAddress $c2 ) )	
			point_lon="${info[0]}"
			point_lat="${info[1]}"

			[ -z "$( echo "${point_lon%.*}" | tr -d "-" )" ] && point_lon="$( echo "$point_lon" | sed -e s/"\."/"0\."/g )" 
			[ -z "$( echo "${point_lat%.*}" | tr -d "-" )" ] && point_lat="$( echo "$point_lat" | sed -e s/"\."/"0\."/g )" 

			if [ "$x" = "0" ] ; then

				if [ "$y" = "0" ] ; then
					if [ ! -z "$info_big_UL_lon" ] && [ ! -z "$info_big_UL_lat" ] ; then
						ori_ul_lon="$info_big_UL_lon"
						ori_ul_lat="$info_big_UL_lat"
					else
						ori_ul_lon="$( echo "scale = 8; ${info[2]} + $lon_fix" | bc -l )"
						ori_ul_lat="$( echo "scale = 8; ${info[3]} + $lat_fix" | bc -l )"
					fi
				else
					ori_ul_lon="$ori_ul_lon"
					ori_ul_lat="$ori_lr_lat"
				fi
			else
				if [ "$y" = "0" ] ; then
					ori_ul_lon="$ori_lr_lon"
					ori_ul_lat="$zero_line_lat"
	
				else
					ori_ul_lon="$ori_ul_lon"
					ori_ul_lat="$ori_lr_lat"
				fi
			fi
			[ "$y" = "0" ] && zero_line_lat="$ori_ul_lat"




			if [ "$x" != "$dim_x" ]	; then
				ori_lr_lon="$( echo "scale = 8; ${info[4]} + $lon_fix" | bc -l )"
			else
				if [ ! -z "$info_big_LR_lon" ] ; then
					ori_lr_lon="$info_big_LR_lon"
				else
					ori_lr_lon="$( echo "scale = 8; ${info[4]} + $lon_fix" | bc -l )"
				fi
			fi


			if [ "$y" != "$dim_y" ]	; then
				ori_lr_lat="$( echo "scale = 8; ${info[5]} + $lat_fix" | bc -l )"
			else
				if [ ! -z "$info_big_LR_lat" ] ; then
					ori_lr_lat="$info_big_LR_lat"
				else
					ori_lr_lat="$( echo "scale = 8; ${info[5]} + $lat_fix" | bc -l )"
				fi
			fi

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

			if [ -f "$tiles_dir/tile-$c2.png" ] ; then
				POL_FILE="poly_${point_lat}_${point_lon}.pol"
				TEXTURE="img_${point_lat}_${point_lon}.dds"
				TER="ter_${point_lat}_${point_lon}.ter"

				LC_lat_center="$( echo "scale = 8; ( $ul_lat + $lr_lat ) / 2" | bc )"
				LC_lon_center="$( echo "scale = 8; ( $ul_lon + $lr_lon ) / 2" | bc )"
				LC_dim="$( tile_size $c2 | awk -F. {'print $1'} )"
				LC_size="$( identify "$tiles_dir/tile-$c2.png" | awk {'print $3'} | awk -Fx {'print $1'} )"


				if [ "$WATER_MASK" = "yes" ] ; then
					if  [ ! -f "$tiles_dir/map-$c2.png" ] ; then
						upDateServer
						ewget "$tiles_dir/${TMPFILE}.png" "${server[1]}$( qrst2xyz "$c2" )" &> /dev/null
						if [ "$( du -k  "$tiles_dir/${TMPFILE}.png" | awk {'print $1'} )" != "0" ] ; then	
							echo
							echo -n "Tile analyze... "
							content="$( convert  "$tiles_dir/${TMPFILE}.png"   txt:- | grep -v "^#" | grep -vi "#99b3cc"  | wc -l )"
							if [  "$( echo "scale = 8; ( $content / (256*256) * 100 ) <= $MAX_PERC_COVER" | bc )" = 1 ] ; then
								echo -n ""  >  "$tiles_dir/map-$c2.png"	
							else
								convert -fuzz 8% "$tiles_dir/${TMPFILE}.png" -format PNG32 -transparent "#99b3cc" -filter Point  "$tiles_dir/map-$c2.png"
							fi
							echo -n "Done"
							rm -f "$tiles_dir/${TMPFILE}.png"
						else
							echo "Problem with Water Mask! Excessive zoom or unexisting map for this zone..."
							echo -n ""  >  "$tiles_dir/map-$c2.png"
							rm -f "$tiles_dir/${TMPFILE}.png"

						fi
				               	for i in $( seq $SLEEP_TIME ) ; do
							echo -n "."
				               	        sleep 1
				               	done
					fi
					if [ "$( du -k  "$tiles_dir/map-$c2.png" | awk {'print $1'} )" != "0" ] ; then
						convert  -layers mosaic "$tiles_dir/tile-$c2.png"  -format PNG32 -background transparent "$tiles_dir/tile-ww-$c2.png"
						composite -compose Dst_In "$tiles_dir/map-$c2.png" "$tiles_dir/tile-ww-$c2.png" "$tiles_dir/${TMPFILE}.png"
						rm -f "$tiles_dir/tile-ww-$c2.png"
						convert "$tiles_dir/${TMPFILE}.png" -format PNG32 -transparent "#000000" "$tiles_dir/tile-$c2.png"
						rm -f "$tiles_dir/${TMPFILE}.jpg"
						
					else
						cp -f "$( dirname -- "$0" )/ext_app/images/trans.png" "$tiles_dir/tile-$c2.png"
					fi
				fi


				[ "$MASH_SCENARY" = "yes" ] && TARGET_IMG_DIR="$TER_DIR"
				[ "$MASH_SCENARY" = "no"  ] && TARGET_IMG_DIR="$output_dir"

				[ -f "$TARGET_IMG_DIR/$TEXTURE" ] && [ ! -f "$tiles_dir/tile-$c2.dds" ] && cp -f "$TARGET_IMG_DIR/$TEXTURE" "$tiles_dir/tile-$c2.dds"

			        if [ ! -f "$TARGET_IMG_DIR/$TEXTURE" ] ; then
					if [ ! -f "$tiles_dir/tile-$c2.dds" ] ; then
						if [ "$( uname -s )" = "Linux" ] ; then
							wine "$ddstool" --png2dxt "$tiles_dir/tile-$c2.png" "$TARGET_IMG_DIR/$TEXTURE"
						else
							"$ddstool" --png2dxt "$tiles_dir/tile-$c2.png" "$TARGET_IMG_DIR/$TEXTURE"
						fi
						cp -f "$TARGET_IMG_DIR/$TEXTURE" "$tiles_dir/tile-$c2.dds"
					else
						cp -f "$tiles_dir/tile-$c2.dds" "$TARGET_IMG_DIR/$TEXTURE"
					fi
			        fi


				if [ "$MASH_SCENARY" = "yes" ] ; then
					if [ ! -f "$TER_DIR/$TER" ] ; then
					        echo "A"                           					>  "$TER_DIR/$TER"
				                echo "800"                              				>> "$TER_DIR/$TER"
				                echo "TERRAIN"                          				>> "$TER_DIR/$TER"
				                echo                                    				>> "$TER_DIR/$TER"
				                echo "BASE_TEX_NOWRAP $TEXTURE"         				>> "$TER_DIR/$TER"
						echo "LOAD_CENTER $LC_lat_center $LC_lon_center $LC_dim $LC_size"	>> "$TER_DIR/$TER"
				       fi
				fi



				if  [ "$dfs_file" != "$( getDSFName "$ori_ul_lat" "$ori_ul_lon" )" ] ; then

					if [ "$MASH_SCENARY" = "yes" ] ; then
						if [ "$output_index" != "0" ] && [ -f  "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file.txt" ]; then
							j="0"
							echo "Unload buffer for file $dfs_file..."
							( while [ "$j" != "$output_index" ] ; do                                                                                                                                          
	
							        echo "${output[$j]}"
							        j=$[ $j + 1 ]
						
							done ) >>  "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file.txt"
							output_index="0"
							output=()
						fi
					fi


					dfs_dir="$( getDirName "$ori_ul_lat" "$ori_ul_lon" )"

					if [ ! -d "$output_dir/$output_sub_dir/$dfs_dir" ] ; then
						echo "Creating DSF directory \"$dfs_dir\"...                                             "
						mkdir "$output_dir/$output_sub_dir/$dfs_dir"
					fi
	
					dfs_file="$( getDSFName "$ori_ul_lat" "$ori_ul_lon" )"
					dfs_list[$dfs_index]="$dfs_dir/$dfs_file"
					if [ "$MASH_SCENARY" = "yes" ] ; then
						dfs_tri_count="$dfs_index"	
						dfs_triangle[$dfs_tri_count]=""
					fi
					dfs_index=$[ $dfs_index + 1 ]

					[ "$( echo "$ori_ul_lat < 0" | bc )" = 1  ] && \
						max_lat="$( echo "$ori_ul_lat"	   | bc | awk -F. {'print $1'} )" && \
						min_lat="$( echo "$ori_ul_lat - 1" | bc | awk -F. {'print $1'} )"

					[ "$( echo "$ori_ul_lat > 0" | bc )" = 1  ] && 
						max_lat="$( echo "$ori_ul_lat + 1" | bc | awk -F. {'print $1'} )" && \
						min_lat="$( echo "$ori_ul_lat" 	   | bc | awk -F. {'print $1'} )"

					[ -z "$min_lat" 	] && min_lat="0"
					[ "$min_lat" = "-" 	] && min_lat="-0"
					[ -z "$max_lat" 	] && max_lat="0"
					[ "$max_lat" = "-" 	] && max_lat="-0"
	
					[ "$( echo "$ori_ul_lon < 0" | bc )" = 1  ] && \
						max_lon="$( echo "$ori_ul_lon" 	   | bc | awk -F. {'print $1'} )" && \
						min_lon="$( echo "$ori_ul_lon - 1" | bc | awk -F. {'print $1'} )"

					[ "$( echo "$ori_ul_lon > 0" | bc )" = 1  ] && 
						max_lon="$( echo "$ori_ul_lon + 1" | bc | awk -F. {'print $1'} )" && \
						min_lon="$( echo "$ori_ul_lon" 	   | bc | awk -F. {'print $1'} )"

					[ -z "$min_lon" 	] && min_lon="0"
					[ "$min_lon" = "-" 	] && min_lon="-0"
					[ -z "$max_lon" 	] && max_lon="0"
					[ "$max_lon" = "-" 	] && max_lon="-0"
	
					if [ ! -f "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file.txt" ] ; then
						cnt="0"
						echo "Creating file $dfs_file....                                                    "
				


						echo "A" 							>  "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file".txt 
						#echo "800" 							>> "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file".txt 
						echo "$XPLANE_CMD_VERSION" 					>> "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file".txt 
						echo "DSF2TEXT" 						>> "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file".txt 

						echo "PROPERTY sim/creation_agent $( basename -- "$0" )"	>> "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file".txt 
						echo "PROPERTY sim/planet earth" 				>> "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file".txt 
	
						[ "$MASH_SCENARY" = "no" ] && echo "PROPERTY sim/overlay 1" 	>> "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file".txt

						echo "PROPERTY sim/west $min_lon" 				>> "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file".txt 
						echo "PROPERTY sim/east $max_lon" 				>> "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file".txt 
						echo "PROPERTY sim/north $max_lat" 				>> "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file".txt 
						echo "PROPERTY sim/south $min_lat" 				>> "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file".txt 
						echo 								>> "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file".txt

						[ "$MASH_SCENARY" = "yes" ] && echo "TERRAIN_DEF terrain_Water" >> "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file".txt 
						echo 								>> "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file".txt

					else

						[ "$MASH_SCENARY" = "no"  ] && cnt="$( cat "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file.txt" | grep "BEGIN_POLYGON" | tail -n 1 | awk {'print $2'} )"
						[ "$MASH_SCENARY" = "yes" ] && cnt="$( cat "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file.txt" | grep "TERRAIN_DEF"   | grep -v "terrain_Water" | wc -l | awk {'print $1'} )"
						cnt=$[ $cnt + 1 ]	

					fi

				else
					[ "$MASH_SCENARY" = "no"  ] && cnt="$( cat "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file.txt" | grep "BEGIN_POLYGON" | tail -n 1 | awk {'print $2'} )"
					[ "$MASH_SCENARY" = "yes" ] && cnt="$( cat "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file.txt" | grep "TERRAIN_DEF"   | grep -v "terrain_Water" | wc -l | awk {'print $1'} )"
					cnt=$[ $cnt + 1 ]	
				fi

				if [ "$MASH_SCENARY" = "yes" ] ; then
					last_ter="$( cat "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file.txt" | grep "TERRAIN_DEF" | tail -n 1 | sed -e s/"\/"/":"/g )"
					if [ -z "$last_ter" ] ; then
						echo  "TERRAIN_DEF $( basename -- "$TER_DIR" )/$TER" >>  "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file.txt"
					else
						tmp_content="$( cat  "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file.txt" | sed -e s/"\/"/":"/g  )"

						 [ "$( uname -s )" = "Linux" ]   && echo "$tmp_content" | sed -e s/"$last_ter"/"$last_ter\nTERRAIN_DEF $( basename -- "$TER_DIR" ):$TER\n"/g | sed -e s/":"/"\/"/g > "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file.txt"
						 [ "$( uname -s )" = "Darwin" ]  && echo "$tmp_content" | sed -e s/"$last_ter"/"$last_ter;TERRAIN_DEF $( basename -- "$TER_DIR" ):$TER;"/g | sed -e s/":"/"\/"/g | tr ";" "\n" > "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file.txt"

						unset tmp_content

					fi
				fi

				

				[ -z "$( echo "${ul_lat%.*}" | tr -d "-" )" ] && ul_lat="$( echo "$ul_lat" | sed -e s/"\."/"0\."/g )" 
				[ -z "$( echo "${ul_lon%.*}" | tr -d "-" )" ] && ul_lon="$( echo "$ul_lon" | sed -e s/"\."/"0\."/g )" 

				[ -z "$( echo "${ur_lat%.*}" | tr -d "-" )" ] && ur_lat="$( echo "$ur_lat" | sed -e s/"\."/"0\."/g )" 
				[ -z "$( echo "${ur_lon%.*}" | tr -d "-" )" ] && ur_lon="$( echo "$ur_lon" | sed -e s/"\."/"0\."/g )" 

				[ -z "$( echo "${lr_lat%.*}" | tr -d "-" )" ] && lr_lat="$( echo "$lr_lat" | sed -e s/"\."/"0\."/g )" 
				[ -z "$( echo "${lr_lon%.*}" | tr -d "-" )" ] && lr_lon="$( echo "$lr_lon" | sed -e s/"\."/"0\."/g )" 

				[ -z "$( echo "${ll_lat%.*}" | tr -d "-" )" ] && ll_lat="$( echo "$ll_lat" | sed -e s/"\."/"0\."/g )" 
				[ -z "$( echo "${ll_lon%.*}" | tr -d "-" )" ] && ll_lon="$( echo "$ll_lon" | sed -e s/"\."/"0\."/g )" 



				skip_check="no"
				if [ "$( echo "scale = 8; ( $y <= $dim_y ) && ( $ul_lat < 0 ) && ( $lr_lat < 0 )" | bc  )" = "1" ] ; then
					y_next_info=( $( GetCoordinatesFromAddress $( GetNextTileY $c2 1 ) ) )
		                        next_ul_lon="$( echo "scale = 8; ${y_next_info[2]} + $lon_fix" | bc -l )"
		                        next_ul_lat="$( echo "scale = 8; ${y_next_info[3]} + $lat_fix" | bc -l )"
		                        next_lr_lon="$( echo "scale = 8; ${y_next_info[4]} + $lon_fix" | bc -l )"
		                        next_lr_lat="$( echo "scale = 8; ${y_next_info[5]} + $lat_fix" | bc -l )"
					if [ "$[ ${next_lr_lat%.*} + 1  ]" = "${next_ul_lat%.*}" ] ; then
						ll_lat="$min_lat.00000000"
						lr_lat="$min_lat.00000000"
						skip_check="yes"
					fi
				fi



				if [ "$[ ${lr_lat%.*} + 1  ]" = "${ul_lat%.*}" ] ; then
					if [ "$skip_check" = "no" ] ; then					
						[ "$( echo "scale = 8; ( $ul_lat > $max_lat )" | bc  )" = "1" ] && ul_lat="$max_lat.00000000" 
						[ "$( echo "scale = 8; ( $ur_lat > $max_lat )" | bc  )" = "1" ] && ur_lat="$max_lat.00000000" 
					
						[ "$( echo "scale = 8; ( $lr_lat < $min_lat )" | bc  )" = "1" ] && lr_lat="$min_lat.00000000" 
						[ "$( echo "scale = 8; ( $ll_lat < $min_lat )" | bc  )" = "1" ] && ll_lat="$min_lat.00000000"
					fi
					y_after="$[ $y + 1 ]"
				fi


				skip_check="no"
				if [ "$( echo "scale = 8; ( $x <= $dim_x) && ( $ul_lon < 0 ) && ( $lr_lon < 0 )" | bc  )" = "1" ] ; then
					if [ "$[ ${ul_lon%.*} + 1  ]" = "${lr_lon%.*}" ] ; then
						ur_lon="$max_lon.00000000"
						lr_lon="$max_lon.00000000"

						skip_check="yes"
						x_after="$[ $x + 1 ]"
					fi
				fi


				if [ "$[ ${ul_lon%.*} + 1  ]" = "${lr_lon%.*}" ] ; then
					if [ "$skip_check" = "no" ] ; then
						[ "$( echo "scale = 8; ( $ul_lon < $min_lon )" | bc  )" = "1" ] && ul_lon="$min_lon.00000000" 
						[ "$( echo "scale = 8; ( $ll_lon < $min_lon )" | bc  )" = "1" ] && ll_lon="$min_lon.00000000" 


						[ "$( echo "scale = 8; ( $ur_lon > $max_lon )" | bc  )" = "1" ] && ur_lon="$max_lon.00000000"
						[ "$( echo "scale = 8; ( $lr_lon > $max_lon )" | bc  )" = "1" ] && lr_lon="$max_lon.00000000" 
					fi
					x_after="$[ $x + 1 ]"
				fi 

				if [ "$y_after" = "$y" ] ; then
					ul_lat="$max_lat.00000000" 
					ur_lat="$max_lat.00000000" 
					y_after=""
				fi
				if [ "$x_after" = "$x" ] ; then
					ul_lon="$min_lon.00000000"
					ll_lon="$min_lon.00000000"
					x_after="$x"
				fi

				[ "$MASH_SCENARY" = "no" ] && createKMLoutput ADD  "$KML_FILE" "$TEXTURE" $ul_lat $lr_lat $lr_lon $ul_lon 
				


				if [ "$MASH_SCENARY" = "no" ] ; then
					echo -ne "$prog / $split_index / $tot: Create polygon (.pol) file \"$POL_FILE\"...                          \r"
		
					if [ -f "$output_dir/$POL_FILE" ] ; then
						echo "Error! Polygon file already exists!"
						exit 3
					fi

					echo "A"								>  "$output_dir/$POL_FILE"
					echo "850"								>> "$output_dir/$POL_FILE"
					echo "DRAPED_POLYGON"							>> "$output_dir/$POL_FILE"
					echo 									>> "$output_dir/$POL_FILE"
					echo "LAYER_GROUP airports -1"						>> "$output_dir/$POL_FILE"
					echo "TEXTURE_NOWRAP $TEXTURE"						>> "$output_dir/$POL_FILE"
					echo "SCALE 25 25"							>> "$output_dir/$POL_FILE"
					echo "LOAD_CENTER $LC_lat_center $LC_lon_center $LC_dim $LC_size"       >> "$output_dir/$POL_FILE"	


					################################

					# create dsf file ....
					echo "POLYGON_DEF $POL_FILE"				>> "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file".txt
					echo "BEGIN_POLYGON $cnt 65535 4"			>> "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file".txt
					echo "BEGIN_WINDING"					>> "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file".txt
					echo "POLYGON_POINT $lr_lon	$lr_lat		1 0"	>> "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file".txt
					echo "POLYGON_POINT $ur_lon	$ur_lat		1 1"	>> "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file".txt
					echo "POLYGON_POINT $ul_lon	$ul_lat		0 1"	>> "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file".txt
					echo "POLYGON_POINT $ll_lon	$ll_lat		0 0"	>> "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file".txt
					echo "END_WINDING"					>> "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file".txt
					echo "END_POLYGON"					>> "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file".txt
					echo  							>> "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file".txt
					################################
				fi


				if [ "$MASH_SCENARY" = "yes" ] ; then
		
				
					mesh_level="0"
				        mesh=""
				        new_vertex=""
					POINTS=( "${lr_lon},${lr_lat}_1.00000000,0.00000000" "${ur_lon},${ur_lat}_1.00000000,1.00000000" "${ul_lon},${ul_lat}_0.00000000,1.00000000" "${ll_lon},${ll_lat}_0.00000000,0.00000000" )
				       	if [ "${#POINTS[@]}" != "4" ] ; then
	                			echo "ERROR: POINTS corrupted..."
				                exit 5

				        fi



				        vertex="$( echo "${POINTS[@]}"  | tr " " ";" )"
				        echo -n "$prog / $split_index / $tot Create mash "
					MESH_LEVEL_SUB="$[ $MESH_LEVEL - 2 ]"
					[ "$( echo "scale = 8; ( $MESH_LEVEL_SUB < 0 )" | bc  )" = "1" ] && MESH_LEVEL_SUB="0"

					md5mesh="$( echo "$MESH_LEVEL_SUB ${POINTS[@]}" | md5sum | awk {'print $1'} )"
					mesh_file="$tiles_dir/$md5mesh.msh"	
					if [ -f  "$mesh_file" ] ; then
						mesh_tmp=( $( cat "$mesh_file" ) )
						if [ "$( echo "scale = 8; ${#mesh_tmp[@]} == (4^$MESH_LEVEL_SUB)" | bc  )" != "1" ] ; then
							rm -f "$mesh_file"
						else
							echo -n "from cache..."
							mesh="${mesh_tmp[@]}"
						fi
									
					fi


					if [ ! -f  "$mesh_file" ] ; then	
						if [ "$MESH_LEVEL_SUB" = "0" ] ; then
							mesh="${lr_lon},${lr_lat},1.00000000,0.00000000;${ur_lon},${ur_lat},1.00000000,1.00000000;${ul_lon},${ul_lat},0.00000000,1.00000000;${ll_lon},${ll_lat},0.00000000,0.00000000;"
						else
						        while [ "$mesh_level" != "$MESH_LEVEL_SUB" ] ; do
								echo -n "$mesh_level"
						                for square in $vertex ; do
					        	                POINTS=( $( echo "$square" | tr ";" " " ) )
			                			        new_vertex="$new_vertex $( divideSquare ${POINTS[0]} ${POINTS[1]} ${POINTS[2]} ${POINTS[3]} )"
					                	        echo -n "."
					                	done
					                	vertex="$new_vertex"
								new_vertex=""
					                	mesh_level="$[ $mesh_level + 1 ]"		
						        done
						        mesh="$vertex"
							echo -n "$mesh" > "$mesh_file"
						fi
					fi


					FINAL_TRIANGLES[$index_triangle]="$( echo "$mesh" | tr " " "#" )"
					dfs_triangle[$dfs_tri_count]="${dfs_triangle[$dfs_tri_count]} $index_triangle"
					index_triangle="$[ $index_triangle + 1 ]"

					echo -n " Creating triangles "

					addLine
				        addLine "BEGIN_PATCH 0   0.0 -1.0    1   5"
				        addLine "BEGIN_PRIMITIVE 0"
					pcount="1"
					ptri="0"
				        for square in $mesh ; do
				                vertex=( $( echo "$square" | tr ";" " " ) )

				                vertex[0]="$( echo "${vertex[0]}" | tr "_" " " | tr "," "\t" )"
				                vertex[1]="$( echo "${vertex[1]}" | tr "_" " " | tr "," "\t" )"
				                vertex[2]="$( echo "${vertex[2]}" | tr "_" " " | tr "," "\t" )"
				                vertex[3]="$( echo "${vertex[3]}" | tr "_" " " | tr "," "\t" )"

				                # fetch coordinates
				                COORD[0]="$( echo "${vertex[0]}" | awk {'print $1" "$2'} )"
				                COORD[1]="$( echo "${vertex[1]}" | awk {'print $1" "$2'} )"
				                COORD[2]="$( echo "${vertex[2]}" | awk {'print $1" "$2'} )"
				                COORD[3]="$( echo "${vertex[3]}" | awk {'print $1" "$2'} )"     

				                # Search altitude
				                ALT[0]="$( getAltitude ${COORD[0]} )"
				                ALT[1]="$( getAltitude ${COORD[1]} )"
				                ALT[2]="$( getAltitude ${COORD[2]} )"
				                ALT[3]="$( getAltitude ${COORD[3]} )"

					
						createKMLoutput TRI "$KML_FILE" ${COORD[3]} ${COORD[1]} ${COORD[0]} 

	 			                addLine "PATCH_VERTEX ${COORD[3]} ${ALT[3]} 0 0"
				               	addLine "PATCH_VERTEX ${COORD[1]} ${ALT[1]} 0 0"
				                addLine "PATCH_VERTEX ${COORD[0]} ${ALT[0]} 0 0"
						if [ "$ptri" = "84" ] ; then
							addLine "END_PRIMITIVE"
						        addLine "BEGIN_PRIMITIVE $pcount"
							pcount="$[ $pcount + 1 ]"
							ptri="0"
						fi
						ptri="$[ $ptri + 1 ]"

						createKMLoutput TRI "$KML_FILE" ${COORD[3]} ${COORD[2]} ${COORD[1]}

				                addLine "PATCH_VERTEX ${COORD[3]} ${ALT[3]} 0 0"
				                addLine "PATCH_VERTEX ${COORD[2]} ${ALT[2]} 0 0"
				                addLine "PATCH_VERTEX ${COORD[1]} ${ALT[1]} 0 0"
						if [ "$ptri" = "84" ] ; then
							addLine "END_PRIMITIVE"
						        addLine "BEGIN_PRIMITIVE $pcount"
							pcount="$[ $pcount + 1 ]"
							ptri="0"
						fi
						ptri="$[ $ptri + 1 ]"

 
				               echo -n "."
				        done

				        addLine "END_PRIMITIVE"
				        addLine "END_PATCH"
				        addLine
					echo

				fi


				cnt=$[ $cnt + 1 ]
				prog=$[ $prog + 1 ]
			else
				[ "$MASH_SCENARY" = "no" ] && echo -ne "$prog / $split_index / $tot ...                                                              \r"

				if [ "$MASH_SCENARY" = "yes" ] ; then	
					if 	[ "$[ ${lr_lat%.*} + 1  ]" != "${ul_lat%.*}" ] 						&& \
						[ "$[ ${lr_lon%.*} + 1  ]" != "${ul_lon%.*}" ] 						&& \
						[ "$dfs_file" = "$( getDSFName "${lr_lat}" "${lr_lon}" )" ]				&& \
						[ "$dfs_file" = "$( getDSFName "${ur_lat}" "${ur_lon}" )" ]				&& \
						[ "$dfs_file" = "$( getDSFName "${ul_lat}" "${ul_lon}" )" ]				&& \
						[ "$dfs_file" = "$( getDSFName "${ll_lat}" "${ll_lon}" )" ]				&& \
						[ "$( echo "scale = 8; ( $ul_lat > 0 ) && ( $lr_lat < 0 ) " | bc -l )" != "1" ] 	&& \
						[ "$( echo "scale = 8; ( $lr_lon > 0 ) && ( $ul_lon < 0 ) " | bc -l )" != "1" ]	 ; then

						echo -n "$prog / $split_index / $tot Creating water mesCreating water meshh..."

						mesh_level="0"
					        mesh=""
					        new_vertex=""
						POINTS=( "${lr_lon},${lr_lat}_1.00000000,0.00000000" "${ur_lon},${ur_lat}_1.00000000,1.00000000" "${ul_lon},${ul_lat}_0.00000000,1.00000000" "${ll_lon},${ll_lat}_0.00000000,0.00000000" )
					       	if [ "${#POINTS[@]}" != "4" ] ; then
		                			echo "ERROR: POINTS corrupted..."
					                exit 5

					        fi

					        vertex="$( echo "${POINTS[@]}"  | tr " " ";" )"
						MESH_LEVEL_SUB="$[ $MESH_LEVEL - 2 ]"
						[ "$( echo "scale = 8; ( $MESH_LEVEL_SUB < 0 )" | bc  )" = "1" ] && MESH_LEVEL_SUB="0"

						md5mesh="$( echo "$MESH_LEVEL_SUB ${POINTS[@]}" | md5sum | awk {'print $1'} )"
						mesh_file="$tiles_dir/$md5mesh.msh"	
						if [ -f  "$mesh_file" ] ; then
							mesh_tmp=( $( cat "$mesh_file" ) )
							if [ "$( echo "scale = 8; ${#mesh_tmp[@]} == (4^$MESH_LEVEL_SUB)" | bc  )" != "1" ] ; then
								rm -f "$mesh_file"
							else
								echo -n "from cache..."
								mesh="${mesh_tmp[@]}"
							fi
									
						fi

						if [ ! -f  "$mesh_file" ] ; then	
							if [ "$MESH_LEVEL_SUB" = "0" ] ; then
								mesh="${lr_lon},${lr_lat},1.00000000,0.00000000;${ur_lon},${ur_lat},1.00000000,1.00000000;${ul_lon},${ul_lat},0.00000000,1.00000000;${ll_lon},${ll_lat},0.00000000,0.00000000;"
							else
							        while [ "$mesh_level" != "$MESH_LEVEL_SUB" ] ; do
									echo -n "$mesh_level"
							                for square in $vertex ; do
						        	                POINTS=( $( echo "$square" | tr ";" " " ) )
				                			        new_vertex="$new_vertex $( divideSquare ${POINTS[0]} ${POINTS[1]} ${POINTS[2]} ${POINTS[3]} )"
						                	        echo -n "."
						                	done
						                	vertex="$new_vertex"
									new_vertex=""
						                	mesh_level="$[ $mesh_level + 1 ]"		
							        done
							        mesh="$vertex"
								echo -n "$mesh" > "$mesh_file"
							fi
						fi


						echo -n " Create triangles "

						addLine
					        addLine "BEGIN_PATCH 0   0.0 -1.0    1   5"
					        addLine "BEGIN_PRIMITIVE 0"
						pcount="1"
						ptri="0"
					        for square in $mesh ; do
					                vertex=( $( echo "$square" | tr ";" " " ) )

					                vertex[0]="$( echo "${vertex[0]}" | tr "_" " " | tr "," "\t" )"
					                vertex[1]="$( echo "${vertex[1]}" | tr "_" " " | tr "," "\t" )"
					                vertex[2]="$( echo "${vertex[2]}" | tr "_" " " | tr "," "\t" )"
					                vertex[3]="$( echo "${vertex[3]}" | tr "_" " " | tr "," "\t" )"

					                # fetch coordinates
					                COORD[0]="$( echo "${vertex[0]}" | awk {'print $1" "$2'} )"
					                COORD[1]="$( echo "${vertex[1]}" | awk {'print $1" "$2'} )"
					                COORD[2]="$( echo "${vertex[2]}" | awk {'print $1" "$2'} )"
					                COORD[3]="$( echo "${vertex[3]}" | awk {'print $1" "$2'} )"     

					                # Search altitude
					                ALT[0]="$( getAltitude ${COORD[0]} )"
					                ALT[1]="$( getAltitude ${COORD[1]} )"
					                ALT[2]="$( getAltitude ${COORD[2]} )"
					                ALT[3]="$( getAltitude ${COORD[3]} )"

					
							createKMLoutput TRI "$KML_FILE" ${COORD[3]} ${COORD[1]} ${COORD[0]} 

		 			                addLine "PATCH_VERTEX ${COORD[3]} ${ALT[3]} 0 0"
					               	addLine "PATCH_VERTEX ${COORD[1]} ${ALT[1]} 0 0"
					                addLine "PATCH_VERTEX ${COORD[0]} ${ALT[0]} 0 0"
							if [ "$ptri" = "84" ] ; then
								addLine "END_PRIMITIVE"
							        addLine "BEGIN_PRIMITIVE $pcount"
								pcount="$[ $pcount + 1 ]"
								ptri="0"
							fi
							ptri="$[ $ptri + 1 ]"

							createKMLoutput TRI "$KML_FILE" ${COORD[3]} ${COORD[2]} ${COORD[1]}

					                addLine "PATCH_VERTEX ${COORD[3]} ${ALT[3]} 0 0"
					                addLine "PATCH_VERTEX ${COORD[2]} ${ALT[2]} 0 0"
					                addLine "PATCH_VERTEX ${COORD[1]} ${ALT[1]} 0 0"
							if [ "$ptri" = "84" ] ; then
								addLine "END_PRIMITIVE"
							        addLine "BEGIN_PRIMITIVE $pcount"
								pcount="$[ $pcount + 1 ]"
								ptri="0"
							fi
							ptri="$[ $ptri + 1 ]"

 
					               echo -n "."
					        done

					        addLine "END_PRIMITIVE"
					        addLine "END_PATCH"
					        addLine
						echo


					fi
				fi
			
			fi
	                c_last="$c2"
	                c2="$( GetNextTileY $c2 1 )"
	        done

	done
	if [ "$MASH_SCENARY" = "yes" ] ; then
		cnt="0"
		( while [ ! -z "${output[$cnt]}" ] ; do
		        echo "${output[$cnt]}"
		        cnt=$[ $cnt + 1 ]
		done ) >> "$output_dir/$output_sub_dir/$dfs_dir/$dfs_file.txt"

	fi
	split_index=$[ $split_index + 1 ]
done


################################################################################################################################



if [ "$MASH_SCENARY" = "yes" ] ; then

	j="0"
	while [ ! -z "${dfs_list[$j]}" ] ; do
		output_index="0"
		output=()

		echo "Filling mesh triangle for file ${dfs_list[$j]} ..."
		cnt="$( cat "$output_dir/$output_sub_dir/${dfs_list[$j]}.txt" | grep "BEGIN_PATCH" | tail -n 1 | awk {'print $2'} )"
		[ -z "$cnt" ] && cnt="0"
	

		tot=( ${dfs_triangle[$j]} )
		tot="$[ ${#tot[@]} + $cnt ]"
		for trix in ${dfs_triangle[$j]} ; do
			triangle="${FINAL_TRIANGLES[$trix]}"
		        addLine "BEGIN_PATCH $[ $cnt + 1 ]   0.0 -1.0     1 7"

		        addLine "BEGIN_PRIMITIVE 0"
		        mesh="$( echo "$triangle" | tr "#" " " )"
		        echo -n "$[ $cnt + 1 ] / $tot Create triangles "
			pcount="1"
			ptri="0"
		        for square in $mesh ; do

		                vertex=( $( echo "$square" | tr ";" " " ) )

		                vertex[0]="$( echo "${vertex[0]}" | tr "_" " " | tr "," "\t" )"
		                vertex[1]="$( echo "${vertex[1]}" | tr "_" " " | tr "," "\t" )"
		                vertex[2]="$( echo "${vertex[2]}" | tr "_" " " | tr "," "\t" )"
		                vertex[3]="$( echo "${vertex[3]}" | tr "_" " " | tr "," "\t" )"

		                # fetch coordinates
		                COORD[0]="$( echo "${vertex[0]}" | awk {'print $1" "$2'} )"
		                COORD[1]="$( echo "${vertex[1]}" | awk {'print $1" "$2'} )"
		                COORD[2]="$( echo "${vertex[2]}" | awk {'print $1" "$2'} )"
		                COORD[3]="$( echo "${vertex[3]}" | awk {'print $1" "$2'} )"     


        		        # Search altitude
        		        ALT[0]="$( getAltitude ${COORD[0]} )"
        		        ALT[1]="$( getAltitude ${COORD[1]} )"
        		        ALT[2]="$( getAltitude ${COORD[2]} )"
        		        ALT[3]="$( getAltitude ${COORD[3]} )"
	
	        	        # fetch position
	        	        POS[0]=$( echo "${vertex[0]}" | awk {'print $3" "$4'} )
	        	        POS[1]=$( echo "${vertex[1]}" | awk {'print $3" "$4'} )
	        	        POS[2]=$( echo "${vertex[2]}" | awk {'print $3" "$4'} )
	        	        POS[3]=$( echo "${vertex[3]}" | awk {'print $3" "$4'} )

	                	addLine "PATCH_VERTEX ${COORD[3]} ${ALT[3]} 0 0 ${POS[3]}"
	                	addLine "PATCH_VERTEX ${COORD[1]} ${ALT[1]} 0 0 ${POS[1]}"
	                	addLine "PATCH_VERTEX ${COORD[0]} ${ALT[0]} 0 0 ${POS[0]}"


				if [ "$ptri" = "84" ] ; then
					addLine "END_PRIMITIVE"
				        addLine "BEGIN_PRIMITIVE $pcount"
					pcount="$[ $pcount + 1 ]"
					ptri="0"
				fi
				ptri="$[ $ptri + 1 ]"



	                	addLine "PATCH_VERTEX ${COORD[3]} ${ALT[3]} 0 0 ${POS[3]}"
	                	addLine "PATCH_VERTEX ${COORD[2]} ${ALT[2]} 0 0 ${POS[2]}"
	                	addLine "PATCH_VERTEX ${COORD[1]} ${ALT[1]} 0 0 ${POS[1]}"
				if [ "$ptri" = "84" ] ; then
					addLine "END_PRIMITIVE"
				        addLine "BEGIN_PRIMITIVE $pcount"
					pcount="$[ $pcount + 1 ]"
					ptri="0"
				fi
				ptri="$[ $ptri + 1 ]"


		                echo -n "."
		        done
		        echo
		        cnt=$[ $cnt + 1 ]
		        addLine "END_PRIMITIVE"
		        addLine "END_PATCH"
		        addLine
		done
		echo

		cnt="0"
		( while [ ! -z "${output[$cnt]}" ] ; do
		        echo "${output[$cnt]}"
		        cnt=$[ $cnt + 1 ]
		done ) >> "$output_dir/$output_sub_dir/${dfs_list[$j]}.txt" 
		j=$[ $j + 1 ]
	done

fi




createKMLoutput END  "$KML_FILE"  #&& exit

# Sorting DSF file and remove the duplicate
dfs_list=( $( echo "${dfs_list[@]}" | tr " " "\n" | sort -u | tr "\n" " " ) )

#########################################################################3

if [ "$OSM" = "yes" ] ; then
	echo
	echo "Adding roads from OpenStreetMap..."

	#BASE_URL="http://xapi.openstreetmap.org/api/0.5"
	#BASE_URL="http://www.informationfreeway.org/api/0.6"
	BASE_URL="http://api.openstreetmap.org/api/0.6" # /map?bbox=11.54,48.14,11.543,48.145"

# ROAD DEFINITION

ROAD_TYPE="
railway-rail            56
highway-residential     13
highway-secondary       44
highway-tertiary        47
highway-trunk		13
highway-unclassified    51
highway-trunk_link	50
highway-motorway_link	50
highway-service		47
highway-motorway	1
"
# To define:
# highway-primary

	osm_left="$( 	echo "scale = 8; $osm_center_lon 	- 0.05" | bc | awk '{ printf "%0.4f\n", $1 }' )"
	osm_right="$(	echo "scale = 8; $osm_center_lon 	+ 0.05" | bc | awk '{ printf "%0.4f\n", $1 }' )"

	osm_bottom="$(	echo "scale = 8; $osm_center_lat        - 0.05" | bc | awk '{ printf "%0.4f\n", $1 }' )"
	osm_top="$( 	echo "scale = 8; $osm_center_lat        + 0.05" | bc | awk '{ printf "%0.4f\n", $1 }' )"

	QUERY_URL="${BASE_URL}/map?bbox=$osm_left,$osm_bottom,$osm_right,$osm_top"
	md5road="$( echo "$osm_left,$osm_bottom,$osm_right,$osm_top" | md5sum | awk {'print $1'} )"
	road_file="$tiles_dir/$md5road.osm"	

	[ -f "$road_file" ] && [ "$( du -k  "$road_file" | awk {'print $1'} )" = "0" ] && rm -f "$road_file"

	if [ ! -f "$road_file" ] ; then
		echo "Download roads information..."
		echo "$QUERY_URL"
		wget --user-agent=Firefox -O "$road_file" "$QUERY_URL"
		echo "Store road in file $road_file ..."
	fi


	echo "Load road file $road_file ..."
	XML_OUTPUT="$( cat "$road_file" | tr "\"" "\'"  )"

	echo "Get ways list..." 
	WAYS_START=( $( echo "$XML_OUTPUT" | grep -n "<way id=" | awk -F:  {'print $1'} | tr "\n" " " ) )
	WAYS_END=(   $( echo "$XML_OUTPUT" | grep -n "</way>"   | awk -F:  {'print $1'} | tr "\n" " " ) )
	echo "Found ${#WAYS_START[@]} ways ..."

	echo "Get nodes list..."
	NODES="$(       echo "$XML_OUTPUT" | grep "node id="    | awk -F\' '{ printf "%020d %f %f\n", $2, $4, $6 }' )"

	for f in ${dfs_list[@]} ; do
		[ "$MASH_SCENARY" = "no"  ] && begin="$( cat "$output_dir/$output_sub_dir/${f}.txt" | grep "BEGIN_POLYGON" | tail -n 1 | awk {'print $2'} )"
	        [ "$MASH_SCENARY" = "yes" ] && begin="$( cat "$output_dir/$output_sub_dir/${f}.txt" | grep "TERRAIN_DEF"   | grep -v "terrain_Water" | wc -l | awk {'print $1'} )"

		begin="$[ $begin + 1 ]"

		dsf_cont="$( cat "$output_dir/$output_sub_dir/${f}.txt" | sed -e s/"\/"/":"/g )"

		# PROPERTY sim/exclude_net 13.000/40.000/14.000/41.000
		k="0"
		for coord in west south east north ; do
			val[$k]="$( echo "$dsf_cont" | grep "PROPERTY sim:$coord"  | awk {'print $3'}).000"
			k=$[ $k + 1 ]
		done
		exclude_string="PROPERTY sim:exclude_net $( echo "${val[@]}" | tr " " ":" )"

		[ "$( uname -s )" = "Linux" ]   && dsf_cont="$( echo "$dsf_cont" | sed -e s/"PROPERTY sim:creation_agent $( basename -- "$0" )"/"PROPERTY sim:creation_agent\n$exclude_string\n"/g )"
		[ "$( uname -s )" = "Darwin" ]  && dsf_cont="$( echo "$dsf_cont" | sed -e s/"PROPERTY sim:creation_agent $( basename -- "$0" )"/"PROPERTY sim:creation_agent;$exclude_string;"/g )"


		# NETWORK_DEF lib/g8/roads.net
		if [ "$MASH_SCENARY" = "yes" ] ; then
			last_ter="$( echo "$dsf_cont" | grep "TERRAIN_DEF" | tail -n 1 | sed -e s/"\/"/":"/g )"
			[ "$( uname -s )" = "Linux" ]   && echo "$dsf_cont" | sed -e s/"$last_ter"/"$last_ter\nNETWORK_DEF lib:g8:roads.net\n"/g 	| sed -e s/":"/"\/"/g 			> "$output_dir/$output_sub_dir/${f}.txt"
			[ "$( uname -s )" = "Darwin" ]  && echo "$dsf_cont" | sed -e s/"$last_ter"/"$last_ter;NETWORK_DEF lib:g8:roads.net;"/g 		| sed -e s/":"/"\/"/g | tr ";" "\n" 	> "$output_dir/$output_sub_dir/${f}.txt"
		fi
		if [ "$MASH_SCENARY" = "no" ] ; then
			first_pol="$( echo "$dsf_cont" | grep "POLYGON_DEF" | head -n 1 | sed -e s/"\/"/":"/g )"
			[ "$( uname -s )" = "Linux" ]   && echo "$dsf_cont" | sed -e s/"$first_pol"/"NETWORK_DEF lib:g8:roads.net\n$first_pol\n"/g 	| sed -e s/":"/"\/"/g 			> "$output_dir/$output_sub_dir/${f}.txt"
			[ "$( uname -s )" = "Darwin" ]  && echo "$dsf_cont" | sed -e s/"$first_pol"/"NETWORK_DEF lib:g8:roads.net;$first_pol;"/g 	| sed -e s/":"/"\/"/g | tr ";" "\n" 	> "$output_dir/$output_sub_dir/${f}.txt"
		fi
		unset dsf_cont


		i="0"
		while [ ! -z "${WAYS_START[$i]}" ]  ; do

			way_file="$tiles_dir/$md5road-${WAYS_START[$i]}-${WAYS_END[$i]}.osm"     
			if [ ! -f "$way_file" ] ; then
				CONTENT="$( echo "$XML_OUTPUT"  | head -n "${WAYS_END[$i]}" | tail -n $[ ${WAYS_END[$i]} - ${WAYS_START[$i]} + 1 ] )" 
				echo "$CONTENT" > "$way_file"
			else
				CONTENT="$( cat "$way_file" )"
			fi

			TAG_KEY=( $(    echo "$CONTENT" | grep "<tag k=" | tr -d " "  | awk -F\' {'print $2'} | tr "\n" " " ) )
			TAG_VALUE=( $(  echo "$CONTENT" | grep "<tag k=" | tr -d " "  | awk -F\' {'print $4'} | tr "\n" " " ) )
	
			s="$( echo "${TAG_KEY[@]}" | tr " " "\n"  | grep -ni "highway" | awk -F: {'print $1'} )" 
			[ -z "$s" ] && s="$( echo "${TAG_KEY[@]}" | tr " " "\n"  | grep -ni "railway" | awk -F: {'print $1'} )" 


			if [ -z "$s" ] ; then
			        echo "Not highway or railway, skip..."
			        i="$[ $i + 1 ]"
			        continue
			fi
			s="$[ $s  - 1 ]" 


			[ "${TAG_KEY[$s]}-${TAG_VALUE[$s]}" = "highway-footway" ] 	&& echo "$i - highway-footway skip..." && i="$[ $i + 1 ]" 	&& continue
			[ "${TAG_KEY[$s]}-${TAG_VALUE[$s]}" = "highway-pedestrian" ] 	&& echo "$i - highway-pedestrian skip..." && i="$[ $i + 1 ]" 	&& continue


			rtype="$( echo "$ROAD_TYPE" | awk {'print $1"- "$2'} | grep "^${TAG_KEY[$s]}-${TAG_VALUE[$s]}-" | awk {'print $2'} )"

			if [ -z "$rtype" ] ; then
			        echo "Road ${TAG_KEY[$s]}-${TAG_VALUE[$s]} unknown"
				i="$[ $i + 1 ]"
				continue
			        #exit
			fi
			echo -n "$i - Add ${TAG_KEY[$s]}-${TAG_VALUE[$s]} "

			REF="$(     echo "$CONTENT"     | grep "<nd ref=" | awk -F\' '{ printf "%020d\n", $2 }' | tr "\n" " " )"

			cnt="0"
			WAY=()
			ALT=()
			for r in $REF ; do
			        echo -n "." 
			        WAY[$cnt]="$( echo "$NODES" | grep "^$r" | awk '{ printf "%.7f %.7f", $3, $2 }')"
				ori_lat="$( echo "${WAY[$cnt]}" | awk {'print $2'} )"
				ori_lon="$( echo "${WAY[$cnt]}" | awk {'print $1'} )"

				ori_lat="$( echo "scale = 8; $ori_lat + $lat_fix" | bc -l )"	
				ori_lon="$( echo "scale = 8; $ori_lon + $lon_fix" | bc -l )"


				if [ "$rot_fix" = "0" ] ; then
					lat="$ori_lat"
					lon="$ori_lon"
				else
					# With rotation...
					lat="$( echo "scale = 8; $ori_lat - $lat_plane" | bc -l )"
					lon="$( echo "scale = 8; $ori_lon - $lon_plane" | bc -l )"
					lon="$( echo "scale = 8; $lon * c( ($pi/180) * $rot_fix ) - $lat * s( ($pi/180) * $rot_fix )" | bc -l )"
					lat="$( echo "scale = 8; $lon * s( ($pi/180) * $rot_fix ) + $lat * c( ($pi/180) * $rot_fix )" | bc -l )"
					lat="$( echo "scale = 8; $lat + $lat_plane" | bc -l )"
					lon="$( echo "scale = 8; $lon + $lon_plane" | bc -l )"

				fi
				lat="$( echo "$lat" | awk '{ printf "%.8f", $1 }')"
				lon="$( echo "$lon" | awk '{ printf "%.8f", $1 }')"
				
				[ "$( echo "scale = 6; ( ( $lon < ${val[0]} ) || ( $lon > ${val[2]} ) )" | bc )" = "1" ] && continue
				[ "$( echo "scale = 6; ( ( $lat < ${val[1]} ) || ( $lat > ${val[3]} ) )" | bc )" = "1" ] && continue

				WAY[$cnt]="$lon $lat"	
				ALT[$cnt]="$( echo "scale = 8; $( getAltitude ${WAY[$cnt]} ) + 1" | bc -l )"
			        cnt=$[ $cnt + 1 ]
			done
			echo

			cnt="1"
			echo "BEGIN_SEGMENT 0 $rtype $begin ${WAY[0]} ${ALT[0]}"	>> "$output_dir/$output_sub_dir/${f}.txt"
			while [ "$cnt" -lt $[ ${#WAY[@]} - 1 ] ] ; do           
			        echo "SHAPE_POINT ${WAY[$cnt]} ${ALT[$cnt]}"		>> "$output_dir/$output_sub_dir/${f}.txt"
			        cnt=$[ $cnt + 1 ]
			done
			begin=$[ $begin + 1 ]
			echo "END_SEGMENT $begin ${WAY[$cnt]} ${ALT[$cnt]}"		>> "$output_dir/$output_sub_dir/${f}.txt"
			begin=$[ $begin + 1 ]
	

			i="$[ $i + 1 ]"
		done
	done
fi




#########################################################################3



if [  ! -z "$dsftool" ] ; then
	for i in ${dfs_list[@]} ; do
		echo "Create DSF file \"$i\"..."
		if [ "$( uname -s )" = "Linux" ] ; then
			wine "$dsftool" --text2dsf "$output_dir/$output_sub_dir/${i}.txt" "$output_dir/$output_sub_dir/$i" 
		else
			"$dsftool" --text2dsf "$output_dir/$output_sub_dir/${i}.txt" "$output_dir/$output_sub_dir/$i"
		fi
		echo "-------------------------------------------------------"
	done
fi

exit 0

