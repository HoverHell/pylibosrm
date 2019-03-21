#!/usr/bin/env python3
# pylint: disable=invalid-name,line-too-long

# from time import monotonic_ns
import yaml
import numpy
import msgpack
from pyaux.madness import p_datadiff
import pylibosrm.route_cache as route_cache

# Note: any python version but POSIX only:
monotonic_ns = route_cache.monotonic_ns

cacher = route_cache.RouteCache()
cacher.dump_cache('./.tst_empty_cache.msgp')

coordses = dict(
    src_lon_ar=numpy.array([11.0, 12.0, 13.0, 14.0]),
    src_lat_ar=numpy.array([-31.0, -32.0, -33.0, -34.0]),
    dst_lon_ar=numpy.array([11.3, 12.3, 13.3]),
    dst_lat_ar=numpy.array([-31.3, -32.3, -33.3]),
)

def _sortdicts(lst):
    return sorted(lst, key=lambda item: sorted(item.items()))

def _inverse_index(idxes, size):
    mask = numpy.ones(size, numpy.bool)
    mask[idxes] = 0
    return mask


class TunedYamlDumper(yaml.SafeDumper):

    def represent_mapping(self, tag, mapping, flow_style=None):
        from yaml.nodes import MappingNode, ScalarNode
        value = []
        node = MappingNode(tag, value, flow_style=flow_style)
        if self.alias_key is not None:
            self.represented_objects[self.alias_key] = node
        best_style = True
        if hasattr(mapping, 'items'):
            mapping = list(mapping.items())
        for item_key, item_value in mapping:
            node_key = self.represent_data(item_key)
            node_value = self.represent_data(item_value)
            if not (isinstance(node_key, ScalarNode) and not node_key.style):
                best_style = False
            if not (isinstance(node_value, ScalarNode) and not node_value.style):
                best_style = False
            value.append((node_key, node_value))
        if flow_style is None:
            if self.default_flow_style is not None:
                node.flow_style = self.default_flow_style
            else:
                node.flow_style = best_style
        return node


# pre-test: cache update
result_matrix = numpy.full(
    (len(coordses['src_lon_ar']), len(coordses['dst_lon_ar'])),
    numpy.nan)

src_indexes = numpy.array([0, 2, 3, -1], dtype=numpy.uint64)
src_indexes = cacher.drop_fake_nan(src_indexes)

dst_indexes = numpy.array([1, 2, -1], dtype=numpy.uint64)
dst_indexes = cacher.drop_fake_nan(dst_indexes)

new_result_matrix = numpy.array(
    [[110.123, 110.133],
     [130.123, 130.133],
     [140.123, 140.133]])

new_coordses = dict(
    src_lon_ar=coordses['src_lon_ar'][src_indexes],
    src_lat_ar=coordses['src_lat_ar'][src_indexes],
    dst_lon_ar=coordses['dst_lon_ar'][dst_indexes],
    dst_lat_ar=coordses['dst_lat_ar'][dst_indexes])
cacher.cache_update(
    new_result_matrix=new_result_matrix,
    **new_coordses)
filename = './.tst_minimal_cache.msgp'
cacher.dump_cache(filename)
cache = msgpack.load(open(filename, 'rb'))
cache_expected = _sortdicts([
    dict(src_lon=src_lon, src_lat=src_lat, dst_lon=dst_lon, dst_lat=dst_lat, distance=distance)
    for src_lon, src_lat, dsts in zip(new_coordses['src_lon_ar'], new_coordses['src_lat_ar'], new_result_matrix)
    for dst_lon, dst_lat, distance in zip(new_coordses['dst_lon_ar'], new_coordses['dst_lat_ar'], dsts)])
cache_effective = _sortdicts([
    dict(src_lon=src_lon, src_lat=src_lat, dst_lon=dst_lon, dst_lat=dst_lat, distance=distance)
    for src_lon, items1 in cache.items() for src_lat, items2 in items1.items()
    for dst_lon, items3 in items2.items() for dst_lat, distance in items3.items()])
assert cache_expected == cache_effective

print("Repeatedly poking route_from_cache...")
iterations = 997
t1 = monotonic_ns()
counter = 0
for iteration in range(iterations):  # Ensure it works reliably.
    result_matrix = cacher.route_from_cache(**coordses)
    # Ensure the cache was successfully applied:
    result_matrix_filled_part = result_matrix[src_indexes][:, dst_indexes]
    assert numpy.array_equal(result_matrix_filled_part, new_result_matrix), (iteration, result_matrix_filled_part)
    counter += numpy.sum(result_matrix_filled_part)
t2 = monotonic_ns()
td = (t2 - t1) / 1e9
assert abs(numpy.sum(result_matrix_filled_part) * iterations - counter) < 1e-8, "precision check"
print("Repeatedly poking cache_preprocess: done (%d repeats, %.3fs, %.6fs per loop, checksum %.3f)." % (
    iterations, td, td / iterations, counter))

result_matrix = cacher.route_from_cache(**coordses)
routings, routings_case = cacher.split_unrouted(result_matrix=result_matrix, **coordses)

# # Useful slicings:
# result_matrix[_inverse_index(src_indexes, result_matrix.shape[0])]
# result_matrix[:, _inverse_index(dst_indexes, result_matrix.shape[1])]

# # TODO:
# assert all(
#     numpy.array_equal(value, new_coordses[key])
#     for key, value in pp1['new_data'].items()), pp1['new_data']

from example import worker, make_route_matrix_params, test_routes, lon_range, lat_range

params_with_few_new = make_route_matrix_params(srcs=700, dsts=700)
n_src_lon_ar, n_src_lat_ar, n_dst_lon_ar, n_dst_lat_ar = range(4)
params_with_few_new[n_src_lon_ar][123] += lon_range / 13.13
params_with_few_new[n_src_lon_ar][124] += lon_range / 13.14
params_with_few_new[n_src_lon_ar][125] += lon_range / 13.15
params_with_few_new[n_dst_lon_ar][321] += lon_range / 13.13

paramses = [
    ('700x6', make_route_matrix_params(srcs=700, dsts=6)),
    ('6x700', make_route_matrix_params(srcs=6, dsts=700)),
    ('700x700', make_route_matrix_params(srcs=700, dsts=700)),
    ('700x700 with few new', params_with_few_new),
]

for pfx in ('', 'repeated '):
    for case, params in paramses:
        case = pfx + case
        route_result, details = cacher.route_matrix_verbose(worker, *params)
        details.pop('datas', None)
        details.pop('timestamps', None)
        details['timings'] = {key: '%.6fs' % (val / 1e9,) for key, val in details['timings'].items()}
        # print("case=%r, details=%r" % (case, details))
        print(yaml.dump(
            dict(case=case, details=details),
            default_flow_style=False,
            Dumper=TunedYamlDumper,
        ))


cacher.dump_cache('./tst_resulting_cache.msgp')
