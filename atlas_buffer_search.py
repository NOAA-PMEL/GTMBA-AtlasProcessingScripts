#!/usr/bin/env python

"""
Simple script for reviewing Atlas tube files and data BUFFERS
"""

import re
from argparse import ArgumentParser as AP

BUFFERS = {
    1: "met",
    2: "argos",
    3: "swr",
    4: "rain",
    7: "lwr",
    9: "baro",
    10: "dummy",
    11: "rain",
    19: "hrmet",
}


def _found_matches(match):
    if yearpat.match(match[3]):
        size = int(match[1], 16)
        k = int(match[2], 16)
        buff = ""
        if buff := BUFFERS.get(k):
            print(
                f"{match[0]} : {match[3]}-{match[4]}-{match[5]} {match[6]}:{match[7]}:{match[8]} {buff:6s} size {size:d}"
            )


parser = AP(prog="atlas_buffer_search", description="Compares two ")
parser.add_argument(
    "files",
    metavar="files",
    nargs="+",
    help="Atlas Tube dump file names, 1 or more",
    type=ascii,
)
args = parser.parse_args()


logpat = re.compile(
    r"(CAFE)(.{4})(.{4})([0-9]{4})([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})"
)
fastpat = re.compile(
    r"(3502)(.{4})(.{4})([0-9]{4})([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})"
)
yearpat = re.compile(r"^20[12][0-9]")

for fname in args.file:
    print()
    print(fname)
    with open(fname, "rb") as f:
        b = f.read()

    fastmatches = fastpat.findall(b.hex().upper())
    for m in fastmatches:
        _found_matches(m)

    logmatches = logpat.findall(b.hex().upper())
    for m in logmatches:
        _found_matches(m)
