#!/bin/bash
#########################################################################################
scriptFolder=$( dirname ${BASH_SOURCE[0]} )
orhFiles=$scriptFolder/gitBookOrpFiles.sh
orhFolders=$scriptFolder/gitBookOrpFolders.sh

##inputParam of search directory
cur=$1

for d in */; do
    $orhFiles $d
done

$orhFiles $cur
$orhFolders $cur
