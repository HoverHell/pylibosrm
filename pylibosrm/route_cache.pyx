# distutils: language = c++
# cython: language_level=3

from libcpp cimport bool as c_bool
from libcpp.string cimport string as c_string
cimport cython
from cython cimport view
from cython.parallel cimport prange
from cython.operator cimport dereference as deref
from libcpp.unordered_map cimport unordered_map
from libcpp.pair cimport pair as c_pair
# from libcpp.iterator cimport iterator as c_iterator
cimport numpy as cnumpy
import numpy
import os

ctypedef cnumpy.uint64_t uint64_t
ctypedef cnumpy.float64_t DTYPE
DTYPE_PY = numpy.float64

ctypedef unordered_map[DTYPE, DTYPE] _dst_lat_to_duration_seconds
ctypedef unordered_map[DTYPE, _dst_lat_to_duration_seconds] _dst_lon_to_cache
ctypedef unordered_map[DTYPE, _dst_lon_to_cache] _src_lat_to_cache
ctypedef unordered_map[DTYPE, _src_lat_to_cache] _src_lon_to_cache
ctypedef _src_lon_to_cache route_cache_data


# cdef extern from "std_mutex.h":
cdef extern from "mutex":
    cdef cppclass mutex:
        pass


cdef extern from "route_cache_helper.cpp":
    cdef route_cache_data load_cache(c_string filename)
    cdef void dump_cache(route_cache_data cache, c_string filename)
    cdef cppclass MutexMap:
        # MutexMap() except +
        mutex* get_mutex(void* ptr)
        size_t cleanup_mutexes()
    cdef MutexMap MUTEX_MAP


