#!/bin/bash
# Author: Daryn White, daryn.white@noaa.gov

if [ -z $1 ] && [ -z $2 ]; then
    echo '
    SSC_ramshifts readjusts the SSC data column in temp, sal, cond, & dens files
    to undo erroneous shifts that happened during a deployment

    It is assumed to be run inside the working deployment directory,
    thus this file should be copied into that directory for use

    Use: SSC_ramshifts [Deploy ID] [listfile]

        Deploy ID = the id of the deployment, [ra|pi]###[a|b]
        listfile  = output listfile from SSC_ClockAdjusted script

    Examples:
    SSC_ramshifts ra169a SSC_ClockAdjusted.lst
    '
    exit 1
fi

if [[ $1 =~ ..\d\d\d[a-c] ]]; then
    echo 'Need the deployment leg please'
    echo 'Did you mean?\n $1a'
    exit
elif [[ $2 =~ ..\w.lst ]]; then
    echo 'Need the output listfile please'
    echo 'Did you mean?\n $2a'
    exit
fi;

id=${1: -4}
file=$(find $2)

# check for ram_orig files and create them if they do not exist
for fl in {temp,cond,sal,dens}; do
    if [ -f $fl$id.ram_orig ]; then
        echo "Original $fl$id.ram_orig exists"
    else
        echo "No original files"
        cp $fl$id.ram $fl$id.ram_orig
    fi;
done;

exec 5<$file

len=$(awk 'END { print NR }' $file)

# for i in $len; do TMP$i=$(mktemp); done;

while read -u 5 d s; do
    l=$c
    ((c=$c+1))
    echo "adjustment date: $d | # of samples: $s | l=$l | c=$c"
    if [[ $c == 1 ]]; then
        ram_shift --at=$d --col=1 --samples=$s temp$id.ram_orig > $c
    else
        ram_shift --at=$d --col=1 --samples=$s $l > $c
    fi;
done;

cat $len > temp$id.ram

rm -f $(seq 1 $len)