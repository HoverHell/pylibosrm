#!/usr/bin/env python3
# pylint: disable=invalid-name

import os
import gc
import sys
from time import monotonic_ns

import numpy as np


DEBUG = True
COMPARE_HTTP = bool(os.environ.get('E_COMPARE_HTTP'))
SKIP_PERFTEST = bool(os.environ.get('E_SKIP_PERFTEST'))

def _dbg(msg):
    if not DEBUG:
        return
    sys.stderr.write(" ======= " + msg)
    sys.stderr.write('\n')
    sys.stderr.flush()


# Data needs to be downloaded and prepared. Example:
# fln="central-fed-district-latest"
# mode="foot"  # mode="car"
# mkdir osrm_data
# cd osrm_data
# wget "http://download.geofabrik.de/russia/${fln}.osm.pbf"
# # Use osrm from the official docker image:
# osrm_in_docker() { docker run --rm --name osrm-backend-b -t -v "$(pwd):/data" osrm/osrm-backend "$@"; }
# osrm_in_docker osrm-extract -p "/opt/${mode}.lua" "/data/${fln}.osm.pbf"
# osrm_in_docker osrm-partition "/data/${fln}.osrm"
# osrm_in_docker osrm-customize "/data/${fln}.osrm"
# # Alternatively, use the locally built osrm:
# ../osrm-backend/build/osrm-extract -p "../osrm-backend/profiles/${mode}.lua" "./${fln}.osm.pbf"
# ../osrm-backend/build/osrm-partition "./${fln}.osrm"
# ../osrm-backend/build/osrm-customize "./${fln}.osrm"

filename = "./osrm_data/central-fed-district-latest.osrm"
_dbg('import')
import pylibosrm.osrm_wrapper as ow
_dbg('init')
worker = ow.OSRMWrapper(filename, _debug=DEBUG)
_dbg('route')
# # Small area
# lon1 = 37.7711303
# lat1 = 55.808113
# lon2 = 37.7070137
# lat2 = 55.7969917
# # Half-of-Moscow area.
lon1 = 37.441942
lat1 = 55.6604125
lon2 = 37.7408831
lat2 = 55.8350469
result = worker.route_one(
    lon1, lat1, lon2, lat2,
    _debug=DEBUG)
print(result)
_dbg('route_outside_the_data')
try:
    result = worker.route_one(
        -lon1, -lat1, -lon2, -lat2,
        _debug=DEBUG)
except ow.RouteException as exc:
    print(repr(exc))
else:
    raise Exception("Was supposed to raise", result)


_dbg("route_matrix...")


def make_route_matrix_params(froms=7, tos=5, mode='duration_seconds'):
    """
    Make some sources+destinations matrix.

    Effectively makes points on two lines of a square.
    """
    # froms_lon_step = (lon2 - lon1) / froms
    froms_lat_step = (lat2 - lat1) / froms
    from_lon_ar = np.full(froms, lon1)  # constant
    from_lat_ar = np.arange(lat1, lat2, froms_lat_step)
    # tos_lon_step = (lon2 - lon1) / tos
    tos_lat_step = (lat2 - lat1) / tos
    to_lon_ar = np.full(tos, lon2)  # constant
    to_lat_ar = np.arange(lat2, lat1, -tos_lat_step)  # reversed just for the variety of it
    return (
        from_lon_ar, from_lat_ar,
        to_lon_ar, to_lat_ar)


def route_by_http(from_lon_ar, from_lat_ar, to_lon_ar, to_lat_ar, mode):
    assert mode == 'duration_seconds'

    import itertools
    import requests
    import numpy as np
    url_base = 'http://localhost:5000/table/v1/foot/'
    url = url_base + ';'.join([
        '{},{}'.format(lon, lat)
        for lon, lat in itertools.chain(
            zip(from_lon_ar, from_lat_ar),
            zip(to_lon_ar, to_lat_ar))
    ])
    params = dict(
        sources=';'.join([
            str(val)
            for val in range(len(from_lon_ar))
        ]),
        destinations=';'.join([
            str(val)
            for val in range(
                len(from_lon_ar),
                len(from_lon_ar) + len(to_lon_ar))
        ])
    )
    resp = requests.get(url, params=params)
    resp.raise_for_status()
    resp_data = resp.json()
    assert resp_data['code'] == 'Ok'
    resp_results = np.array(resp_data['durations'])
    return resp_results, resp.elapsed.total_seconds()


test_routes = make_route_matrix_params()
for ret_mode in ('duration_seconds', 'distance_meters'):
    _dbg("route_matrix: {}...".format(ret_mode))
    t1 = monotonic_ns()
    mresult = worker.route_matrix(*test_routes, mode=ret_mode, _debug=True)
    t2 = monotonic_ns()
    print(mresult)
    _dbg("... in {:.3f}s.".format((t2 - t1) / 1e9))
    if COMPARE_HTTP and ret_mode == 'duration_seconds':
        _dbg("route_matrix: {} from http...".format(ret_mode))
        t3 = monotonic_ns()
        resp_results, resp_time = route_by_http(*test_routes, mode=ret_mode)
        t4 = monotonic_ns()
        _dbg("... inner={:.3f}s, oter={:.3f}s.".format(resp_time, (t4 - t3) / 1e9))
        if not np.array_equal(mresult, resp_results):
            raise Exception("local/http mismatch", dict(local=mresult, http=resp_results))
        else:
            _dbg("HTTP-compare ok.")


if not SKIP_PERFTEST:
    _dbg("perf-test...")
    ret_mode = 'duration_seconds'
    import time
    perf_num = 100 if COMPARE_HTTP else 1000
    perf_data = make_route_matrix_params(froms=perf_num, tos=perf_num)
    # print("perf_data:", perf_data)
    t1 = monotonic_ns()
    mresult = worker.route_matrix(*perf_data, mode=ret_mode)
    t2 = monotonic_ns()
    print("Time for {size}x{size} matrix: {timing:.3f}".format(
        size=perf_num,
        timing=(t2 - t1) / 1e9))
    if COMPARE_HTTP:
        t3 = monotonic_ns()
        resp_results, resp_time = route_by_http(*perf_data, mode=ret_mode)
        t4 = monotonic_ns()
        print("Time for {size}x{size} matrix by http: inner={timing:.3f}, outer={outer_timing:.3f}".format(
            size=perf_num,
            timing=resp_time,
            outer_timing=(t4 - t3) / 1e9))
        if not np.array_equal(mresult, resp_results):
            raise Exception("local/http mismatch in perf")
        else:
            _dbg("HTTP-compare ok.")


_dbg('cleanup...')
del worker
gc.collect()
_dbg('done.')
