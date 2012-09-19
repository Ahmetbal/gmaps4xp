#!/bin/bash


url="http://sketchup.google.com/3dwarehouse/data/entities?q=is%3Amodel+is%3Ageo+filetype%3Akmz+near%3A%2244.8357%2C+11.627%22&scoring=d&max-results=100"



list3D="$( wget -O- -q "$url"  | xmllint --format - | grep "application/vnd.google-earth.kmz" | awk -F\" {'print $2'} | recode html/.. )"

#echo "http://sketchup.google.com/3dwarehouse/download?mid=7a59bdf06bd3a99eb6e43a42b4402e82&rtyp=ks&fn=Palazzo+Prosperi-Sacrati&ctyp=other&ts=1296745285000"



OUTPUT="$1"

[ -z "$OUTPUT" ] && exit 1

for i in $list3D ; do
	info=( $( echo "$i" | tr "?&" " " ) )
	name="${info[3]#*=}.kmz"
	[ ! -f "$name" ] && wget -O "$name" "$i"

	model_file="models/model.dae"
	model_dae="$( cat ${model_file} )"


	values="$( echo "$model_dae"  | grep "<float_array id=" | grep "\-geometry-" )"

	meshs=( $( echo "$values" | awk -F\" {'print $2'} | awk -F- {'print $1'} | sort -u | tr "\n" " " ) )

	[ ! -d "$OUTPUT/objects" ] && mkdir -p "$OUTPUT/objects"
	for id in ${meshs[*]} ; do
		position_array=( $( echo "$model_dae" | grep "id=\"${id}-geometry-position-array\"" | sed 's/<[^>]*>//g' ) )
		normal_array=(	 $( echo "$model_dae" | grep "id=\"${id}-geometry-normal-array\""   | sed 's/<[^>]*>//g' ) )
		uv_array=(	 $( echo "$model_dae" | grep "id=\"${id}-geometry-uv-array\""       | sed 's/<[^>]*>//g' ) )

		# #mesh2-geometry-uv-array

		objFile="$OUTPUT/objects/${id}.obj"

		cnt="0"		
		while read line ; do
			echo "$line"
			cnt=$[ $cnt + 1 ]
		done <<< "$( echo "${position_array[*]}" | sed -e "s/\([^\ ]*\ [^\ ]*\ [^\ ]*\)\ /\1\\`echo -e '\n\r'`/g" )"
		exit 0	
		echo "${#position_array[*]} ${#normal_array[*]} ${#uv_array[*]}"
		
	done

# float_array id="mesh1-geometry-position-array


	# geometry_normal_array=(); cnt="0"
	# while read line ; do
	# 	[ -z "$line" ] && continue
	# 	echo "$line"
	#	geometry_normal_array[$cnt]="$line"
	#	cnt=$[ $cnt + 1 ]
	# done  <<< "$( cat models/model.dae  | grep "geometry_normal_array" | grep "float_array id=\""  | tr "\n" " " | sed -e s/"<\/float_array>"/"\n"/g | sed 's/<[^>]*>//g' )"

	# echo "${geometry_position_array[6]}" | sed -e "s/\([^\ ]*\ [^\ ]*\ [^\ ]*\)\ /\1\\`echo -e '\n\r'`/g" 
	# echo "${geometry_normal_array[6]}"   | sed -e "s/\([^\ ]*\ [^\ ]*\ [^\ ]*\)\ /\1\\`echo -e '\n\r'`/g" 

	break
done


