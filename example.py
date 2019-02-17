#!/usr/bin/env python3
# pylint: disable=invalid-name

import sys

DEBUG = True

def _dbg(msg):
    if not DEBUG:
        return
    sys.stderr.write(msg)
    sys.stderr.write('\n')
    sys.stderr.flush()


# Data needs to be downloaded and prepared. Example:
# fln="central-fed-district-latest"
# mode="foot"  # mode="driving"
# mkdir osrm_data
# cd osrm_data
# wget "http://download.geofabrik.de/russia/${fln}.osm.pbf"
# osrm_in_docker() { docker run --rm --name osrm-backend-b -t -v "$(pwd):/data" osrm/osrm-backend "$@"; }
# osrm_in_docker osrm-extract -p "/opt/${mode}.lua" "/data/${fln}.osm.pbf"
# osrm_in_docker osrm-partition "/data/${fln}.osrm"
# osrm_in_docker osrm-customize "/data/${fln}.osrm"


filename = "./osrm_data/central-fed-district-latest.osrm"
_dbg('import')
import pylibosrm.osrm_wrapper as ow
_dbg('init')
worker = ow.OSRMWrapper(filename, _debug=DEBUG)
_dbg('route_in')
lon1 = 37.7711303
lat1 = 55.808113
lon2 = 37.7070137
lat2 = 55.7969917
result = worker.route_one(
    lon1, lat1, lon2, lat2,
    _debug=DEBUG)
print(result)
_dbg('route_out')
try:
    result = worker.route_one(
        # 7.419758, 43.731142, 7.419505, 43.736825,
        -lon1, -lat1, -lon2, -lat2,
        _debug=DEBUG)
except ow.RouteException as exc:
    print(repr(exc))
else:
    raise Exception("Was supposed to raise", result)

import numpy as np

def test_route_matrix(num=10, mode='duration_seconds'):
    lon_step = (lon2 - lon1) / num
    lat_step = (lat2 - lat1) / num
    from_lon_ar = np.full(num, lon1)  # constant
    from_lat_ar = np.arange(lat1, lat2, lat_step)
    to_lon_ar = np.full(num, lon2)  # constant
    to_lat_ar = np.arange(lat2, lat1, -lat_step)

    mresult = worker.route_matrix(
        from_lon_ar=from_lon_ar,
        from_lat_ar=from_lat_ar,
        to_lon_ar=to_lon_ar,
        to_lat_ar=to_lat_ar,
        mode=mode,
    )
    return mresult

for mode in ('duration_seconds', 'distance_meters'):
    mresult = test_route_matrix(mode=mode)
    print(mode)
    print(mresult)

print("perf-test...")
import time
perf_num = 100
t1 = time.time()
mresult = test_route_matrix(num=100)
t2 = time.time()
print("Time for {size}x{size} matrix: {timing:.3f}".format(
    size=perf_num,
    timing=t2 - t1))
_dbg('cleanup')
del worker
print("...")
