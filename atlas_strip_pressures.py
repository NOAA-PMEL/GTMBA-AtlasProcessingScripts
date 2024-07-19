#!/usr/bin/env python
"""
Script to strip the 300m & 500m pressures from a file with more pressure data.

Author: Daryn White (daryn.white@noaa.gov)
"""
import os
import argparse
import tao.atlas.ram

parser = argparse.ArgumentParser(
    prog="atlas_strip_pressures",
    description="Simple script to pull only the 300m & 500m pressures of an Atlas2 (NX) RAM file with more.",
)
parser.add_argument("file", metavar="file", help="RAM file for editing")
args = parser.parse_args()

# Import file, write out 300m and 500m columns only
infile = tao.atlas.ram.File(args.file)
inframe = infile.frame

outframe = inframe

for n, i in enumerate(inframe.columns.get_level_values(1)):
    if i != "300" and i != "500":
        outframe = outframe.drop(inframe.columns[n], 1)

os.rename(args.file, args.file + "_orig")
infile.writeAtlas(outframe, output=args.file)
