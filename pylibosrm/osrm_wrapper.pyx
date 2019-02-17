# distutils: language = c++
# cython: language_level=3


cdef extern from "osrm_simple.cpp":
    struct osrm_holder_struct:
        pass
    struct route_result_struct:
        pass
    osrm_holder_struct *osrm_initialize(char *filename)
    route_result_struct osrm_route(
        osrm_holder_struct *osrm_holder,
        double from_lon, double from_lat,
        double to_lon, double to_lat
    )


class RouteException(Exception):
    """ ... """


cdef class OSRMWrapper:
    cdef osrm_holder_struct *osrm_holder;

    def __cinit__(self, str filename):
        cdef bytes filename_b = filename.encode('utf-8')
        self.osrm_holder = osrm_initialize(filename_b)

    def __init__(self, str filename):
        pass

    cpdef route_one(
        self,
        double from_lon, double from_lat,
        double to_lon, double to_lat,
        raise_errors=True):
        cdef route_result_struct route_result
        route_result = osrm_route(self.osrm_holder, from_lon, from_lat, to_lon, to_lat)
        if route_result.errors:
            if raise_errors:
                raise RouteException(route_result.errors)
            return dict(errors=route_result.errors)
        return dict(
            distance_meters=route_result.distance_meters,
            duration_seconds=route_result.duration_seconds,
        )

    # cdef __dealloc__(self):
    #     pass
