#!/usr/bin/env python
"""
Script to alter a rain file. Alters the entire deployment.

 Author: Daryn White, daryn.white@noaa.gov
"""
import sys
import argparse
import tao.atlas.ram
import tao.util.calc

## Parse handed arguments
parser = argparse.ArgumentParser(
    prog="atlas_rain_fix",
    description="Simple script to alter a rain file. Alters the entire deployment.",
)
parser.add_argument("fl", metavar="file", help="RAM file for processing")
parser.add_argument("val", type=int, help="Offset volume of data by this amount")
parser.add_argument("A", type=int, help="Lowest value of original data")
parser.add_argument("B", type=int, help="Highest value of original data")
parser.add_argument("a", type=int, help="New value point for A")
parser.add_argument("b", type=int, help="New value point for B")
args = parser.parse_args()

# Load file
read = tao.atlas.ram.File(args.fl)
# Load frame
frame = read.frame

# Vars to work with
rain = frame.loc[:, ("RAIN", "-3")]

# Alter the polar direction values
altrain = rain.values + args.val

# scaling
rainFixed = (args.a + (altrain - args.A) * (args.b - args.a)) / (args.B - args.A)

# Update the frame
frame.loc[:, ("RAIN", "-3")] = rainFixed

# Write file with altered data
read.writeAtlas(frame, output=args.fl + "_fixed")

out = f"""
:: NEED TO ADD THIS TO FLAG FILE! ::
## Altered rain data by {args.val} ml and scaled {args.A} to {args.a} & {args.B} to {args.b}
BEGIN END  Q3  1
"""

sys.stdout.write(out)
