# distutils: language = c++
# cython: language_level=3

from libc.stdint cimport uint64_t as uint64

from posix.time cimport timespec, clock_gettime, CLOCK_MONOTONIC, CLOCK_REALTIME

from libcpp cimport bool as c_bool
from libcpp.string cimport string as c_string
from libcpp.pair cimport pair as c_pair
from libcpp.unordered_map cimport unordered_map

cimport cython
from cython cimport view
from cython.parallel cimport prange
from cython.operator cimport dereference as deref

# from libcpp.iterator cimport iterator as c_iterator
cimport numpy as cnumpy

import os

import numpy

ctypedef cnumpy.uint64_t uint64_t
ctypedef cnumpy.float64_t DTYPE
DTYPE_PY = numpy.float64

ctypedef unordered_map[DTYPE, DTYPE] _dst_lat_to_duration_seconds
ctypedef unordered_map[DTYPE, _dst_lat_to_duration_seconds] _dst_lon_to_cache
ctypedef unordered_map[DTYPE, _dst_lon_to_cache] _src_lat_to_cache
ctypedef unordered_map[DTYPE, _src_lat_to_cache] _src_lon_to_cache
ctypedef _src_lon_to_cache route_cache_data


# cdef extern from "std_mutex.h":
cdef extern from "<mutex>" namespace "std" nogil:
    cdef cppclass mutex:
        void lock() except +
        c_bool try_lock() except +
        void unlock() except +


cdef extern from "route_cache_helper.cpp":
    cdef route_cache_data load_cache(c_string filename) nogil except +
    cdef void dump_cache(route_cache_data cache, c_string filename) nogil except +
    cdef cppclass MutexMap:
        # MutexMap() except +
        mutex* get_mutex(void* ptr) nogil except +
        size_t cleanup_mutexes() nogil except +
    cdef MutexMap MUTEX_MAP


# Note: this magic number is maxvalue of uint64
cpdef uint64 time_ns() except 18446744073709551615:
    # python 3.7+: `return time.time_ns()`
    cdef timespec ts
    cdef int errors
    errors = clock_gettime(CLOCK_REALTIME, &ts)
    if errors != 0:
        raise RuntimeError("clock_gettime(CLOCK_REALTIME, ...) error", errors)
    return <uint64>(ts.tv_sec) * 1000000000 + ts.tv_nsec


cpdef uint64 monotonic_ns() except 18446744073709551615:
    """
    python 3.7+: `return time.monotonic_ns()`

    python 3.3+ approximation: `return int(time.monotonic() * 1e9)`
    """
    cdef timespec ts
    cdef int errors
    errors = clock_gettime(CLOCK_MONOTONIC, &ts)
    if errors != 0:
        raise RuntimeError("clock_gettime(CLOCK_MONOTONIC, ...) error", errors)
    return <uint64>(ts.tv_sec) * 1000000000 + ts.tv_nsec


cpdef uint64 monotonic_adjustment() except 18446744073709551615:
    """
    Add this value to monotonic_ns() values
    to get close approximation of unixtime ns (`time_ns()`)
    """
    # It is what it is
    # monotonic_ns() + monotonic_adjustment() = time_ns()
    return time_ns() - monotonic_ns()


cpdef routes_score(routes):
    # TODO: a more realistic estimation.
    # (something about N×N routing being best-case proportional to N rather than N**2)
    result = 0
    for routing in routes:
        if not routing:
            continue
        result += (
            routing['postprocess_params']['src_indexes'].shape[0] *
            routing['postprocess_params']['dst_indexes'].shape[0])
    return result



