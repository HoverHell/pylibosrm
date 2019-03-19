#!/usr/bin/env python3

import numpy
import pylibosrm.route_cache as route_cache

cacher = route_cache.RouteCache()
cacher.dump_cache('.tst_empty_cache.msgp')

src_lon = numpy.array([11.0, 12.0, 13.0, 14.0])
src_lat = numpy.array([-31.0, -32.0, -33.0, -34.0])
dst_lon = numpy.array([11.3, 12.3, 13.3])
dst_lat = numpy.array([-31.3, -32.3, -33.3])

# pre-test:
result_matrix = numpy.full((len(src_lon), len(dst_lon)), numpy.nan)
src_indexes = numpy.array([0, 2, 3, -1], dtype=numpy.uint64)
src_indexes = cacher.drop_fake_nan(src_indexes)
dst_indexes = numpy.array([1, 2, -1], dtype=numpy.uint64)
dst_indexes = cacher.drop_fake_nan(dst_indexes)
new_result_matrix = numpy.array(
    [[110.123, 110.133],
     [130.123, 130.133],
     [140.123, 140.133]])
new_src_lon = src_lon[src_indexes]
new_src_lat = src_lat[src_indexes]
new_dst_lon = dst_lon[dst_indexes]
new_dst_lat = dst_lat[dst_indexes]
cacher.cache_update(
    src_lon_ar=new_src_lon,
    src_lat_ar=new_src_lat,
    dst_lon_ar=new_dst_lon,
    dst_lat_ar=new_dst_lat,
    results=new_result_matrix)
