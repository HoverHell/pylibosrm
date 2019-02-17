# distutils: language = c++
# cython: language_level=3

from libcpp cimport bool as c_bool
from libcpp.string cimport string as c_string

import os


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
    )


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
        cdef route_result_struct route_result
        cdef str errors
        route_result = osrm_route(self._osrm_obj, from_lon, from_lat, to_lon, to_lat, _debug=_debug)
        errors = (<bytes>(route_result.errors)).decode('utf-8', errors='replace')
        if errors:
            if raise_errors:
                raise RouteException(errors)
            return dict(errors=errors)
        return dict(
            distance_meters=route_result.distance_meters,
            duration_seconds=route_result.duration_seconds,
        )

    # cdef __dealloc__(self):
    #     pass
