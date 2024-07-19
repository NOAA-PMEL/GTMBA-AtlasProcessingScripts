#!/usr/bin/env python
## Author: Daryn White, daryn.white@noaa.gov
## Last altered: 2020-01-07
"""
Simple script to fix wind speed, U, & V
"""

import sys
import argparse
import tao.atlas.ram as RAM
import tao.util.calc as calc

parser = argparse.ArgumentParser(
    prog="atlas_wind_speed_fix",
    description="Simple script to fix wind speeds, U & V, based on input.",
)
parser.add_argument("file", metavar="file", help="RAM file for editing")
parser.add_argument("val", type=int, help="Integer the wind will be divided by")

args = parser.parse_args()

read = RAM.File(args.file)
frame = read.frame

spd = frame.loc[:, ("SPEED", "-4")]

newSpd = spd / args.val

u, v = calc.polarcartesian(newSpd.values, frame.loc[:, ("DIR", "-4")].values)

frame.loc[:, ("U", "-4")] = u
frame.loc[:, ("V", "-4")] = v
frame.loc[:, ("SPEED", "-4")] = newSpd

read.writeAtlas(frame)

out = f"""
:: NEED TO ADD THIS TO FLAG FILE! ::
## Altered wind speeds by dividing by {args.val}
BEGIN END  Q3  1..4
"""

sys.stdout.write(out)
