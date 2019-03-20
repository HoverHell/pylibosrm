# distutils: language = c++
# cython: language_level=3

from libcpp cimport bool as c_bool
from libcpp.string cimport string as c_string
cimport cython
from cython cimport view
from cython.parallel cimport prange
cimport numpy as cnumpy
import numpy
import os


ctypedef cnumpy.uint64_t uint64_t

# ctypedef double DTYPE
# DTYPE_PY = numpy.double  # numpy.float64
ctypedef cnumpy.float64_t DTYPE
DTYPE_PY = numpy.float64


cdef extern from "osrm/osrm.hpp" namespace "osrm" nogil:
    cppclass OSRM:
        pass


cdef extern from "osrm_simple.cpp" nogil:
    struct route_result_struct:
        double distance_meters
        double duration_seconds
        c_string errors

    OSRM *osrm_initialize(char *filename, c_bool _debug) nogil except +

    route_result_struct osrm_route(
        OSRM *osrm,
        double src_lon, double src_lat,
        double dst_lon, double dst_lat,
        c_bool _debug,
    ) nogil except +

    c_string osrm_table(
        OSRM *osrm,
        uint64_t src_size, double[] src_lon, double[] src_lat,
        uint64_t dst_size, double[] dst_lon, double[] dst_lat,
        double[] route_result,
        int mode,
        c_bool _debug,
    ) nogil except +


class RouteException(Exception):
    """ ... """


