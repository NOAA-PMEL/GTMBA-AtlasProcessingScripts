#!/usr/bin/env python2
## Author: Daryn White, daryn.white@noaa.gov
## Last altered: 2018-01-24
"""
Simple script to alter DIR, U, & V in a met ram file.
Assumes that the difference is the same for the entire deployment.

Usage: python2 windDirFix.py [ram file] [deg. change]
Example: python2 windCorrection met111a.ram 180
"""

import sys
import tao.atlas.ram
import tao.util.calc

# Given a file
fl = sys.argv[1]
# Alter direction by
deg = int(sys.argv[2])

# Load file
read = tao.atlas.ram.File(fl)
# Load frame
frame = read.frame

# Vars to work with
pdir = frame.loc[:, ('DIR', '-4')]
spd = frame.loc[:, ('SPEED', '-4')]

# Alter the polar direction values
altdir = pdir.values + deg
altdir[altdir > 360] = altdir[altdir > 360] - 360
altdir[altdir < 0] = altdir[altdir < 0] + 360

u, v = tao.util.calc.polarcartesian(spd.values, altdir)

# Replace DIR, U, & V values with new calculations
frame.loc[:, ('U', '-4')] = u
frame.loc[:, ('V', '-4')] = v
frame.loc[:, ('DIR', '-4')] = altdir

read.writeAtlas(frame, output=fl + '_fixed')

out = """
:: NEED TO ADD THIS TO FLAG FILE! ::
## Altered wind data by {} deg
BEGIN END  Q3  1..4
""".format(deg)

sys.write(out)
