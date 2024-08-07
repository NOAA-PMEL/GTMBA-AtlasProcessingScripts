#!/usr/bin/env python

import re
from argparse import ArgumentParser as AP


# ArgParser
parser = AP(
    prog="atlas_strip_temp_numbers",
    description="Script to pull percent return numbers for Atlas subsurface temperature data from a summary file",
)
parser.add_argument("file", metavar="file", help="Summmary file (.sum)", type=open)
args = parser.parse_args()

# Vars
out = []

# RegEx
patt = re.compile(
    r"(?<=\w\s{4}#\d{5})\s+(\d{2,}|\d{1,}|\d\d\.\d|\d.\d)(?=\s%|%|\s{1,}\/)"
)

for m in re.finditer(patt, args.file.read()):
    out.append(float(m.group(0)))

if not out:
    patt = re.compile(r"(?<=\w\s{4}#\d{5}\s{2})(\d{1,3}\.\d|\d{2,}|\d{1,})")

    for m in re.finditer(patt, args.file.read()):
        out.append(float(m.group(0)))

print(str(out))
