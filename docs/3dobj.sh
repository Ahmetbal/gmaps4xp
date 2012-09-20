#!/bin/bash


getTagContent(){
	content="$1"
	key="$2"
	line="$( echo "$content" | grep -n "$key" )"
	endTag="$( echo "${line#*:}" | awk {'print $1'} | sed -e s/"<"/"<\/"/g | tr -d ">" )>"
	while read line ; do
		[ "$line" = "$endTag" ] && break
		echo "$line"
	done <<< "$( echo "$content" | tail -n +$[ ${line%:*} + 1 ]  )"
}


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
	images_dir="images"
	model_dae="$( cat ${model_file} )"
	obj_list="obj_list.txt"
	dsf_body="dsf_body.txt"
	geometries=( $( echo "$model_dae" | grep "geometry id=\"" | awk -F\" {'print $2'} | tr "\n" " " ) )

	library_images="$( 	getTagContent "$model_dae" "<library_images>" 	 )"
	library_materials="$( 	getTagContent "$model_dae" "<library_materials>" )"
	library_effects="$(	getTagContent "$model_dae" "<library_effects>" 	 )"

	materials=( $( echo "$library_materials"  | grep "<material id=\"" | awk -F\" {'print $2","$4'} | tr -d "#" | tr "\n" " " ) )

	cnt="0"
	for mat in ${materials[*]} ; do
		effects="$( 	getTagContent "$library_materials" "<material id=\"${mat%,*}" | grep "<instance_effect url="  | awk -F\" {'print $2'} | tr -d "#"  )"
		image="$(	getTagContent "$library_effects" "<effect id=\"$effects\"" | grep "<init_from>" |  sed 's/<[^>]*>//g' )"
		texture="$( getTagContent "$library_images" "<image id=\"$image\"" |  sed 's/<[^>]*>//g' )"
		texture_list[$cnt]="${mat#*,},$texture"
		cnt=$[ $cnt + 1 ]
	done

	[ ! -d "$OUTPUT/objects"   ] && mkdir -p "$OUTPUT/objects"
	[ ! -d "$OUTPUT/textures"  ] && mkdir -p "$OUTPUT/textures"
	[ -f   "$OUTPUT/$obj_list" ] && rm -f "$OUTPUT/$obj_list"
	[ -f   "$OUTPUT/$dsf_body" ] && rm -f "$OUTPUT/$dsf_body"

	obj_index="0"
	for id in ${geometries[*]} ; do
		echo "Creating object $id ..."
		geometry="$(  getTagContent "$model_dae" "geometry id=\"$id\"" 	)"

		materials=( $(	echo "$geometry" | grep "triangles material=\"" | awk -F\" {'print $2'} | tr "\n" " " ) )

		triangles="$( 	getTagContent "$geometry"  "triangles material=\"${materials[0]}\"" )"
		VERTEX="$( 	echo "$triangles" | grep "semantic=\"VERTEX\""   	| awk -F\" {'print $4'} | tr -d "#" )"	
		NORMAL="$( 	echo "$triangles" | grep "semantic=\"NORMAL\""   	| awk -F\" {'print $4'} | tr -d "#" )"	
		TEXCOORD="$( 	echo "$triangles" | grep "semantic=\"TEXCOORD\"" 	| awk -F\" {'print $4'} | tr -d "#" )"	
		POSITION="$(  	getTagContent "$geometry"  "vertices id=\"$VERTEX\"" 	| awk -F\" {'print $4'} | tr -d "#" )"



			
		cnt="0"
		while read line ; do
			[ -z "$line" ] && continue
			position_array[$cnt]="$line"
			cnt=$[ $cnt + 1 ]
		done <<< "$( getTagContent "$geometry" "source id=\"$POSITION\"" | grep "<float_array" | sed 's/<[^>]*>//g' | sed -e "s/\([^\ ]*\ [^\ ]*\ [^\ ]*\)\ /\1\\`echo -e '\n\r'`/g" | tr -d "\r" )"

		cnt="0"
		while read line ; do
			[ -z "$line" ] && continue
			normal_array[$cnt]="$line"
			cnt=$[ $cnt + 1 ]
		done <<< "$( getTagContent "$geometry" "source id=\"$NORMAL\"" | grep "<float_array" | sed 's/<[^>]*>//g' | sed -e "s/\([^\ ]*\ [^\ ]*\ [^\ ]*\)\ /\1\\`echo -e '\n\r'`/g" | tr -d "\r" )"


		cnt="0"
		while read line ; do
			[ -z "$line" ] && continue
			uv_array[$cnt]="$line"
			cnt=$[ $cnt + 1 ]
		done <<< "$( getTagContent "$geometry" "source id=\"$TEXCOORD\"" | grep "<float_array" | sed 's/<[^>]*>//g' | sed -e "s/\([^\ ]*\ [^\ ]*\)\ /\1\\`echo -e '\n\r'`/g" | tr -d "\r" )"


		for material in ${materials[*]}	; do
			echo "Output for material $material ..."
			objFile="$OUTPUT/objects/${id}-${material}.obj"
			echo "OBJECT_DEF objects/${id}-${material}.obj" 			>> "$OUTPUT/$obj_list"
			echo "OBJECT $obj_index 11.621277611922 44.842663276817 0.000000000000" >> "$OUTPUT/$dsf_body"


			triangles="$( 	getTagContent "$geometry"  "triangles material=\"${material}\"" )"
			cnt="0"
			while read line ; do
				[ -z "$line" ] && continue
				array[$cnt]="$line"
				cnt=$[ $cnt + 1 ]
			done <<< "$( echo "$triangles" | grep "<p>" | sed 's/<[^>]*>//g' | sed -e "s/\([^\ ]*\ [^\ ]*\ [^\ ]*\)\ /\1\\`echo -e '\n\r'`/g" | tr -d "\r" )"
	
			cnt="0"

	
			VT="$( while read line ; do
					p=( $line );
					echo -ne "$line,VT ${position_array[${p[0]}]}\t${normal_array[${p[1]}]}\t${uv_array[${p[2]}]}\n";
				done <<< "$( echo "${array[*]}" | sed -e "s/\([^\ ]*\ [^\ ]*\ [^\ ]*\)\ /\1\\`echo -e '\n\r'`/g" | tr -d "\r" | sort -u )"
			)"


			cnt="0"
			IDX=()
			while [ ! -z "${array[$cnt]}" ] ; do
				IDX[$cnt]="$( echo "$VT" | grep -n "${array[$cnt]}" | awk -F: {'print $1'} )"
				cnt=$[ $cnt + 1 ]
			done

			texture="$( echo "${texture_list[*]}" | tr " " "\n" | grep "${material}," | awk -F, {'print $2'}  )"
			texture="$( basename -- $texture )"
			[ ! -f "$OUTPUT/textures/$texture" ] && cp "$images_dir/$texture" "$OUTPUT/textures/$texture"
		
			echo -n								>  "$objFile"
			echo "I"							>> "$objFile"
			echo "800"							>> "$objFile"
			echo "OBJ"							>> "$objFile"
			echo								>> "$objFile"
			echo "TEXTURE ../textures/$texture"				>> "$objFile"
			echo								>> "$objFile"
			echo "POINT_COUNTS $( echo "$VT" | wc -l ) 0 0 ${#IDX[*]}"	>> "$objFile"
			echo								>> "$objFile"
			echo "$VT" | awk -F, '{ print $2}'				>> "$objFile"
			echo								>> "$objFile"
			for idx in ${IDX[*]} ; do echo "IDX $idx" ; done		>> "$objFile"
			obj_index=$[ $obj_index + 1 ]
		done
	done

	break
done


