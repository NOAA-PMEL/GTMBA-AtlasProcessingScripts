#!/usr/bin/env python
"""
Script to check for & set RH values over 100% to 100%
Also, this will set the flag falue to 3

Use: atlasRH met124a.flg
"""
## Author: Daryn White, daryn.white@noaa.gov
## Last altered: 2020-10-27
import os
import argparse
import tao.atlas.flg

## Parse handed arguments
parser = argparse.ArgumentParser(
    prog="atlasRH",
    description="Simple script to alter the RH of a met file. Sets all values >100.0 to Q3 and 100.0",
)
parser.add_argument("fl", metavar="file", help="FLG file for processing")
args = parser.parse_args()

## Load file
metFile = tao.atlas.flg.File(args.fl)
## Load frame
metFrame = metFile.frame

## check for values over 100.00%
if (metFrame["HUM"]["-3"] > 100.00).any():
    ## Proceed w/altering the file
    ## Move original file
    os.rename(args.fl, args.fl + "_orig")

    ## Qualities go first
    metFrame.loc[metFrame["HUM"]["-3"] > 100.00, ("Q", 3)] = 3
    ## Set values
    metFrame.loc[metFrame["Q"][3] == 3, ("HUM", "-3")] = 100.00

    ## Write file with altered data
    metFile.writeAtlas(
        metFrame,
        formats=[
            "7.2",  # u
            "7.2",  # v
            "7.2",  # spd
            "7.1",  # dir
            "7.2",  # at
            "7.2",  # rh
            "1.0",  # quals
            "1.0",
            "1.0",
            "1.0",
            "1.0",  # source
            "1.0",
            "1.0",
            "1.0",
        ],
        output=args.fl,
    )
else:
    print("No humidity values over 100.00%")