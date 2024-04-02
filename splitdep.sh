#!/bin/bash

dep=$1 pre="" num="" seg="" 
if [[ "$(echo "${dep}"|grep -E '[0-9]+$')" != "" ]]
then
        dep="${dep}a" 
fi
if [[ "$(echo "${dep}"|grep -E '^[a-zA-Z][a-zA-Z][0-9]+[a-zA-Z]$')" != "" ]]
then
        pre=${dep:0:2} 
        num=${dep:2:${#dep}-3} 
        seg=${dep:0-1} 
elif [[ "$(echo "${dep}"|grep -E '^[a-zA-Z][a-zA-Z][a-zA-Z][0-9]+[a-zA-Z]$')" != "" ]]
then
        pre=${dep:0:3} 
        num=${dep:3:${#dep}-4} 
        seg=${dep:0-1} 
elif [[ "$(echo "${dep}"|grep -E '^[a-zA-Z][a-zA-Z][a-zA-Z][a-zA-Z][0-9]+[a-zA-Z]$')" != "" ]]
then
        pre=${dep:0:4} 
        num=${dep:4:${#dep}-5} 
        seg=${dep:0-1} 
else
        error "Unable to recognize the deployment identifier!" || return 1
fi
echo "${pre} ${num} ${seg}" "${dep}"