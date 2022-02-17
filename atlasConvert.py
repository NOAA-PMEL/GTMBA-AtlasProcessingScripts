#!/usr/bin/env python
## Author: Daryn White, daryn.white@noaa.gov
## Last altered: 2018-04-27
"""
Simple script to convert dates to Julian of an Atlas2 (NX) ram file.

Usage: python2 atlasConvert.py [ram file]
Example: python2 atlasConvert met111a.ram
"""

import sys
import tao.atlas.ram

# Given a file
fl = sys.argv[1]

# Load file
read = tao.atlas.ram.File(fl)
# Load frame
frame = read.frame
# Write the atlas file
read.writeAtlas(frame, output=fl)
