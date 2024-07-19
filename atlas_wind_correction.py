#!/usr/bin/env python
## Author: Daryn White, daryn.white@noaa.gov
## Last altered: 2021-04-13
"""
Simple script to alter DIR, U, & V in a met ram file.
Assumes that the difference is the same for the entire deployment.

Usage: python windDirFix.py [ram file] [deg. change]
Example: python windCorrection met111a.ram 180
"""

import argparse
from datetime import datetime
import tao.atlas.ram
import tao.util.calc


# Date normalizing function
def normalizedate(date):
    """Attempting to normalize date entries"""

    fmts = (
        r"%Y-%m-%d",
        r"%Y-%m-%d %H:%M",
        r"%Y-%m-%d %H:%M:%S",
        r"%Y%j",
        r"%Y%j%H%M",
        r"%Y%j%H%M%S",
        r"%Y-%m-%dT%H:%M",
    )
    for f in fmts:
        try:
            dts = datetime.strptime(date, f)
            break
        except ValueError:
            pass
    return dts


# Arg parsing
parser = argparse.ArgumentParser(
    prog="atlas_wind_correction",
    description="""
    Simple script to alter DIR, U, & V in a met ram file.
    Assumes that the difference is the same for the entire deployment.""",
)
parser.add_argument("ramFile", metavar="file", help="Atlas RAM file to be altered")
parser.add_argument("degChange", type=int, help="Cardinal degrees to change direction")
parser.add_argument(
    "--datestart",
    "--start",
    default=None,
    type=str,
    help="Julian timestamp to start adjustments at",
)
parser.add_argument(
    "--datestop",
    "--stop",
    default=None,
    type=str,
    help="Julian timestamp to stop adjustments at",
)
args = parser.parse_args()

# Alter direction by
deg = args.degChange
# Redefine datestart & datestop if exists
if args.datestart:
    datestart = normalizedate(args.datestart)
else:
    datestart = None
if args.datestop:
    datestop = normalizedate(args.datestop)
else:
    datestop = None

# Load file
fl = tao.atlas.ram.File(args.ramFile)
# Load frame
frame = fl.frame
# Get the working slices
if datestart and datestop:
    # Vars to work with
    pdir = frame.loc[datestart:datestop, ("DIR", "-4")]
    spd = frame.loc[datestart:datestop, ("SPEED", "-4")]
elif datestart:
    # Vars to work with
    pdir = frame.loc[datestart:, ("DIR", "-4")]
    spd = frame.loc[datestart:, ("SPEED", "-4")]
elif datestop:
    # Vars to work with
    pdir = frame.loc[:datestop, ("DIR", "-4")]
    spd = frame.loc[:datestop, ("SPEED", "-4")]
else:
    # Vars to work with
    pdir = frame.loc[:, ("DIR", "-4")]
    spd = frame.loc[:, ("SPEED", "-4")]

# Alter the polar direction values
altdir = pdir.values + deg
altdir[altdir > 360] = altdir[altdir > 360] - 360
altdir[altdir < 0] = altdir[altdir < 0] + 360

u, v = tao.util.calc.polarcartesian(spd.values, altdir)

# Replace DIR, U, & V values with new calculations
if datestart and datestop:
    frame.loc[datestart:datestop, ("U", "-4")] = u
    frame.loc[datestart:datestop, ("V", "-4")] = v
    frame.loc[datestart:datestop, ("DIR", "-4")] = altdir
elif datestart:
    frame.loc[datestart:, ("U", "-4")] = u
    frame.loc[datestart:, ("V", "-4")] = v
    frame.loc[datestart:, ("DIR", "-4")] = altdir
elif datestop:
    frame.loc[:datestop, ("U", "-4")] = u
    frame.loc[:datestop, ("V", "-4")] = v
    frame.loc[:datestop, ("DIR", "-4")] = altdir
else:
    frame.loc[:, ("U", "-4")] = u
    frame.loc[:, ("V", "-4")] = v
    frame.loc[:, ("DIR", "-4")] = altdir

fl.writeAtlas(frame, output=args.ramFile + "_fixed")

if datestart and datestop:
    out = f"""
    :: NEED TO ADD THIS TO FLAG FILE! ::
    ## Altered wind data by {deg} deg
    {datestart.strftime("%Y%j%H%M%S")} {datestop.strftime("%Y%j%H%M%S")}  Q3  1..4
    """
elif datestart:
    out = f"""
    :: NEED TO ADD THIS TO FLAG FILE! ::
    ## Altered wind data by {deg} deg
    {datestart.strftime("%Y%j%H%M%S")} END  Q3  1..4
    """
elif datestop:
    out = f"""
    :: NEED TO ADD THIS TO FLAG FILE! ::
    ## Altered wind data by {deg} deg
    BEGIN {datestop.strftime("%Y%j%H%M%S")}  Q3  1..4
    """
else:
    out = f"""
    :: NEED TO ADD THIS TO FLAG FILE! ::
    ## Altered wind data by {deg} deg
    BEGIN END  Q3  1..4
    """

print(out)
