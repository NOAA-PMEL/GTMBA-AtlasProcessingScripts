#!/usr/bin/env python
# Author: Daryn White, daryn.white@noaa.gov
"""
Take a block of clock adjust times from the module log file
and convert them to a .lst file for bash processing

THIS SCRIPT ASSUMES THAT ONLY ONE MODULE HAS CLOCK ADJUSTMENTS
"""

import argparse
import re
from datetime import datetime as dt

# Argparsing
parser = argparse.ArgumentParser(
    prog="atlas_SSC_Clock_Adjusted",
    description="""
Take a block of clock adjust times from the module log file
and convert them to a .lst file for bash processing.

THIS SCRIPT ASSUMES THAT ONLY ONE MODULE HAS CLOCK ADJUSTMENTS
""",
)
parser.add_argument("logfile", metavar="file")
parser.add_argument("--outfile", default="SSC_ClockAdjusted")
args = parser.parse_args()

# Regex building
adjustment_patt = re.compile(r"(?<=Clock adjusted by )[\-\d]{,4}(?= samples)")
datetimes_patt = re.compile(r"(?<= buffer at )\d{4}/\d{2}/\d{2} \d{2}:\d{2}:\d{2}(?=!)")

# File opening
with open(args.logfile, mode="r", encoding="utf8") as log_file:
    # Pattern matching
    adjustments_list = re.findall(adjustment_patt, log_file.read())
    log_file.seek(0)
    datetimes_list = re.findall(datetimes_patt, log_file.read())

# Convert text dates to Julian & adjust times
dt_out_list = []
for d in datetimes_list:
    dt_out_list.append(dt.strptime(d, "%Y/%m/%d %H:%M:%S").strftime("%Y%j%H1000"))

# Invert the offsets
adj_out_list = []
for a in adjustments_list:
    adj_out_list.append(str(-int(a)))

# Mash the lists together
out_list = [a[0] + "  " + a[1] for a in zip(dt_out_list, adj_out_list)]

# Output a .lst file
with open(args.outfile + ".lst", mode="w", encoding="utf8") as out_file:
    for i in out_list:
        out_file.write(i + " \n")
