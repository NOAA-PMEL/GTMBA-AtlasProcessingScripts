#!/usr/bin/env python
## Author: Daryn White, daryn.white@noaa.gov
"""
Simple script to fix cyclic data within Atlas subsurface RAM
"""

import sys
import os
import argparse
import tao.atlas.ram as RAM

from numpy import nan as NAN

parser = argparse.ArgumentParser(
    prog="atlasModuleNoise",
    description="Simple script to fix cyclic data within Atlas subsurface RAM",
)
parser.add_argument("file", metavar="file", help="RAM file for editing")
parser.add_argument("serial", type=int, help="Serial number of module")
parser.add_argument("depth", type=int, help="Depth of module")
parser.add_argument("val", type=float, help="Value the module is jumping to")

args = parser.parse_args()

ram_file = RAM.File(args.file)
frame = ram_file.frame

module = frame.loc[:, (str(args.serial), str(args.depth))]

module[module == args.val] = NAN

os.rename(args.file, args.file + "_orig")
ram_file.writeAtlas(frame, output=args.file)

print(
    f"""
Module {args.serial} at {args.depth}m has had all {args.val} removed.
See the new {args.file} file; {args.file}_orig saved for reference."""
)
