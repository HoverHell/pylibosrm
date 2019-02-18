#!/usr/bin/env python3
# pylint: disable=invalid-name

import os
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
# mode="foot"  # mode="car"
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
    return (
        from_lon_ar, from_lat_ar,
        to_lon_ar, to_lat_ar)

    mresult = worker.route_matrix(
        from_lon_ar=from_lon_ar,
        from_lat_ar=from_lat_ar,
        to_lon_ar=to_lon_ar,
        to_lat_ar=to_lat_ar,
        mode=mode,
    )
    return mresult

test_routes = test_route_matrix()
for ret_mode in ('duration_seconds', 'distance_meters'):
    mresult = worker.route_matrix(*test_routes, mode=ret_mode)
    print(ret_mode)
    print(mresult)
    if os.environ.get('E_COMPARE_HTTP') and ret_mode == 'duration_seconds':
        import itertools
        import requests
        import numpy as np
        url_base = 'http://localhost:5000/table/v1/foot/'
        url = url_base + ';'.join(
            '{},{}'.format(lon, lat)
            for lon, lat in itertools.chain(
                    # from_lon, from_lat
                    zip(test_routes[0], test_routes[1]),
                    # to_lon, to_lat
                    zip(test_routes[2], test_routes[3])))
        params = dict(
            sources=';'.join([str(val) for val in range(len(test_routes[0]))]),
            destinations=';'.join([
                str(val) for val in range(
                    len(test_routes[0]),
                    len(test_routes[0]) + len(test_routes[2]))]))
        resp = requests.get(url, params=params)
        resp.raise_for_status()
        resp_data = resp.json()
        assert resp_data['code'] == 'Ok'
        resp_results = np.array(resp_data['durations'])
        assert np.array_equal(mresult, resp_results)


if not os.environ.get('E_SKIP_PERFTEST'):
    print("perf-test...")
    import time
    perf_num = 100
    perf_data = test_route_matrix(num=perf_num)
    t1 = time.time()
    mresult = worker.route_matrix(*perf_data, mode='duration_seconds')
    t2 = time.time()
    print("Time for {size}x{size} matrix: {timing:.3f}".format(
        size=perf_num,
        timing=t2 - t1))

_dbg('cleanup')
del worker
print("...")
