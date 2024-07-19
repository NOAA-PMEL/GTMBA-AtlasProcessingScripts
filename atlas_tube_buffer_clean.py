#!/usr/bin/env python
"""
Script to clean up a bad/corrupted Atlas Tube file.
"""

import re
from argparse import ArgumentParser as AP


# Functions
def is_binary(test_bytes):
    "Boolean function for determing file as binary or hex"
    textchars = bytearray({7, 8, 9, 10, 12, 13, 27} | set(range(0x20, 0x100)) - {0x7F})
    return bool(test_bytes.translate(None, textchars))


# Regex
PATT = r"(?<!\b)CAFE"
SUBS = "\\nCAFE"

# Parser
parser = AP(
    prog="tube_buffer_clean",
    description="""
        Script to attempt to clean a tube data dump, if corrupt.

        This script only adds newlines in front of any CAFE
        instances that are not at the beginning of a line.
        """,
)
parser.add_argument("file", metavar="file", help="HEX or binary file to be cleaned")
args = parser.parse_args()

with open(args.file, "rb") as file:
    if is_binary(file.read(1024)):
        file.seek(0)
        hexData = file.read().hex().upper()
        outFile = file.name[:-3] + "hex_cleaned"
    else:
        file.seek(0)
        hexData = file.read().decode().upper()
        outFile = file.name + "_cleaned"

    cleanData = re.sub(PATT, SUBS, hexData, 0, re.MULTILINE)
    with open(outFile, "w", encoding="utf8") as output:
        output.write(cleanData)
