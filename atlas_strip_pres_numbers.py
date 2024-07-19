#!/usr/bin/env python

import re
from argparse import ArgumentParser as AP


# ArgParser
parser = AP(
    prog="atlas_strip_pres_numbers",
    description="Script to pull percent return numbers for Atlas subsurface pressure data from a summary file",
)
parser.add_argument("file", metavar="file", help="Summmary file (.sum)", type=open)
args = parser.parse_args()

# Vars
out = []

# RegEx
patt = re.compile(r"(?<=TP).+(?<=\/\s)(\d{3,}|\d{1,}|\d\d\.\d)(?=\w{0}%|\s%)")

for m in re.finditer(patt, args.file.read()):
    out.append(float(m.group(1)))

print(str(out))
