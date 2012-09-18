#!/bin/bash


url="http://sketchup.google.com/3dwarehouse/data/entities?q=is%3Amodel+is%3Ageo+filetype%3Akmz+near%3A%2244.8357%2C+11.627%22&scoring=d&max-results=100"



list3D="$( wget -O- -q "$url"  | xmllint --format - | grep "application/vnd.google-earth.kmz" | awk -F\" {'print $2'} | recode html/.. )"

echo "http://sketchup.google.com/3dwarehouse/download?mid=7a59bdf06bd3a99eb6e43a42b4402e82&rtyp=ks&fn=Palazzo+Prosperi-Sacrati&ctyp=other&ts=1296745285000"

for i in $list3D ; do
	wget -O cacca.kmz "$i"
	break
done


