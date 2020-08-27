#!/bin/bash
# Script to deal with improperly incremented subsurface modules from Atlas

if [ -z $1 ] && [ -z $2 ] && [ -z $3 ]; then
  echo '
  badA2increment copies and processes the bad file in a new directory.
  
  Use: badA2increment [Serial #] [increm] [Deploy ID] [Type]
        
        Serial #  = ONLY the serial number of the improperly deployed module
        increm    = the increment OF the instrument (120, 180, etc)
        Deploy ID = the id of the deployment, [ra|pi]###[a|b]
        Type      = type of files [ temp | sal | pres ]
        Cond #    = serial of the conductivity/pressure sensor, required for merging.
  
  Examples: 
  badA2increment 11212 120 ra121a temp
  badA2increment 11212 120 ra121a sal 1211
  badA2increment 11212 120 ra121a pres 234882
  '
  exit 1
fi

if [ -z $1 ]; then
  echo 'Need the serial number!'
  exit
elif [ -z $2 ]; then
  echo 'Need the increment!'
  exit
elif [ -z $3 ]; then
  echo 'Need the deployment!'
  exit
elif [[ $3 =~ ..\d\d\d[a-c] ]]; then
  echo 'Need the deployment leg please'
  echo 'Did you mean?\n $3a'
  exit
elif [[ $1 =~ [A-Za-z] ]]; then
  echo 'No letters in the serial number please'
  exit
elif [[ $2 =~ [0-9]{2,3}\b ]]; then
  echo 'Did you mean $2 increment?'
  exit
elif [ $4 == 'temp' ]; then
  file=$(find *$1.*)
  calfile=$(find *.cal)
  id=${3: -4}
  echo 'Creating directory...'
  mkdir $1
  mv $file $1/
  echo 'Moving files, running processing programs...'
  processA2Mod $3 ./ --cal $calfile
  cd $1/
  cp $file ${file}_orig
  processA2Mod $3 $file --cal ../$calfile --inc $2
  echo 'Cleaning files, moving up for merging...'
  find ${4}${id}.ram | while read file; do
    (head -n 5 $file; tail -n +6 $file | grep -e '\d\d\d\d\d\d\d\d\d\d000') > ${file}_${2}
    mv ${file}_${2} ../
  done
  cd ..
  echo 'Merging files...'
  find ${4}${id}.ram | while read file; do
    mv $file ${file}_orig
    mergeA2ram $1 ${file}_orig ${file}_${2} > ${file}
    mv ${file}_${2} $1/
  done
  echo 'Done.'
elif [ $4 == 'pres' ]; then
  if [ -z $5 ]; then
    echo 'Need the pressure sensor serial'
    exit
  fi
  file=$(find *$1.*)
  calfile=$(find *.cal)
  id=${3: -4}
  echo 'Creating directory...'
  mkdir $1
  mv $file $1/
  echo 'Moving files, running processing programs...'
  processA2Mod $3 ./ --cal $calfile
  cd $1/
  cp $file ${file}_orig
  processA2Mod $3 $file --cal ../$calfile --inc $2
  echo 'Cleaning files, moving up for merging...'
  find ${4}${id}.ram | while read file; do
    (head -n 5 $file; tail -n +6 $file | grep -e '\d\d\d\d\d\d\d\d\d\d000') > ${file}_${2}
    mv ${file}_${2} ../
  done
  cd ..
  echo 'Merging files...'
  find ${4}${id}.ram | while read file; do
    mv $file ${file}_orig
    mergeA2ram $5 ${file}_orig ${file}_${2} > ${file}
    mv ${file}_${2} $1/
  done
  echo 'Done.'
elif [ $4 == 'sal' ]; then
  if [ -z $5 ]; then
    echo 'Need the conductivity cell number'
    exit
  fi
  file=$(find *$1.*)
  calfile=$(find *.cal)
  id=${3: -4}
  echo 'Creating directory...'
  mkdir $1
  mv $file $1/
  echo 'Moving files, running processing programs...'
  processA2Mod $3 ./ --cal $calfile
  cd $1/
  cp $file ${file}_orig
  processA2Mod $3 $file --cal ../$calfile --inc $2
  echo 'Cleaning files, moving up for merging...'
  find {cond${id}.ram,dens${id}.ram,sal${id}.ram,temp${id}.ram} | while read file; do
    (head -n 5 $file; tail -n +6 $file | grep -e '\d\d\d\d\d\d\d\d\d\d000') > ${file}_${2}
    mv ${file}_${2} ../
  done
  cd ..
  echo 'Merging salinity files...'
  find {cond${id}.ram,dens${id}.ram,sal${id}.ram} | while read file; do
    mv $file ${file}_orig
    mergeA2ram $5 ${file}_orig ${file}_${2} > ${file}
    mv ${file}_${2} $1/
  done
  echo 'Merging temperature file...'
  find temp${id}.ram | while read file; do
    mv $file ${file}_orig
    mergeA2ram $1 ${file}_orig ${file}_${2} > ${file}
    mv ${file}_${2} $1/
  done
  echo 'Done.'
else
  echo 'No direction given. Gotta feed the beast.'
  exit
fi