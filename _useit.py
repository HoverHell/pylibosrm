#!/usr/bin/env python3

import sys

DEBUG = True

def _dbg(msg):
    if not DEBUG:
        return
    sys.stderr.write(msg)
    sys.stderr.write('\n')
    sys.stderr.flush()


filename = "./osrm_data/central-fed-district-latest.osrm"
_dbg('import')
import pylibosrm.osrm_wrapper as ow
_dbg('init')
worker = ow.OSRMWrapper(filename, _debug=DEBUG)
_dbg('route_in')
result = worker.route_one(37.7711303, 55.808113, 37.7070137, 55.7969917, _debug=DEBUG)
print(result)
_dbg('route_out')
try:
    result = worker.route_one(7.419758, 43.731142, 7.419505, 43.736825, _debug=DEBUG)
except ow.RouteException as exc:
    print(repr(exc))
else:
    raise Exception("Was supposed to raise", result)
_dbg('cleanup')
del worker
print("...")