cdef class RouteCache:

    cdef route_cache_data cache
    cdef object _debug

    def __cinit__(self, _debug=False):
        pass

    def __init__(self, _debug=False):
        self._debug = _debug

    @cython.boundscheck(False)  # Deactivate bounds checking for lower overhead
    @cython.wraparound(False)  # Deactivate negative indexing for lower overhead
    cpdef cache_preprocess(
            self,
            cnumpy.ndarray src_lon_ar,
            cnumpy.ndarray src_lat_ar,
            cnumpy.ndarray dst_lon_ar,
            cnumpy.ndarray dst_lat_ar):
        """
        Synopsis:

          * Validate the inputs.
          * Prepare the output matrix (columns: src, rows: dst).
          * Parallelize on `src`:
            * Get the src-specific cache (`_dst_lon_to_cache`)
            * Fill a column in the output matrix from cache.
          * Make a result dict:
            * `result_matrix`
            * `(new_src_lon_ar, new_src_lat_ar, new_dst_lon_ar, new_dst_lat_ar)`
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
        cdef Py_ssize_t src_size = src_lon_ar.shape[0]
        cdef Py_ssize_t dst_size = dst_lon_ar.shape[0]

        result = numpy.full([src_size, dst_size], numpy.nan, dtype=DTYPE_PY)

        # preallocate the indexmaps to the maximum size with 'zero' value
        src_indexes = numpy.full([src_size], -1, dtype=numpy.uiint64)
        dst_indexes = numpy.full([dst_size], -1, dtype=numpy.uiint64)

        cdef DTYPE[:] src_lon_memview = src_lon_ar
        cdef DTYPE[:] src_lat_memview = src_lat_ar
        cdef DTYPE[:] dst_lon_memview = dst_lon_ar
        cdef DTYPE[:] dst_lat_memview = dst_lat_ar
        cdef DTYPE[:, :] result_memview = result

        # loopvars
        cdef Py_ssize_t src_pos
        cdef Py_ssize_t dst_pos
        cdef DTYPE src_lon = 0
        cdef DTYPE src_lat = 0
        cdef DTYPE dst_lon = 0
        cdef DTYPE dst_lat = 0
        cdef unordered_map[DTYPE, _src_lat_to_cache].iterator src_lon_cache_item
        cdef _src_lat_to_cache src_lon_cache
        cdef unordered_map[DTYPE, _dst_lon_to_cache].iterator src_cache_item
        cdef _dst_lon_to_cache src_cache
        cdef unordered_map[DTYPE, _dst_lat_to_duration_seconds].iterator dst_lon_cache_item
        cdef _dst_lat_to_duration_seconds dst_lon_cache
        cdef unordered_map[DTYPE, DTYPE].iterator dst_cache_item

        # The most time-consuming loop. Making it as explicit as possible.
        for src_pos in prange(src_size, nogil=True):
            src_lon = src_lon_memview[src_pos]
            src_lon_cache_item = self.cache.find(src_lon)
            if src_lon_cache_item == self.cache.end():
                continue
            src_lon_cache = deref(src_lon_cache_item).second
            src_lat = src_lat_memview[src_pos]
            src_cache_item = src_lon_cache.find(src_lat)
            if src_cache_item == src_lon_cache.end():
                continue
            src_cache = deref(src_cache_item).second
            for dst_pos in prange(dst_size):
                dst_lon = dst_lon_memview[dst_pos]
                dst_lon_cache_item = src_cache.find(dst_lon)
                if dst_lon_cache_item == src_cache.end():
                    continue
                dst_lon_cache = deref(dst_lon_cache_item).second
                dst_lat = dst_lat_memview[dst_pos]
                dst_cache_item = dst_lon_cache.find(dst_lat)
                if dst_cache_item == dst_lon_cache.end():
                    continue
                result_memview[src_pos, dst_pos] = deref(dst_cache_item).second

        # ...
        # TODO: new_(src|dst)_(lon|lat), (src|dst)_indexes
        new_src_lon_ar = src_lon_ar
        new_src_lat_ar = src_lat_ar
        new_dst_lon_ar = dst_lon_ar
        new_dst_lat_ar = dst_lat_ar
        return dict(
            result_matrix=result,
            new_data=dict(
                src_lon_ar=new_src_lon_ar,
                src_lat_ar=new_src_lat_ar,
                dst_lon_ar=new_dst_lon_ar,
                dst_lat_ar=new_dst_lat_ar),
            src_indexes=src_indexes,
            dst_indexes=dst_indexes,
        )

    @cython.boundscheck(False)  # Deactivate bounds checking for lower overhead
    @cython.wraparound(False)  # Deactivate negative indexing for lower overhead
    cpdef cache_update(
            self,
            cnumpy.ndarray src_lon_ar,
            cnumpy.ndarray src_lat_ar,
            cnumpy.ndarray dst_lon_ar,
            cnumpy.ndarray dst_lat_ar,
            cnumpy.ndarray new_result_matrix):
        """
        Given the arguments and the result of `route_matrix`,
        update the cache.

        Synopsis:

          * Validate the inputs.
          * Prefill the cache structure with src values.
            * self.cache lock
            * writes on the top two levels of `self.cache`.
          * Parallelize on src values:
            * get the single src cache
            * lock the single src cache
            * for each destination (row), update the single src cache
        """
        pieceses = [[src_lon_ar, src_lat_ar], [dst_lon_ar, dst_lat_ar]]
        for pieces in pieceses:
            for piece in pieces:
                assert isinstance(piece, numpy.ndarray), ("should be a numpy array here", piece)
                assert piece.dtype == DTYPE_PY
                assert len(piece.shape) == 1, "should be a 1-d array"
                assert pieces[0].shape[0] == pieces[1].shape[0], "should be of matching size"
        cdef Py_ssize_t src_size = src_lon_ar.shape[0]
        cdef Py_ssize_t dst_size = dst_lon_ar.shape[0]
        assert new_result_matrix.shape[0] == src_size
        assert new_result_matrix.shape[1] == dst_size

        cdef DTYPE[:] src_lon_memview = src_lon_ar
        cdef DTYPE[:] src_lat_memview = src_lat_ar
        cdef DTYPE[:] dst_lon_memview = dst_lon_ar
        cdef DTYPE[:] dst_lat_memview = dst_lat_ar
        cdef DTYPE[:, :] results_memview = new_result_matrix

        cdef Py_ssize_t src_pos
        cdef Py_ssize_t dst_pos
        cdef DTYPE src_lon = 0
        cdef DTYPE src_lat = 0
        cdef DTYPE dst_lon = 0
        cdef DTYPE dst_lat = 0

        # cdef unordered_map[DTYPE, _src_lat_to_cache].iterator src_lon_cache_item
        # cdef _src_lat_to_cache src_lon_cache
        # cdef unordered_map[DTYPE, _dst_lon_to_cache].iterator src_cache_item
        cdef _dst_lon_to_cache src_cache
        # cdef unordered_map[DTYPE, _dst_lat_to_duration_seconds].iterator dst_lon_cache_item
        # cdef _dst_lat_to_duration_seconds dst_lon_cache
        # cdef unordered_map[DTYPE, DTYPE].iterator dst_cache_item

        cdef mutex *cache_mutex = MUTEX_MAP.get_mutex(&self.cache)
        cdef mutex *src_cache_mutex

        with nogil:
            with c_lock_guard(cache_mutex):
                for src_pos in range(src_size):
                    src_lon = src_lon_memview[src_pos]
                    src_lat = src_lat_memview[src_pos]
                    self.cache[src_lon][src_lat] = {}
            for src_pos in prange(src_size):
                src_lon = src_lon_memview[src_pos]
                src_lat = src_lat_memview[src_pos]
                src_cache = self.cache[src_lon][src_lat]
                # NOTE: this complicated dynamic mutexing might actually not be necessary,
                # since it is not particularly useful to run multiple `cache_update`s in parallel.
                src_cache_mutex = MUTEX_MAP.get_mutex(ref(src_cache))
                with c_lock_guard(src_cache_mutex):
                    for dst_pos in range(dst_size):
                        dst_lon = dst_lon_memview[dst_pos]
                        dst_lat = dst_lat_memview[dst_pos]
                        src_cache[dst_lon][dst_lat] = results_memview[src_pos, dst_pos]

    @staticmethod
    def drop_fake_nan(ar, negone=False):
        selection = ~numpy.isnan(ar)
        dtype = ar.dtype
        if dtype is numpy.uint64 or dtype is numpy.uint32:
            maxval = numpy.iinfo(dtype).max
            selection = selection | (ar != maxval)
        elif negone:
            selection = selection | (ar != -1)
        return ar[selection]

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

          * Validate and clean the inputs.
          * For each enumerated item of `new_result matrix`, in parallel:
            * Find the corresponding `result_matrix` indices
            * Put the value
          * Ensure the `result_matrix` has no default values (`np.nan` / `-1`).
        """
        raise Exception("TODO")

    cpdef load_cache(self, filename):
        if isinstance(filename, str):
            filename = filename.encode('utf-8')
        self.cache = load_cache(filename)

    cpdef dump_cache(self, filename):
        if isinstance(filename, str):
            filename = filename.encode('utf-8')
        dump_cache(self.cache, filename)

    cpdef route_matrix(
            self, osrm,
            cnumpy.ndarray src_lon_ar,
            cnumpy.ndarray src_lat_ar,
            cnumpy.ndarray dst_lon_ar,
            cnumpy.ndarray dst_lat_ar,
            update_cache=True):
        base_data = dict(
            src_lon_ar=src_lon_ar,
            src_lat_ar=src_lat_ar,
            dst_lon_ar=dst_lon_ar,
            dst_lat_ar=dst_lat_ar)
        data = self.cache_preprocess(**base_data)
        data['new_data']['new_result_matrix'] = osrm.route_matrix(
            mode='duration_seconds',
            _debug=self._debug,
            **data['new_data'])  # (src|dst)_(lon|lat)_ar=new_(src|dst)_(lon|lat)_ar,
        if update_cache:
            self.cache_update(**data['new_data'])
        result_matrix = data['result_matrix']
        # Will update `result_matrix` inplace:
        self.cache_postprocess(
            result_matrix=result_matrix,
            src_indexes=data['src_indexes'],
            dst_indexes=data['dst_indexes'],
            **data['new_data'])
        return result_matrix

    # # TODO?:
    # cdef __dealloc__(self):
    #     pass
