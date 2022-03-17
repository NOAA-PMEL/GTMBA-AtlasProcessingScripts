#!/usr/bin/env python

import sys
import json
import numpy as np


# Parse argv or stdin
if sys.argv[1:]:
    inp = sys.argv[1]
else:
    inp = sys.stdin.read()
conv = json.loads(inp)

data = np.asarray(conv)
mean = np.mean(data)
ret = np.around(mean, decimals=1)

print(ret)
