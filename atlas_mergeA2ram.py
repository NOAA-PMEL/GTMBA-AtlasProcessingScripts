#!/usr/bin/env python
"""
Simple script for pulling in 2 Atlas ram files and merging them into a single
ram file. Takes the first file and replaces the data column for the serial
number provided with the data column of the second fileself.

Example: mergeA2ram 15533 temp113a.ram_orig temp113a.ram_120 > temp113a.ram
"""

import argparse
import tao.atlas.ram

parser = argparse.ArgumentParser(
    prog="mergeA2ram",
    description="""Simple script for pulling in 2 Atlas ram files and merging them into a single ram file. 
    
    Takes the first file and replaces the data column for the serial number provided with the data column of the second fileself.""",
)
parser.add_argument(
    "serial", help="Serial number identifying column needing replacement"
)
parser.add_argument(
    "file_1", metavar="file", help="RAM file needing replacement of a column"
)
parser.add_argument(
    "file_2", metavar="file", help="RAM file to source new data column from"
)
args = parser.parse_args()

## serial #, merging into, source of data

ram_file_1 = tao.atlas.ram.File(args.file_1)
ram_file_2 = tao.atlas.ram.File(args.file_2)

ram1 = ram_file_1.frame
ram2 = ram_file_2.frame

ram1[args.serial] = ram2[args.serial]

ram_file_1.writeAtlas(ram1)
