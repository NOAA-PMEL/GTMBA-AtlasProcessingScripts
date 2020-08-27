#!/usr/bin/env python2
"""
Simple script for pulling in 2 Atlas ram files and merging them into a single
ram file. Takes the first file and replaces the data column for the serial
number provided with the data column of the second fileself.

Example: python2 15533 temp113a.ram_orig temp113a.ram_120 > temp113a.ram
"""

import sys
import tao.atlas.ram

## serial #, merging into, source of data
serial, file_1, file_2 = sys.argv[1:]

ram_file_1 = tao.atlas.ram.File(file_1)
ram_file_2 = tao.atlas.ram.File(file_2)

ram1 = ram_file_1.frame
ram2 = ram_file_2.frame

ram1[serial] = ram2[serial]

ram_file_1.writeAtlas(ram1)
