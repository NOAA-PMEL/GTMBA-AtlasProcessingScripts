#!/bin/bash
# Script to clone and setup Atlas data directories
# Author: Daryn A. White, daryn.white@noaa.gov -> Only for use w/in GTMBA

## About this script if fed nothing
if [ -z "$1" ]; then
  echo '
  atlasBuild: Clone and setup an Atlas data directory for processing.

  This is purely to make the setup process faster and get into processing data
  quicker. Use is simple, give the name of the directory.

  Example: atlasBuild ra102
  '
  exit 1
fi

## Build out the needed functions and variables
make_files() {
  [ "1" = "$#" ] || {
    echo "Requires BUOYID name"
    return 1
  }
  # shellcheck disable=SC1091
  source /Users/white/bin/tao/functions
  D=("$(splitdep "$1")")
  calfile "$1" | grep -E -v '^#' >"${D[3]}".cal
  nxram_setup "$1"
}

## Actually go get things done
git clone spectrum:/home/data/nxram/"$1" -b processing

if [ "$1" -eq 0 ]; then
  cd "$1" || exit 1
  docfile "$1" >"$1".doc
  make_files "$1"
  echo "Ok, ${1} is built."
  code .
else
  echo "Clone failed"
fi