cdef class RouteCache:
    """
    ...

    split_unrouted tuning params:

    `sur_too_flat` = 8
    If src size or dst size is equal or below this, consider the matrix
    'flat' and do not split by the lower dimension.

    `sur_split_quotient` = 0.85
    First-level select: rows/columns with amount of NaNs larger than
    `sur_split_quotient` of the entire peak-to-peak range.
    (which is, notably, different from a quantile in that it does not
    count the amount of each value's repetitions)
    """

    cdef route_cache_data cache
    cdef object _debug
    cdef object sur_too_flat
    cdef object sur_split_quotient

    def __cinit__(self, _debug=False):
        self.sur_too_flat = 8
        self.sur_split_quotient = 0.85

    def __init__(self, _debug=False):
        self._debug = _debug

    cpdef validate_params(
        self,
        cnumpy.ndarray src_lon_ar,
        cnumpy.ndarray src_lat_ar,
        cnumpy.ndarray dst_lon_ar,
        cnumpy.ndarray dst_lat_ar,
        cnumpy.ndarray result_matrix=None,
    ):
        pieceses = [
            [('src_lon_ar', src_lon_ar), ('src_lat_ar', src_lat_ar)],
            [('dst_lon_ar', dst_lon_ar), ('dst_lat_ar', dst_lat_ar)]]
        for pieces in pieceses:
            for name, piece in pieces:
                if not isinstance(piece, numpy.ndarray):
                    raise ValueError("Should be a numpy array here", name)
                if piece.dtype != DTYPE_PY:
                    raise ValueError("Invalid dtype", dict(name=name, got=piece.dtype, expected=DTYPE_PY))
                if piece.ndim != 1:
                    raise ValueError("Should be a 1-d array", name)
            if pieces[0][1].shape != pieces[1][1].shape:
                raise ValueError(
                    "Should be of matching sizes",
                    dict(names=(pieces[0][0], pieces[1][0])))

        if result_matrix is not None:
            name = "result_matrix"
            if result_matrix.ndim != 2:
                raise ValueError("Should be a 2-d array", name)
            src_size = src_lon_ar.shape[0]
            if result_matrix.shape[0] != src_size:
                raise ValueError(
                    "Rows count should match src_*_ar",
                    dict(name=name, expected=src_size, got=result_matrix.shape[0]))
            dst_size = dst_lon_ar.shape[0]
            if result_matrix.shape[1] != dst_size:
                raise ValueError(
                    "Columns count should match dst_*_ar",
                    dict(name=name, expected=dst_size, got=result_matrix.shape[1]))

    @cython.boundscheck(False)  # Deactivate bounds checking for lower overhead
    @cython.wraparound(False)  # Deactivate negative indexing for lower overhead
    cpdef route_from_cache(
            self,
            cnumpy.ndarray src_lon_ar,
            cnumpy.ndarray src_lat_ar,
            cnumpy.ndarray dst_lon_ar,
            cnumpy.ndarray dst_lat_ar,
            validate_args=True,
    ):
        """
        Make a route result matrix from cache.

        Synopsis:

          * Validate the inputs.
          * Prepare the output matrix (columns: src, rows: dst).
          * Parallelize on `src`:
            * Get the src-specific cache (`_dst_lon_to_cache`)
            * Fill a column in the output matrix from cache.
        """
        if validate_args:
            self.validate_params(
                src_lon_ar=src_lon_ar, src_lat_ar=src_lat_ar,
                dst_lon_ar=dst_lon_ar, dst_lat_ar=dst_lat_ar)

        cdef Py_ssize_t src_size = src_lon_ar.shape[0]
        cdef Py_ssize_t dst_size = dst_lon_ar.shape[0]

        result = numpy.full([src_size, dst_size], numpy.nan, dtype=DTYPE_PY)

        cdef DTYPE[:] src_lon_memview = src_lon_ar
        cdef DTYPE[:] src_lat_memview = src_lat_ar
        cdef DTYPE[:] dst_lon_memview = dst_lon_ar
        cdef DTYPE[:] dst_lat_memview = dst_lat_ar
        cdef DTYPE[:, :] result_memview = result

        # #######
        # The most time-consuming loop.
        # Making it as explicit as possible.
        # #######

        # loopvars
        cdef Py_ssize_t src_pos
        cdef Py_ssize_t dst_pos
        cdef DTYPE src_lon = 0
        cdef DTYPE src_lat = 0
        cdef DTYPE dst_lon = 0
        cdef DTYPE dst_lat = 0
        cdef unordered_map[DTYPE, _src_lat_to_cache].iterator src_lon_cache_item
        cdef _src_lat_to_cache * src_lon_cache
        cdef unordered_map[DTYPE, _dst_lon_to_cache].iterator src_cache_item
        cdef _dst_lon_to_cache * src_cache
        cdef unordered_map[DTYPE, _dst_lat_to_duration_seconds].iterator dst_lon_cache_item
        cdef _dst_lat_to_duration_seconds * dst_lon_cache
        cdef unordered_map[DTYPE, DTYPE].iterator dst_cache_item

        for src_pos in prange(src_size, nogil=True):
            src_lon = src_lon_memview[src_pos]
            src_lon_cache_item = self.cache.find(src_lon)
            if src_lon_cache_item == self.cache.end():
                continue
            src_lon_cache = &(deref(src_lon_cache_item).second)
            src_lat = src_lat_memview[src_pos]
            src_cache_item = src_lon_cache.find(src_lat)
            if src_cache_item == src_lon_cache.end():
                continue
            src_cache = &(deref(src_cache_item).second)
            for dst_pos in prange(dst_size):
                dst_lon = dst_lon_memview[dst_pos]
                dst_lon_cache_item = src_cache.find(dst_lon)
                if dst_lon_cache_item == src_cache.end():
                    continue
                dst_lon_cache = &(deref(dst_lon_cache_item).second)
                dst_lat = dst_lat_memview[dst_pos]
                dst_cache_item = dst_lon_cache.find(dst_lat)
                if dst_cache_item == dst_lon_cache.end():
                    continue
                result_memview[src_pos, dst_pos] = deref(dst_cache_item).second

        return result

    def split_unrouted(
            self,
            cnumpy.ndarray src_lon_ar,
            cnumpy.ndarray src_lat_ar,
            cnumpy.ndarray dst_lon_ar,
            cnumpy.ndarray dst_lat_ar,
            cnumpy.ndarray result_matrix,
            validate_args=True,
    ):
        """
        Given a partially filled route result matrix,
        make a least amount of routing parameterses needed to fill it
        (somehow taking into account that routing by one point is much slower
        than routing many-to-many)
        """
        if validate_args:
            self.validate_params(
                src_lon_ar=src_lon_ar, src_lat_ar=src_lat_ar,
                dst_lon_ar=dst_lon_ar, dst_lat_ar=dst_lat_ar,
                result_matrix=result_matrix)

        cdef Py_ssize_t src_size = src_lon_ar.shape[0]
        cdef Py_ssize_t dst_size = dst_lon_ar.shape[0]

        nans = numpy.isnan(result_matrix)

        # Simple case: nothing to route.
        if not nans.any():
            return [], 'nothing_to_route'

        def filtered_route(row_selector=None, col_selector=None, autoselect=True):
            if autoselect:
                if row_selector is not None and col_selector is None:
                    # If, after dropping the specified rows, some columns in
                    # the result are already filled, drop such columns.
                    col_selector = nans[row_selector].any(axis=0)
                elif col_selector is not None and row_selector is not None:
                    # If, after dropping the specified columns, some rows in
                    # the result are already filled, drop such rows.
                    row_selector = nans[:, col_selector].any(axis=1)
                elif col_selector is None and row_selector is None:
                    col_selector = nans.any(axis=0)
                    row_selector = nans.any(axis=1)

            res_src_indexes = numpy.arange(src_size, dtype=numpy.uint64)
            res_dst_indexes = numpy.arange(dst_size, dtype=numpy.uint64)

            # Emptiness-check:
            if row_selector is not None and not row_selector.any():
                return None
            if col_selector is not None and not col_selector.any():
                return None
            return dict(
                params=dict(
                    src_lon_ar=src_lon_ar[row_selector] if row_selector is not None else src_lon_ar,
                    src_lat_ar=src_lat_ar[row_selector] if row_selector is not None else src_lat_ar,
                    dst_lon_ar=dst_lon_ar[col_selector] if col_selector is not None else dst_lon_ar,
                    dst_lat_ar=dst_lat_ar[col_selector] if col_selector is not None else dst_lat_ar,
                ),
                postprocess_params=dict(
                    src_indexes=res_src_indexes[row_selector] if row_selector is not None else res_src_indexes,
                    dst_indexes=res_dst_indexes[col_selector] if col_selector is not None else res_dst_indexes,
                ),
            )

        route_full = filtered_route()

        # Simple case: route everything.
        if nans.all():
            return [route_full], 'everything_to_route'

        # # Copout option:
        # return [route_full]

        # Tricky: find a smallest amount of routings to perform.

        # Flat cases: drop filled rows / columns and route the rest.
        if src_size <= self.sur_too_flat:
            return [filtered_route(col_selector=nans.any(axis=0))], 'src_too_flat'
        if dst_size <= self.sur_too_flat:
            return [filtered_route(row_selector=nans.any(axis=1))], 'dst_too_flat'

        row_selector = nans.any(axis=1)
        col_selector = nans.any(axis=0)

        # One of the most interesting sample cases:
        # Most of the stuff is filled, except for a few rows and a few columns.
        # Expected result is: two routings, one filling most of the rows,
        # another filling the remaining columns. Or vice versa.
        # nans = numpy.random.random((17, 5)) < 0.05; nans[3] = True; nans[:, 1] = True

        to_route = []

        route_full_size = src_size * dst_size

        row_fullnans = nans.all(axis=1)
        col_fullnans = nans.all(axis=0)
        row_nans = nans.sum(axis=1)
        col_nans = nans.sum(axis=0)

        # Tee this class' docstring for some details.
        ssq = self.sur_split_quotient
        row_nans_edge = row_nans.max() * ssq + row_nans.min() * (1 - ssq)
        row_selector_b = (row_selector & (row_nans > row_nans_edge)) | row_fullnans

        col_nans_edge = col_nans.max() * ssq + col_nans.min() * (1 - ssq)
        col_selector_b = (col_selector & (col_nans > col_nans_edge)) | col_fullnans

        routeses = [
            ('full', [route_full]),
            ('rowfirst', [
                filtered_route(row_selector=row_selector_b),
                filtered_route(row_selector=~row_selector_b)]),
            ('colfirst', [
                filtered_route(col_selector=col_selector_b),
                filtered_route(col_selector=~col_selector_b)]),
        ]
        case, to_route = min(
            routeses,
            key=lambda item: routes_score(item[1]))

        return to_route, case

    @cython.boundscheck(False)  # Deactivate bounds checking for lower overhead
    @cython.wraparound(False)  # Deactivate negative indexing for lower overhead
    cpdef cache_update(
            self,
            cnumpy.ndarray src_lon_ar,
            cnumpy.ndarray src_lat_ar,
            cnumpy.ndarray dst_lon_ar,
            cnumpy.ndarray dst_lat_ar,
            cnumpy.ndarray new_result_matrix,
            validate_args=True,
    ):
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
        if validate_args:
            self.validate_params(
                src_lon_ar=src_lon_ar, src_lat_ar=src_lat_ar,
                dst_lon_ar=dst_lon_ar, dst_lat_ar=dst_lat_ar,
                result_matrix=new_result_matrix)

        cdef Py_ssize_t src_size = src_lon_ar.shape[0]
        cdef Py_ssize_t dst_size = dst_lon_ar.shape[0]

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
        cdef _dst_lon_to_cache * src_cache
        # cdef unordered_map[DTYPE, _dst_lat_to_duration_seconds].iterator dst_lon_cache_item
        # cdef _dst_lat_to_duration_seconds dst_lon_cache
        # cdef unordered_map[DTYPE, DTYPE].iterator dst_cache_item

        cdef mutex *cache_mutex = MUTEX_MAP.get_mutex(&self.cache)
        cdef mutex *src_cache_mutex

        with nogil:
            cache_mutex.lock()
            try:
                for src_pos in range(src_size):
                    src_lon = src_lon_memview[src_pos]
                    src_lat = src_lat_memview[src_pos]
                    # self.cache[src_lon][src_lat] = {}
                    self.cache[src_lon][src_lat]
            finally:
                cache_mutex.unlock()
            for src_pos in prange(src_size):
                # TODO?: use `….at(…).second` to ensure this is only-reading?
                src_lon = src_lon_memview[src_pos]
                src_lat = src_lat_memview[src_pos]
                src_cache = &self.cache[src_lon][src_lat]
                # NOTE: this complicated dynamic mutexing might actually not be necessary,
                # since it is not particularly useful to run multiple `cache_update`s in parallel.
                src_cache_mutex = MUTEX_MAP.get_mutex(&src_cache)
                src_cache_mutex.lock()
                try:
                    for dst_pos in range(dst_size):
                        dst_lon = dst_lon_memview[dst_pos]
                        dst_lat = dst_lat_memview[dst_pos]
                        deref(src_cache)[dst_lon][dst_lat] = results_memview[src_pos, dst_pos]
                finally:
                    src_cache_mutex.unlock()

    @staticmethod
    def drop_fake_nan(ar, negone=False):
        selection = ~numpy.isnan(ar)
        dtype = ar.dtype
        if dtype in (numpy.uint64, numpy.uint32, numpy.int64, numpy.int32):
            maxval = numpy.iinfo(dtype).max
            selection = selection & (ar != maxval)
        elif negone:
            selection = selection & (ar != -1)
        return ar[selection]

    @cython.boundscheck(False)  # Deactivate bounds checking for lower overhead
    @cython.wraparound(False)  # Deactivate negative indexing for lower overhead
    cpdef result_merge(
            self,
            cnumpy.ndarray result_matrix,
            cnumpy.ndarray new_result_matrix,
            cnumpy.ndarray src_lon_ar, cnumpy.ndarray src_lat_ar,
            cnumpy.ndarray dst_lon_ar, cnumpy.ndarray dst_lat_ar,
            cnumpy.ndarray src_indexes,
            cnumpy.ndarray dst_indexes,
            validate_args=True,
    ):
        """
        Given a `split_unrouted`'s item params and result matrices,
        fill `result_matrix` with items from `new_result_matrix`.

        Note: (src|dst)_(lon_lat)_ar must correspond to `new_result_matrix`.

        Synopsis:

          * Validate and clean the inputs.
          * For each enumerated item of `new_result_matrix`, in parallel:
            * Find the corresponding `result_matrix` indices.
            * Put the value.
        """
        if validate_args:
            self.validate_params(
                src_lon_ar=src_lon_ar, src_lat_ar=src_lat_ar,
                dst_lon_ar=dst_lon_ar, dst_lat_ar=dst_lat_ar,
                result_matrix=new_result_matrix)
            if src_indexes.ndim != 1 or src_indexes.shape[0] != new_result_matrix.shape[0]:
                raise ValueError("Invalid size of src_indexes")
            if dst_indexes.ndim != 1 or dst_indexes.shape[0] != new_result_matrix.shape[1]:
                raise ValueError("Invalid size of dst_indexes")

        cdef Py_ssize_t src_size = src_indexes.shape[0]
        cdef Py_ssize_t dst_size = dst_indexes.shape[0]
        cdef Py_ssize_t newres_row
        cdef Py_ssize_t newres_col
        cdef Py_ssize_t res_row
        cdef Py_ssize_t res_col
        cdef DTYPE[:, :] result_memview = result_matrix
        cdef DTYPE[:, :] new_result_memview = new_result_matrix
        cdef uint64_t[:] src_indexes_memview = src_indexes
        cdef uint64_t[:] dst_indexes_memview = dst_indexes

        for newres_row in prange(src_size, nogil=True):
            res_row = src_indexes_memview[newres_row]
            for newres_col in prange(dst_size):
                res_col = dst_indexes_memview[newres_col]
                result_memview[res_row, res_col] = new_result_memview[newres_row, newres_col]
        # ...

    cpdef load_cache(self, filename):
        if isinstance(filename, str):
            filename = filename.encode('utf-8')
        self.cache = load_cache(filename)

    cpdef dump_cache(self, filename):
        if isinstance(filename, str):
            filename = filename.encode('utf-8')
        dump_cache(self.cache, filename)

    cpdef route_matrix_verbose(
            self, osrm,
            cnumpy.ndarray src_lon_ar,
            cnumpy.ndarray src_lat_ar,
            cnumpy.ndarray dst_lon_ar,
            cnumpy.ndarray dst_lat_ar,
            update_cache=True):

        details = dict()
        cdef uint64 ts0 = monotonic_ns()
        cdef uint64 ts_adj = monotonic_adjustment()
        base_data = dict(
            src_lon_ar=src_lon_ar,
            src_lat_ar=src_lat_ar,
            dst_lon_ar=dst_lon_ar,
            dst_lat_ar=dst_lat_ar)
        cdef uint64 ts1 = monotonic_ns()
        result_matrix = self.route_from_cache(**base_data)
        cdef uint64 total_values = result_matrix.shape[0] * result_matrix.shape[1]
        cdef uint64 cached_values = total_values - numpy.isnan(result_matrix).sum()
        cdef uint64 ts2 = monotonic_ns()
        routings, routings_case = self.split_unrouted(
            result_matrix=result_matrix,
            **base_data)
        cdef uint64 ts3 = monotonic_ns()

        cdef uint64 routed_values = 0
        cdef uint64 time_routes = 0
        cdef uint64 time_cache_updates = 0
        cdef uint64 time_result_merges = 0
        cdef uint64 ts4_1 = 0
        cdef uint64 ts4_2 = 0
        cdef uint64 ts4_3 = 0
        cdef uint64 ts4_4 = 0

        # TODO?: prange? (might need to adjust for the timing counters though)
        for routing in routings:
            if not routing:
                continue
            routed_values += (
                routing['params']['src_lon_ar'].shape[0] *
                routing['params']['dst_lon_ar'].shape[0])
            ts4_1 = monotonic_ns()
            routing['params']['new_result_matrix'] = osrm.route_matrix(
                mode='duration_seconds',
                _debug=self._debug,
                **routing['params'])  # (src|dst)_(lon|lat)_ar=new_(src|dst)_(lon|lat)_ar,
            ts4_2 = monotonic_ns()
            time_routes += (ts4_2 - ts4_1)
            if update_cache:
                self.cache_update(**routing['params'])
            ts4_3 = monotonic_ns()
            time_cache_updates += (ts4_3 - ts4_2)
            # Will update `result_matrix` inplace:
            self.result_merge(
                result_matrix=result_matrix,
                **routing['params'],
                **routing['postprocess_params'])
            ts4_4 = monotonic_ns()
            time_result_merges += (ts4_4 - ts4_3)

        cdef uint64 ts5 = monotonic_ns()

        # Result check: should not have NaNs
        # (Note: routing failures are actually returned as `0.0`)
        assert not numpy.isnan(result_matrix).any()

        details = dict(
            timestamps=dict(
                ts_adj=ts_adj,
                ts0=ts0,
                ts1=ts1,
                ts2=ts2,
                ts3=ts3,
                # No point in adding ts4_* as they might as well be zero in this context.
            ),
            timings=dict(
                auxiliary_0=ts1 - ts0,
                route_from_cache=ts2 - ts1,
                split_unrouted=ts3 - ts2,
                routes=time_routes,
                cache_updates=time_cache_updates,
                result_merges=time_result_merges,
                routings_process=ts5 - ts3,
            ),
            datas=dict(
                base_data=base_data,
                result_matrix=result_matrix,
                routings=routings,
            ),
            routings_case=routings_case,
            cached_values=cached_values,
            routed_values=routed_values,
            total_values=total_values,
        )
        cdef uint64 ts6 = monotonic_ns()
        details['timings']['auxilary_1'] = ts6 - ts5
        details['timings']['total'] = ts6 - ts0
        return result_matrix, details

    def route_matrix(self, *args, **kwargs):
        result_matrix, _ = self.route_matrix_verbose(*args, **kwargs)
        return result_matrix

    # # TODO?:
    # cdef __dealloc__(self):
    #     pass
