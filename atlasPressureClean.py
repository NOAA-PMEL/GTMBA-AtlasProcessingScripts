#!/usr/bin/env python2
import sys
import tao.atlas.ram

# Import file, write out 300m and 500m columns only
fl = sys.argv[1]

infile = tao.atlas.ram.File(fl)
inframe = infile.frame

outframe = inframe

for n, i in enumerate(inframe.columns.get_level_values(1)):
    if i != u"300" and i != u"500":
        outframe = outframe.drop(inframe.columns[n], 1)

infile.writeAtlas(outframe, output=fl + ".0")
