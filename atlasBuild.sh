#!/bin/bash
# Script to clone and setup Atlas data directories
# Author: Daryn A. White, daryn.white@noaa.gov -> Only for use w/in GTMBA

## About this script if fed nothing
if [ -z "$1" ]; then
  echo '
  atlasBuild: Clone and setup an Atlas data directory for processing.

  This is purely to make the setup process faster and get into processing data
  quicker. Use is simple, give the name of the directory.

  --noeditor: this option will stop VSCode from launching with the cloned repo open

  Usage: atlasBuild DEPID [--noeditor]

  Examples:
    > atlasBuild ra102
    > atlasBuild ra102 --noeditor
  '
  exit
fi

## Build out the needed functions and variables
make_files() {
  [ "1" = "$#" ] || {
    echo "Requires BUOYID name"
    return 1
  }
  D=$(depsegments "$1")
  for s in $D; do
    calfile "$1" | grep -E -v '^#' >"$1""$s".cal
    nxram_setup "$1""$s" --md
  done
}

valid="[a-zA-Z][a-zA-Z][0-9]{3}$"

## Actually go get things done
if [[ ! "$1" =~ $valid ]]; then
  echo "BUOYID should be in the form aa### not $1"
elif [[ "$1" =~ $valid ]]; then
  git clone spectrum:/home/data/nxram/"$1" -b processing || exit 5
  cd "$1" || exit 1
  docfile "$1" >"$1".doc
  make_files "$1"
  echo "Ok, ${1} is built."
  if [[ ! "$2" =~ "--noeditor" ]]; then
    code .
  fi
else
  echo "Clone failed"
fi
