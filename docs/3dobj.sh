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





matrixApply(){
	matrix=( $1 )
	coords=( $2 1 )

	awk 'BEGIN { printf "%f ", ( '${coords[0]}' * '${matrix[0]}'  ) + ( '${coords[1]}' * '${matrix[1]}'  ) + ( '${coords[2]}' * '${matrix[2]}'  ) + ( '${coords[3]}' * '${matrix[3]}'  ) }' 
	awk 'BEGIN { printf "%f ", ( '${coords[0]}' * '${matrix[4]}'  ) + ( '${coords[1]}' * '${matrix[5]}'  ) + ( '${coords[2]}' * '${matrix[6]}'  ) + ( '${coords[3]}' * '${matrix[7]}'  ) }' 
	awk 'BEGIN { printf "%f ", ( '${coords[0]}' * '${matrix[8]}'  ) + ( '${coords[1]}' * '${matrix[9]}'  ) + ( '${coords[2]}' * '${matrix[10]}' ) + ( '${coords[3]}' * '${matrix[11]}' ) }' 
#	awk 'BEGIN { printf "%f",  ( '${coords[0]}' * '${matrix[12]}' ) + ( '${coords[1]}' * '${matrix[13]}' ) + ( '${coords[2]}' * '${matrix[14]}' ) + ( '${coords[3]}' * '${matrix[15]}'  ) }' 

}


url="http://sketchup.google.com/3dwarehouse/data/entities?q=is%3Amodel+is%3Ageo+filetype%3Akmz+near%3A%2244.8357%2C+11.627%22&scoring=d&max-results=100"



list3D="$( wget -O- -q "$url"  | xmllint --format - | grep "application/vnd.google-earth.kmz" | awk -F\" {'print $2'} | recode html/.. )"

#echo "http://sketchup.google.com/3dwarehouse/download?mid=7a59bdf06bd3a99eb6e43a42b4402e82&rtyp=ks&fn=Palazzo+Prosperi-Sacrati&ctyp=other&ts=1296745285000"



overLayDir="/home/cavicchi/Documents/Repository/gmaps4xp/docs/overlay"

obj_list="obj_list.txt"
dsf_body="dsf_body.txt"
OUTPUT="$overLayDir/output"
[ -f   "$OUTPUT/$obj_list" ] && rm -f "$OUTPUT/$obj_list"
[ -f   "$OUTPUT/$dsf_body" ] && rm -f "$OUTPUT/$dsf_body"

mkdir -p "$OUTPUT/Earth nav data/+40+010/"

