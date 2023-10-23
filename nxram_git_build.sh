#!/bin/bash
# Script to intiialize a Git repository inside a previously processed site needing RH review
# Author: Daryn A. White, daryn.white@noaa.gov -> Only for use w/in GTMBA

## About this script if fed nothing
if [ -z "$1" ]; then
    echo '
  nxram_git_build: Initialize an existing NextGen Atlas deployment directory

  This script is solely to convert an untracked data directory into a git tracked
  data directory for ongoing use.

  Usage: nxram_git_build [depid] [commit msg]

  Example: nxram_git_build pm308 "Initial commit. Git added for RH reprocessing."
  '
    exit
fi
## Test deployment ID
valid="[a-zA-Z][a-zA-Z][0-9]{3}$"

## Actually go get things done
if [[ ! "$1" =~ $valid ]]; then
    echo "BUOYID should be in the form aa### not $1"
elif [ -z "$2" ]; then
    echo 'Need the commit message!'
    exit
elif [[ "$1" =~ $valid ]]; then
    echo "depid is '$1' and commit message is '$2'"
    cd "/home/data/nxram/$1" || echo "$1 was not found"
    git init --shared
    touch GIT
    git add .
    git commit -m "$2"
    git branch processing
    echo "Ok, ${1} is converted"
else
    echo "The script failed!" && exit 200
fi
