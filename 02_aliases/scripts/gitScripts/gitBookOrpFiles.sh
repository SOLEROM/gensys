#!/bin/bash
#########################################################################################
## find orpehn md files - files *.md that are in folders but no instance in summary file
#########################################################################################

##inputParam of search directory
cur=$1
cd $cur

echo "=========================================================="
echo "Orphen (md)files in $cur"
echo "=========================================================="


##(1)run only if SUMMARY.md found 
if [[ ! -f "readme.md" ]]; then
    echo "no readme.md in $cur"
    exit
fi

##(2) build find command to find all relavent md files
findCMD="find . -name '*.md'"
findCMD=$findCMD" \( ! -name "readme.md" ! -name "SUMMARY.md" \) -printf '%P\n' |sort"
#echo $findCMD

##(3)build cmd to get all md files from current SUMMARY
curMDlist="cat readme.md | grep \"\.md\" |cut -d\( -f2 |cut -d\) -f1 |sort"
#echo $curMDlist

##(4)run compare
compRes=`comm -13  <(eval $curMDlist) <(eval $findCMD)`

for i in $compRes
do 
	j=`echo $i| awk -F/ '{print $NF}' | cut -d. -f1`
	echo "* [$j]($i)"
done

