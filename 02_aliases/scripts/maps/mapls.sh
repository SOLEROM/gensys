#!/bin/bash

# Color vars come from 00_bashrc/bashrc_colors; when run as a child process
# (the ll alias) they aren't inherited, so source them here if missing.
if [ -z "${bldblu:-}" ]; then
  _colors="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/00_bashrc/bashrc_colors"
  [ -f "$_colors" ] && source "$_colors"
fi

function lsmap {
## use map for ls:
#echo "use .map:" $pathInput/$mapFile

## get the file list
lsarr=($(/bin/ls $pathInput))

## read map file ignoreing empty and sharp lines
readarray -t maparr < <(cat $pathInput/$mapFile  | grep -v "^#" | grep -v "^$")

## delete rows in listArr from mapFile
for each in "${maparr[@]}"
do
  file=$(echo $each | cut -d";" -f1)
  #echo remove form map $file
  lsarr=( ${lsarr[@]/$file} )
done


#echo "mapped:"
for each in "${maparr[@]}"
do
  file=$(echo $each | cut -d";" -f1)
  cat=$(echo $each | cut -d";" -f2)
  desc=$(echo $each | cut -d";" -f3)
  echo -e "$bldblu├──" $file  "\t\t $bldcyn(" $cat ") \t$bldblu- " $desc
done



#echo "notInMap:"
for each in "${lsarr[@]}"
do
  cat=" "
  desc=" "
  if [[ -d $pathInput/$each ]]; then
    echo -e "$bldblu├──" $each  
  else
    echo -e "$txtrst├──" $each  
  fi
done
}



## ========================================================================================##
## ========================================================================================##
## vars
pathInput=$1
allInputs=$@
mapFile=.map
## if emply
if [[ $# == 0 ]]; then
  pathInput="."
fi
## no map use regular
if [[ ! -f "$pathInput/$mapFile" ]]; then
  ls -alF $allInputs
else
  lsmap
fi