for i in $list3D ; do
	info=( $( echo "$i" | tr "?&" " " ) )
	name="${info[3]#*=}.kmz"
	#[ "$name" != "bloccoB.kmz" ] && continue
	echo "Elaborating $name file ..."
	
	[ ! -d "$overLayDir/kmz" ]	 && mkdir -p "$overLayDir/kmz"
	[ ! -d "$overLayDir/kml" ]	 && mkdir -p "$overLayDir/kml"
	[ ! -f "$overLayDir/kmz/$name" ] && wget  -O "$overLayDir/kmz/$name" "$i"

	kmlDir="$overLayDir/kml/${name%.*}"
	[ ! -d "$kmlDir" ] && mkdir -p "$kmlDir"	
	unzip -o -q -d "$kmlDir" "$overLayDir/kmz/$name"


	model_file="$kmlDir/models/model.dae"
	images_dir="$kmlDir/images"
	kml_file="$kmlDir/doc.kml"

	# TO BE DEFINED AFTER


	model_dae="$( 	cat "${model_file}" )"
	kml="$( 	cat "${kml_file}"   )"


	Model="$(	getTagContent "$kml" 	"<Model>" 	)"
	Location=( $( 	getTagContent "$Model" 	"<Location>" 	|  sed 's/<[^>]*>//g' | tr "\n" " " ) )


	geometries=( $( echo "$model_dae" | grep "geometry id=\"" | awk -F\" {'print $2'} | tr "\n" " " ) )

	library_images="$( 	  getTagContent "$model_dae" "<library_images>" 	)"
	library_materials="$( 	  getTagContent "$model_dae" "<library_materials>" 	)"
	library_effects="$(	  getTagContent "$model_dae" "<library_effects>" 	)"
	library_visual_scenes="$( getTagContent "$model_dae" "<library_visual_scenes>"	)"

	matrixTrans="$( getTagContent "$library_visual_scenes"  "<matrix>" | tr "\n" " " )"
	materials=( $( echo "$library_materials"  | grep "<material id=\"" | awk -F\" {'print $2","$4'} | tr -d "#" | tr "\n" " " ) )

	cnt="0"; unset texture_list;
	for mat in ${materials[*]} ; do
		effects="$( 	getTagContent "$library_materials" "<material id=\"${mat%,*}" | grep "<instance_effect url="  | awk -F\" {'print $2'} | tr -d "#"  )"
		image="$(	getTagContent "$library_effects" "<effect id=\"$effects\"" | grep "<init_from>" |  sed 's/<[^>]*>//g' )"

		if [ -z "$image" ] ; then
			texture="transparent"
		else
			texture="$( getTagContent "$library_images" "<image id=\"$image\"" |  sed 's/<[^>]*>//g' )"
		fi
		texture_list[$cnt]="${mat#*,},$texture"
		cnt=$[ $cnt + 1 ]
	done


	[ ! -d "$OUTPUT/objects"   ] && mkdir -p "$OUTPUT/objects"
	[ ! -d "$OUTPUT/textures"  ] && mkdir -p "$OUTPUT/textures"

	obj_index="0"
	for id in ${geometries[*]} ; do
		echo "Creating object $id ..."
		geometry="$(  getTagContent "$model_dae" "geometry id=\"$id\"" 	)"

		materials=( $(	echo "$geometry" | grep "triangles material=\"" | awk -F\" {'print $2'} | tr "\n" " " ) )

		for material in ${materials[*]}	; do
			triangles="$( 	getTagContent "$geometry"  "triangles material=\"${material}\"" )"
			[ -z "$triangles" ] && continue

			VERTEX="$( 	echo "$triangles" | grep "semantic=\"VERTEX\""   	| awk -F\" {'print $4'} | tr -d "#" )"	
			NORMAL="$( 	echo "$triangles" | grep "semantic=\"NORMAL\""   	| awk -F\" {'print $4'} | tr -d "#" )"	
			TEXCOORD="$( 	echo "$triangles" | grep "semantic=\"TEXCOORD\"" 	| awk -F\" {'print $4'} | tr -d "#" )"	
			POSITION="$(  	getTagContent "$geometry"  "vertices id=\"$VERTEX\"" 	| awk -F\" {'print $4'} | tr -d "#" )"

			
			cnt="0"; i="0"; unset position_array;
			for e in $( getTagContent "$geometry" "source id=\"$POSITION\"" | grep "<float_array" | sed 's/<[^>]*>//g' ) ; do
				line[$i]="$e"; i=$[ $i + 1 ]
				[ "${#line[*]}" -lt "3" ] && continue
				line=( $( matrixApply "$matrixTrans" "${line[*]}" ) )

				position_array[$cnt]="$( awk 'BEGIN { printf "%f %f %f", '${line[1]}', '${line[2]}', '${line[0]}' }'  )"
				unset line; i="0"
				cnt=$[ $cnt + 1 ]
			done

			cnt="0"; i="0"; unset normal_array
			[ ! -z "$NORMAL" ] && for e in $( getTagContent "$geometry" "source id=\"$NORMAL\"" | grep "<float_array" | sed 's/<[^>]*>//g' ) ; do
				line[$i]="$e"; i=$[ $i + 1 ]
				[ "${#line[*]}" -lt "3" ] && continue
				normal_array[$cnt]="${line[*]}"
				unset line; i="0"
				cnt=$[ $cnt + 1 ]
			done

			cnt="0"; i="0"; unset uv_array
			[ ! -z "$TEXCOORD" ] && for e in $( getTagContent "$geometry" "source id=\"$TEXCOORD\"" | grep "<float_array" | sed 's/<[^>]*>//g' ) ; do
				line[$i]="$e"; i=$[ $i + 1 ]
				[ "${#line[*]}" -lt "2" ] && continue
				uv_array[$cnt]="${line[*]}"
				unset line; i="0"
				cnt=$[ $cnt + 1 ]
			done


			echo "Output for material $material ..."
			# 1:VERTEX 2:NORMAL 3:TEXCOORD
			semantic="$( echo "$triangles" | grep "<input semantic=\"" | awk -F\" {'print $6":"$2'}  )"
			semantic_num="$(   echo "${semantic}" | wc -l )"
			vertex_index="$(   echo "${semantic}" | grep "VERTEX" 	| awk -F: {'print $1'} )"
			normal_index="$(   echo "${semantic}" | grep "NORMAL" 	| awk -F: {'print $1'} )"
			texcoord_index="$( echo "${semantic}" | grep "TEXCOORD" | awk -F: {'print $1'} )"
		
			[ -z "$vertex_index" ]		&& vertex_index="x"
			[ -z "$normal_index" ]		&& normal_index="x"
			[ -z "$texcoord_index" ]	&& texcoord_index="x"
	
			cnt="0"; i="0"; unset array
			for e in $( echo "$triangles" | grep "<p>" | sed 's/<[^>]*>//g' ) ; do
				line[$i]="$e"; i=$[ $i + 1 ]
				[ "${#line[*]}" -lt "$semantic_num" ] && continue


				v="x"; n="x"; t="x"
				[ "$vertex_index"   != "x" ] && v="${line[$vertex_index]}"
				[ "$normal_index"   != "x" ] && n="${line[$normal_index]}"
				[ "$texcoord_index" != "x" ] && t="${line[$texcoord_index]}"
							
				array[$cnt]="$v $n $t"
				unset line; i="0"
				cnt=$[ $cnt + 1 ]
			done



	
			cnt="0";
			array_uniq="$( while [ ! -z "${array[$cnt]}" ] ; do
						echo "${array[$cnt]}"
						cnt=$[ $cnt + 1 ]
					done | sort -u 
			)" 

	
			VT="$( while read line ; do
					p=( $line );
					position="0.000000 0.000000 0.000000"; normal="0.000000 0.00000 1.000000"; uv="0.000000 0.000000"
					[ "${p[0]}" != "x" ] && position="${position_array[${p[0]}]}"
					[ "${p[1]}" != "x" ] && normal="${normal_array[${p[1]}]}"
					[ "${p[2]}" != "x" ] && uv="${uv_array[${p[2]}]}"

					echo -ne "$line,VT ${position}\t${normal}\t${uv}\n";
				done <<< "$( echo "$array_uniq" )"
			)"

			cnt="0"; unset array_mod 
			while [ ! -z "${array[$cnt]}" ] ; do
				a="$cnt"
				b="$[ $cnt + 1 ]"
				c="$[ $cnt + 2 ]"
				array_mod[$a]="${array[$c]}"
				array_mod[$b]="${array[$b]}"
				array_mod[$c]="${array[$a]}"
				cnt=$[ $cnt + 3 ]
			done



			texture="$( echo "${texture_list[*]}" | tr " " "\n" | grep "${material}," | awk -F, {'print $2'}  )"

			[ -z "$texture" ] && echo "TEXTURE ERROR $texture" && exit 3

			texture="$( basename -- "$texture" )"; unset texturepng
			[ "$texture" != "transparent" ] && texturepng="$( echo "$texture" | awk -F. {'print $1'}  ).png"
			if [ "$texture" != "transparent" ] && [ ! -f "$OUTPUT/textures/$texturepng" ] ; then
				size="$( identify "$images_dir/$texture" | awk {'print $3'} )"
				if [ "${size%x*}" -gt "${size#*x}" ] ; then
					size="${size%x*}"
				else
					size="${size#*x}"
				fi
				outSize="256"
				while [ "$size" -gt "$outSize" ] ; do outSize=$[ $outSize * 2 ] ; done
				convert  "$images_dir/$texture" -resize ${outSize}x${outSize}\!  "$OUTPUT/textures/$texturepng"
			fi
			[ -z "$texturepng" ] &&	continue


			cnt="0"; unset IDX
			while [ ! -z "${array_mod[$cnt]}" ] ; do
				echo "$VT" | grep -n "${array_mod[$cnt]},VT " | awk -F, {'print $2'}  >> merda
				IDX[$cnt]="$( echo "$VT" | grep -n "${array_mod[$cnt]},VT " | awk -F: {'print $1 - 1'} )"
				cnt=$[ $cnt + 1 ]
			done



			objFile="$OUTPUT/objects/${id}-${material}.obj"
			echo "OBJECT_DEF objects/${id}-${material}.obj" 	>> "$OUTPUT/$obj_list"
			echo "OBJECT $obj_index ${Location[*]}" 		>> "$OUTPUT/$dsf_body"
			

	
			echo -n									>  "$objFile"
			echo "I"								>> "$objFile"
			echo "800"								>> "$objFile"
			echo "OBJ"								>> "$objFile"
			echo									>> "$objFile"
			[ ! -z "$texturepng" ] && echo "TEXTURE ../textures/$texturepng"	>> "$objFile"
			echo									>> "$objFile"
			echo "POINT_COUNTS $( echo "$VT" | wc -l ) 0 0 ${#IDX[*]}"		>> "$objFile"
			echo									>> "$objFile"
			echo "$VT" | awk -F, '{ print $2}'					>> "$objFile"
			echo									>> "$objFile"
			end="$[ ( ${#IDX[*]} / 10 ) * 10 ]"
			i="0"
			[ "${#IDX[*]}" -ge "10" ] && while [ "$i" -lt "$end" ] ; do
				[ "$[ $i % 10 ]" -eq "0" ] && [ "$i" -ne "0" ] && echo 		>> "$objFile"
				[ "$[ $i % 10 ]" -eq "0" ] && echo -ne "IDX10 "			>> "$objFile"
				echo -ne "${IDX[$i]}\t"						>> "$objFile"
				i="$[ $i + 1 ]"
			done
			echo									>> "$objFile"
			while [ ! -z "${IDX[$i]}" ] ; do
				echo "IDX ${IDX[$i]}"						>> "$objFile"
				i="$[ $i + 1 ]"
			done

			echo									>> "$objFile"
			echo "GLOBAL_no_blend"							>> "$objFile"
			#echo "ATTR_no_cull"							>> "$objFile"
			#echo "ATTR_no_blend"							>> "$objFile"
			echo "ATTR_LOD 0.000000 6000.000000"					>> "$objFile"
			echo "TRIS 0 ${#IDX[*]}"						>> "$objFile"
			

			obj_index=$[ $obj_index + 1 ]
		
		done
	done
	break
done


