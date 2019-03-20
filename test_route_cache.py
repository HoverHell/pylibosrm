#!/usr/bin/env python3

import numpy
import msgpack
import pylibosrm.route_cache as route_cache

cacher = route_cache.RouteCache()
cacher.dump_cache('.tst_empty_cache.msgp')

src_lon = numpy.array([11.0, 12.0, 13.0, 14.0])
src_lat = numpy.array([-31.0, -32.0, -33.0, -34.0])
dst_lon = numpy.array([11.3, 12.3, 13.3])
dst_lat = numpy.array([-31.3, -32.3, -33.3])


def _sortdicts(lst):
    return sorted(lst, key=lambda item: sorted(item.items()))

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
    new_result_matrix=new_result_matrix)
filename = '.tst_minimal_cache.msgp'
cacher.dump_cache(filename)
cache = msgpack.load(open(filename, 'rb'))
cache_expected = _sortdicts([
    dict(src_lon=src_lon, src_lat=src_lat, dst_lon=dst_lon, dst_lat=dst_lat, distance=distance)
    for src_lon, src_lat, dsts in zip(new_src_lon, new_src_lat, new_result_matrix)
    for dst_lon, dst_lat, distance in zip(new_dst_lon, new_dst_lat, dsts)])
cache_effective = _sortdicts([
    dict(src_lon=src_lon, src_lat=src_lat, dst_lon=dst_lon, dst_lat=dst_lat, distance=distance)
    for src_lon, items1 in cache.items() for src_lat, items2 in items1.items()
    for dst_lon, items3 in items2.items() for dst_lat, distance in items3.items()])
assert cache_expected == cache_effective
