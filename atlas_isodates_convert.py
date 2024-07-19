#!/usr/bin/env python
## Author: Daryn White, daryn.white@noaa.gov
## Last altered: 2018-04-27
"""
Simple script to convert dates to Julian of an Atlas2 (NX) ram file.

Usage: atlasConvert [ram file]
Example: atlasConvert met111a.ram
"""
import os
import argparse
import tao.atlas.ram

# Given a file
parser = argparse.ArgumentParser(
    prog="atlas_convert",
    description="Simple script to convert dates to Julian of an Atlas2 (NX) RAM file.",
)
parser.add_argument("file", metavar="file", help="RAM file for editing")
args = parser.parse_args()

# Load file
read = tao.atlas.ram.File(args.file)
# Load frame
frame = read.frame
# Write the atlas file
os.rename(args.file, args.file + "_orig")
read.writeAtlas(frame, output=args.file)
