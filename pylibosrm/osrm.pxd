# distutils: language = c++
# cython: language_level=3

# # original includes:
# #include "osrm/match_parameters.hpp"
# #include "osrm/nearest_parameters.hpp"
# #include "osrm/route_parameters.hpp"
# #include "osrm/table_parameters.hpp"
# #include "osrm/trip_parameters.hpp"

# #include "osrm/coordinate.hpp"
cdef extern from "osrm/coordinate.hpp" namespace "osrm":
    struct FloatLatitude:
        pass
    struct FloatLongitude:
        pass

# #include "osrm/engine_config.hpp"


cdef extern from "osrm/engine_config.hpp" namespace "osrm":
    enum Algorithm:
        CH
        CoreCH  # "Deprecated, will be removed in v6.0"
        MLD


cdef extern from "osrm/engine_config.hpp" namespace "osrm":
    struct EngineConfig:
        pass
        # ...


# #include "osrm/json_container.hpp"
cdef extern from "osrm/json_container.hpp" namespace "osrm":
    struct Object:
        pass
    struct Array:
        pass
    struct String:
        pass
    struct Number:
        pass


# #include "osrm/osrm.hpp"
cdef extern from "osrm/osrm.hpp" namespace "osrm":
    struct RouteParameters:
        pass


cdef extern from "osrm/osrm.hpp" namespace "osrm":
    cdef cppclass OSRM:
        OSRM(EngineConfig)
        # ...
        Status Route(RouteParameters &, Object &)


# #include "osrm/status.hpp"
cdef extern from "osrm/status.hpp" namespace "osrm":
    enum Status:
        Ok
        Error

# #include <exception>
# #include <iostream>
# #include <string>
# #include <utility>

# #include <cstdlib>