cdef class OSRMWrapper:
    cdef OSRM *_osrm_obj
    cdef str filename
    cdef object _debug

    def __cinit__(self, str filename, _debug=False):
        if not os.path.exists(filename):
            raise Exception("Specified file does not exist", filename)
        cdef bytes filename_b = filename.encode('utf-8')
        self._osrm_obj = osrm_initialize(filename_b, _debug=_debug)

    def __init__(self, str filename, _debug=False):
        self.filename = filename
        self._debug = _debug

    cpdef route_one(
            self,
            double src_lon, double src_lat,
            double dst_lon, double dst_lat,
            raise_errors=True,
            _debug=None,
    ):
        if _debug is None:
            _debug = self._debug
        cdef c_bool _debug_c = _debug
        cdef route_result_struct route_result
        cdef str errors
        with nogil:
            route_result = osrm_route(
                self._osrm_obj,
                src_lon, src_lat, dst_lon, dst_lat,
                _debug=_debug_c)
        errors = (<bytes>(route_result.errors)).decode('utf-8', errors='replace')
        if errors:
            if raise_errors:
                raise RouteException(errors)
            return dict(errors=errors)
        return dict(
            distance_meters=route_result.distance_meters,
            duration_seconds=route_result.duration_seconds,
        )

    @cython.boundscheck(False)  # Deactivate bounds checking for lower overhead
    @cython.wraparound(False)  # Deactivate negative indexing for lower overhead
    cpdef route_matrix_by_one(
            self,
            DTYPE[:] src_lon_ar, DTYPE[:] src_lat_ar,
            DTYPE[:] dst_lon_ar, DTYPE[:] dst_lat_ar,
            mode='duration_seconds', _debug=False):
        """
        Route matrix by calling individual `route_one` without GIL.

        Faster for small sizes, automatically parallel.
        """
        assert mode in ('duration_seconds', 'distance_meters')
        pieceses = [[src_lon_ar, src_lat_ar], [dst_lon_ar, dst_lat_ar]]
        for pieces in pieceses:
            for piece in pieces:
                # # It's a memoryview here already:
                # assert isinstance(piece, numpy.ndarray), ("should be a numpy array already", piece)
                # assert piece.dtype == DTYPE_PY
                assert len(piece.shape) == 1, "should be a 1-d array"
            assert pieces[0].shape[0] == pieces[1].shape[0], "should be of matching size"
        cdef Py_ssize_t src_size = src_lon_ar.shape[0]
        cdef Py_ssize_t dst_size = dst_lon_ar.shape[0]

        cdef int mode_c = 115 if mode == 'duration_seconds' else 109
        cdef c_bool _debug_c = _debug

        result = numpy.empty([src_size, dst_size], dtype=DTYPE_PY)

        cdef OSRM *osrm = self._osrm_obj

        cdef Py_ssize_t src_pos
        cdef Py_ssize_t dst_pos
        cdef route_result_struct route_result
        cdef double result_value
        cdef DTYPE[:, :] result_memview = result
        for src_pos in prange(src_size, nogil=True):
            for dst_pos in prange(dst_size):
                route_result = osrm_route(
                    osrm,
                    src_lon_ar[src_pos], src_lat_ar[src_pos],
                    dst_lon_ar[dst_pos], dst_lat_ar[dst_pos],
                    _debug=_debug_c,
                )
                if mode_c == 115:
                    result_value = route_result.duration_seconds
                elif mode_c == 109:
                    result_value = route_result.distance_meters
                else:
                    result_value = -1
                result_memview[src_pos, dst_pos] = result_value

        return result

    @cython.boundscheck(False)  # Deactivate bounds checking for lower overhead
    @cython.wraparound(False)  # Deactivate negative indexing for lower overhead
    cpdef route_matrix(
            self,
            cnumpy.ndarray src_lon_ar, cnumpy.ndarray src_lat_ar,
            cnumpy.ndarray dst_lon_ar, cnumpy.ndarray dst_lat_ar,
            mode='duration_seconds', _debug=False):

        if _debug:
            print("route_matrix: prepare...")

        assert mode in ('duration_seconds', 'distance_meters')
        pieceses = [[src_lon_ar, src_lat_ar], [dst_lon_ar, dst_lat_ar]]
        for pieces in pieceses:
            for piece in pieces:
                # # It's a memoryview here already:
                # assert isinstance(piece, numpy.ndarray), ("should be a numpy array already", piece)
                # assert piece.dtype == DTYPE_PY
                assert len(piece.shape) == 1, "should be a 1-d array"
            assert pieces[0].shape[0] == pieces[1].shape[0], "should be of matching size"
        cdef Py_ssize_t src_size = src_lon_ar.shape[0]
        cdef Py_ssize_t dst_size = dst_lon_ar.shape[0]

        cdef int mode_c = 115 if mode == 'duration_seconds' else 109
        cdef c_bool _debug_c = _debug
        cdef OSRM *osrm = self._osrm_obj

        result = numpy.empty([src_size, dst_size], dtype=DTYPE_PY)

        if not src_lon_ar.flags['C_CONTIGUOUS']:
            src_lon_ar = numpy.ascontiguousarray(src_lon_ar)
        if not src_lat_ar.flags['C_CONTIGUOUS']:
            src_lat_ar = numpy.ascontiguousarray(src_lat_ar)
        if not dst_lon_ar.flags['C_CONTIGUOUS']:
            dst_lon_ar = numpy.ascontiguousarray(dst_lon_ar)
        if not dst_lat_ar.flags['C_CONTIGUOUS']:
            dst_lat_ar = numpy.ascontiguousarray(dst_lat_ar)
        if not result.flags['C_CONTIGUOUS']:
            result = numpy.ascontiguousarray(result)

        cdef DTYPE[::view.contiguous] src_lon_memview = src_lon_ar
        cdef DTYPE[::view.contiguous] src_lat_memview = src_lat_ar
        cdef DTYPE[::view.contiguous] dst_lon_memview = dst_lon_ar
        cdef DTYPE[::view.contiguous] dst_lat_memview = dst_lat_ar
        cdef DTYPE[:, ::view.contiguous] result_memview = result
        # Each row is of `dst_size` elements:
        assert result_memview.strides[0] / result_memview.itemsize == dst_size, dict(
            strides=result_memview.strides, itemsize=result_memview.itemsize, src_size=src_size, dst_size=dst_size)
        # Each column within row is next to each other:
        assert result_memview.strides[1] / result_memview.itemsize == 1, dict(
            strides=result_memview.strides, itemsize=result_memview.itemsize, src_size=src_size, dst_size=dst_size)

        cdef c_string c_errors

        if _debug:
            print("route_matrix: src_lon:", src_lon_ar)
            print("route_matrix: src_lat:", src_lat_ar)
            print("route_matrix: dst_lon:", dst_lon_ar)
            print("route_matrix: dst_lat:", dst_lat_ar)
            print("route_matrix: nogil...")

        with nogil:
            c_errors = osrm_table(
                osrm,
                src_size=src_size, src_lon=&src_lon_memview[0], src_lat=&src_lat_memview[0],
                dst_size=dst_size, dst_lon=&dst_lon_memview[0], dst_lat=&dst_lat_memview[0],
                route_result=&result_memview[0, 0],
                mode=mode_c,
                _debug=_debug_c)

        if _debug:
            print("route_matrix: postprocess...")

        errors = (<bytes>(c_errors)).decode('utf-8', errors='replace')
        if errors:
            raise RouteException(errors)

        if _debug:
            print("route_matrix: done.")

        return result

    # # TODO:
    # cdef __dealloc__(self):
    #     pass
