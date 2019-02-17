# distutils: language = c++
# cython: language_level=3

from libcpp cimport bool as c_bool
from libcpp.string cimport string as c_string
cimport cython
from cython.parallel cimport prange
cimport numpy as cnumpy
import numpy
import os


# DTYPE = cnumpy.float64
ctypedef cnumpy.float64_t DTYPE
DTYPE_PY = numpy.float64


cdef extern from "osrm/osrm.hpp" namespace "osrm":
    cppclass OSRM:
        pass


cdef extern from "osrm_simple.cpp":
    struct route_result_struct:
        double distance_meters
        double duration_seconds
        c_string errors

    OSRM *osrm_initialize(char *filename, c_bool _debug)

    route_result_struct osrm_route(
        OSRM *osrm,
        double from_lon, double from_lat,
        double to_lon, double to_lat,
        c_bool _debug,
    ) nogil


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
            double from_lon, double from_lat,
            double to_lon, double to_lat,
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
                from_lon, from_lat, to_lon, to_lat,
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
    cpdef route_matrix(
            self,
            DTYPE[:] from_lon_ar, DTYPE[:] from_lat_ar,
            DTYPE[:] to_lon_ar, DTYPE[:] to_lat_ar,
            mode='duration_seconds', _debug=False):
        assert mode in ('duration_seconds', 'distance_meters')
        pieceses = [[from_lon_ar, from_lat_ar], [to_lon_ar, to_lat_ar]]
        for pieces in pieceses:
            for piece in pieces:
                # # It's a memoryview here already:
                # assert isinstance(piece, numpy.ndarray), ("should be a numpy array already", piece)
                # assert piece.dtype == DTYPE_PY
                assert len(piece.shape) == 1, "should be a 1-d array"
            assert pieces[0].shape[0] == pieces[1].shape[0], "should be of matching size"
        cdef Py_ssize_t froms_size = from_lon_ar.shape[0]
        cdef Py_ssize_t tos_size = to_lon_ar.shape[0]

        cdef int mode_c = 0 if mode == 'duration_seconds' else 1
        cdef c_bool _debug_c = _debug

        result = numpy.empty([froms_size, tos_size], dtype=DTYPE_PY)
        cdef Py_ssize_t froms_pos, tos_pos
        cdef OSRM *osrm = self._osrm_obj
        cdef route_result_struct route_result
        cdef double result_value
        cdef DTYPE[:, :] result_view = result
        for froms_pos in prange(froms_size, nogil=True):
            for tos_pos in prange(tos_size):
                route_result = osrm_route(
                    osrm,
                    from_lon_ar[froms_pos], from_lat_ar[froms_pos],
                    to_lon_ar[tos_pos], to_lat_ar[tos_pos],
                    _debug=_debug_c,
                )
                if mode_c == 0:
                    result_value = route_result.duration_seconds
                else:
                    result_value = route_result.distance_meters
                result_view[froms_pos, tos_pos] = result_value
        return result

    # # TODO:
    # cdef __dealloc__(self):
    #     pass
