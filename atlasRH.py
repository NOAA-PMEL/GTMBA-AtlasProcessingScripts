#!/usr/bin/env python
## Author: Daryn White, daryn.white@noaa.gov
## Last altered: 2020-08-26
import sys
import argparse
import tao.atlas.ram
import tao.util.calc

## Parse handed arguments
parser = argparse.ArgumentParser(
    prog='rainFix',
    description='Simple script to alter a rain file. Alters the entire deployment.'
)
parser.add_argument('fl', metavar='file', help='FLG file for processing')
args = parser.parse_args()

# Load file
read = tao.atlas.ram.File(args.fl)
# Move original file
# Load frame
frame = read.frame

# Vars to work with
rh = frame.loc[:, ('RH', '-3')]
rq = frame.loc[:, ('Q', '3')]

# Manipulate & flag here

# Update the frame
frame.loc[:, ('RH', '-3')] = rh

# Write file with altered data
read.writeAtlas(frame, output=args.fl + '_fixed')