#!/usr/bin/env python
"""
Create Atlas flags for systematic electronic noise in rain data

usage: flag_enoise.py [-h] [--ram] [--lim LIM] [--hdr HDR] rain_file

positional arguments:
  rain_file   a file to process

optional arguments:
  -h, --help  show this help message and exit
  --ram       data in RAM format
  --lim LIM   minimum spike magnitude [default 0.2]
  --hdr HDR   non-Atlas header line count [default None]
"""
import sys
import os
import argparse
import tempfile
import numpy
import tao.atlas.ram
import tao.atlas.flg


def _threshold_float(strval):
    msg = None
    try:
        val = float(strval)
    except Exception as exc:
        msg = exc.args[0]
    else:
        if val <= 0.0:
            msg = "threshold <= 0"
    if msg is not None:
        raise argparse.ArgumentTypeError(msg)
    return val
    ## def _threshold_float


def _getarguments(argv):
    parser = argparse.ArgumentParser(
        description="""
    Create Atlas flags for systematic electronic noise in rain data"""
    )
    parser.add_argument("fob", metavar="rain_file", type=argparse.FileType('r'), help="a file to process")
    parser.add_argument("--ram", action="store_true", help="data in RAM format")
    parser.add_argument(
        "--lim",
        type=_threshold_float,
        default=0.2,
        help="minimum spike magnitude [default 0.2]",
    )
    parser.add_argument(
        "--hdr", type=int, help="non-Atlas header line count [default None]"
    )
    args = parser.parse_args(argv)
    return args
    ## def _getarguments


def _main(argv):
    args = _getarguments(argv)
    if args.ram:
        rain = tao.atlas.ram.File(args.fob, header=args.hdr)
    else:
        rain = tao.atlas.flg.File(args.fob, header=args.hdr)
    frm = rain.frame
    dy = frm.iloc[:, 0].diff()
    (pos_idx,) = (dy > args.lim).to_numpy().nonzero()
    (neg_idx,) = (dy < -args.lim).to_numpy().nonzero()
    dtm = frm.index[numpy.unique(numpy.concatenate((pos_idx, neg_idx - 1)))]
    (n2355,) = numpy.logical_and(dtm.hour == 23, dtm.minute == 55).nonzero()
    (n2356,) = numpy.logical_and(dtm.hour == 23, dtm.minute == 56).nonzero()
    (n1204,) = numpy.logical_and(dtm.hour == 12, dtm.minute == 4).nonzero()
    (n1205,) = numpy.logical_and(dtm.hour == 12, dtm.minute == 5).nonzero()
    dtm = dtm.values[numpy.sort(numpy.concatenate((n2355, n2356, n1204, n1205)))]
    dtm = dtm.astype("datetime64[s]")
    if dtm.size:
        total = n2355.size + n2356.size + n1204.size + n1205.size
        dt = numpy.diff(frm.index.values.astype("datetime64[s]"))[0]
        dtm = reduceTimes(dtm, dt)
        flags = ["", "RAIN", "## DAW systematic electronic noise using flag_enoise"]
        flags.append("##{:>16} = {}".format("YYYYDDD235532", n2355.size))
        flags.append("##{:>16} = {}".format("YYYYDDD235632", n2356.size))
        flags.append("##{:>16} = {}".format("YYYYDDD120432", n1204.size))
        flags.append("##{:>16} = {}".format("YYYYDDD120532", n1205.size))
        flags.append("##{:>20} / {}".format(total, frm.index.size))
        flags.extend(["{:%Y%j%H%M%S} {:%Y%j%H%M%S}  F  1".format(*r) for r in dtm])
        flags.append("")
        (fd, fname) = tempfile.mkstemp(prefix="flags_", suffix=".txt", text=True)
        with os.fdopen(fd, 'w') as fob:
            fob.write("\n".join(flags))
        print(fname)
    ## def _main


def reduceTimes(dtm, dt):
    """"""
    stp = dt == numpy.diff(dtm)
    sel = dtm.tolist()
    tms = [[sel[0], sel[0]]]
    n = 1
    for s in stp:
        if s:
            tms[-1][1] = sel[n]
        else:
            tms.append([sel[n], sel[n]])
        n += 1
    return tms
    ## def reduceTinmes


if __name__ == "__main__":
    sys.exit(_main(sys.argv[1:]))
