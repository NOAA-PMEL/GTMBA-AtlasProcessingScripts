#!/usr/bin/env python2
## Author: Daryn White, daryn.white@noaa.gov
## Last altered: 2018-01-24
import sys
import argparse
import tao.atlas.ram
import tao.util.calc

## Parse handed arguments
parser = argparse.ArgumentParser(
    prog="rainFix",
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

out = """
:: NEED TO ADD THIS TO FLAG FILE! ::
## Altered rain data by %d ml and scaled %d to %d & %d to %d
BEGIN END  Q3  1
""" % (
    args.val,
    args.A,
    args.a,
    args.B,
    args.b,
)

sys.write(out)
