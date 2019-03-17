# distutils: language = c++
# cython: language_level=3

from libcpp cimport bool as c_bool
from libcpp.string cimport string as c_string
cimport cython
from cython cimport view
from cython.parallel cimport prange
from libcpp.unordered_map cimport unordered_map
cimport numpy as cnumpy
import numpy
import os

ctypedef cnumpy.uint64_t uint64_t
ctypedef cnumpy.float64_t DTYPE
DTYPE_PY = numpy.float64

 ctypedef unordered_map<DTYPE, DTYPE> _dst_lat_to_duration_seconds
 ctypedef unordered_map<DTYPE, _dst_lat_to_duration_seconds> _dst_lon_to_cache
 ctypedef unordered_map<DTYPE, _dst_lon_to_cache> _src_lat_to_cache
 ctypedef unordered_map<DTYPE, _src_lat_to_cache> _src_lon_to_cache
 ctypedef _src_lon_to_cache route_cache_data

cdef from "route_cache_helper.cpp":
    route_cache_data load_cache(c_string filename)
    void dump_cache(route_cache_data cache, c_string filename)

cdef class RouteCache:

    route_cache_data cache
    cdef object _debug

    def __cinit__(self, _debug=False):
        pass

    def __init__(self, _debug=False):
        self._debug = _debug

    @cython.boundscheck(False)  # Deactivate bounds checking for lower overhead
    @cython.wraparound(False)  # Deactivate negative indexing for lower overhead
    cpdef cache_preprocess(self, src_lon, src_lat, dst_lon, dst_lat):
        """
        Synopsis:

          * Prepare the output matrix (columns: src, rows: dst).
          * Parallelize on `src`:
            * Get the src-specific cache (`_dst_lon_to_cache`)
            * Fill a column in the output matrix from cache.
          * Make a result dict:
            * `result_matrix`
            * `(new_src_lon, new_src_lat, new_dst_lon, new_dst_lat)`
              * coordinates with at least one unfilled result_matrix value
            * `(src_indexes, dst_indexes)`
              * arrays of at least the same length as new_src_*, new_dst_*,
                pointing to corresponding indexex of the src_*, dst_*
        """
        pieceses = [[src_lon_ar, src_lat_ar], [dst_lon_ar, dst_lat_ar]]
        for pieces in pieceses:
            for piece in pieces:
                assert isinstance(piece, numpy.ndarray), ("should be a numpy array here", piece)
                assert piece.dtype == DTYPE_PY
                assert len(piece.shape) == 1, "should be a 1-d array"
            assert pieces[0].shape[0] == pieces[1].shape[0], "should be of matching size"
        cdef Py_ssize_t srcs_size = src_lon_ar.shape[0]
        cdef Py_ssize_t dsts_size = dst_lon_ar.shape[0]

        result = numpy.full([srcs_size, dsts_size], np.nan, dtype=DTYPE_PY)

        # preallocate the indexmaps to the maximum size with 'zero' value
        src_indexes = numpy.full([srcs_size], -1, dtype=numpy.uiint64)
        dst_indexes = numpy.full([dsts_size], -1, dtype=numpy.uiint64)

        cdef DTYPE[:] src_lon_memview = src_lon_ar
        cdef DTYPE[:] src_lat_memview = src_lat_ar
        cdef DTYPE[:] dst_lon_memview = dst_lon_ar
        cdef DTYPE[:] dst_lat_memview = dst_lat_ar
        cdef DTYPE[:, :] result_memview = result

        cdef Py_ssize_t src_pos
        cdef Py_ssize_t dst_pos

        for src_pos in prange(src_size, nogil=True):
            cdef DTYPE src_lon = src_lon_ar[src_pos]
            cdef auto src_lon_cache_item = self.cache.find(src_lon)
            if src_lon_cache_item == self.cache.end():
                continue
            cdef auto src_lon_cache = src_lon_cache_item.second
            cdef DTYPE src_lat = src_lat_ar[src_pos]
            cdef auto src_cache_item = src_lon_cache.find(src_lat)
            if src_cache_item == src_lon_cache.end():
                continue
            cdef auto src_cache = src_cache_item.second
            for dst_pos in prange(dst_size):
                cdef DTYPE dst_lon = dst_lon_ar[dst_pos]
                cdef auto dst_lon_cache_item = src_cache.find(dst_lon)
                if dst_lon_cache_item == src_cache.end():
                    continue
                auto dst_lon_cache = dst_lon_cache_item.second
                cdef DTYPE dst_lat = dst_lat_ar[dst_pos]
                cdef auto dst_cache_item = dst_lon_cache.find(dst_lat)
                if dst_cache_item == dst_lon_cache.end():
                    continue
                result_memview[src_pos, dst_pos] = dst_cache_item.second

        # ...
        # TODO: new_(src|dst)_(lon|lat), (src|dst)_indexes
        raise Exception("TODO")

    @cython.boundscheck(False)  # Deactivate bounds checking for lower overhead
    @cython.wraparound(False)  # Deactivate negative indexing for lower overhead
    cpdef cache_update(
            self,
            cnumpy.ndarray src_lon_ar,
            cnumpy.ndarray src_lat_ar,
            cnumpy.ndarray dst_lon_ar,
            cnumpy.ndarray dst_lat_ar,
            cnumpy.ndarray results):
        """
        Given the arguments and the result of `route_matrix`,
        update the cache.

        Synopsis:

          * Prefill the cache structure with src values.
            * self.cache lock
           * writes on the top two levels of `self.cache`.
          * Parallelize on src values:
            * get the single src cache
            * lock the single src cache
            * for each destination (row), update the single src cache
        """
        raise Exception("TODO")

    cpdef cache_postprocess(
            self,
            cnumpy.ndarray result_matrix,
            cnumpy.ndarray new_result_matrix,
            cnumpy.ndarray new_src_lon, cnumpy.ndarray new_src_lat,
            cnumpy.ndarray new_dst_lon, cnumpy.ndarray new_dst_lat,
            cnumpy.ndarray src_indexes,
            cnumpy.ndarray dst_indexes):
        """
        Given the output of `cache_preprocess` and
        `new_result_matrix` with the result of `route_matrix`,
        update the `result_matrix` to completion.

        Synopsis:

          * For each enumerated item of `new_result matrix`, in parallel:
            * Find the corresponding `result_matrix` indices
            * Put the value
          * Ensure the `result_matrix` has no default values (`np.nan` / `-1`).
        """
        raise Exception("TODO")

    cpdef load_cache(self, filename):
        self.cache = load_cache(filename)

    cpdef dump_cache(self, filename):
        dump_cache(self.cache, filename)

    # # TODO:
    # cdef __dealloc__(self):
    #     pass
