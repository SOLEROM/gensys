#!/bin/bash

pwd=$1

echo "#######################################################"
echo "Runnig status check on all my gits:"
echo "#######################################################"

dirs=($( find -L $pwd  -type d -name .git -printf '%h\n' ))
for dir in "${dirs[@]}"; do
  echo "======================================================="
  cd $dir
  echo $PWD
  git status -s
done
