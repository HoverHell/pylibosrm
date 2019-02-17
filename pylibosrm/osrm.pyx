# distutils: language = c++
# cython: language_level=3

from libcpp cimport bool as cbool
from libcpp.string cimport string as std_string
from libcpp.vector cimport vector as std_vector

# # cpp wrapping example:
# cdef extern from "Rectangle.h" namespace "shapes":
#     cdef cppclass Rectangle:
#         Rectangle(int, int, int, int)
# cdef Rectangle *rec = new Rectangle(1, 2, 3, 4)
# del rec #delete heap allocated object

# # original includes:
# #include "osrm/match_parameters.hpp"
# #include "osrm/nearest_parameters.hpp"
# #include "osrm/route_parameters.hpp"
# #include "osrm/table_parameters.hpp"
# #include "osrm/trip_parameters.hpp"

# #include "osrm/coordinate.hpp"
cdef extern from "osrm/coordinate.hpp" namespace "osrm":
    struct Coordinate:
        pass
    struct FloatLatitude:
        pass
    struct FloatLongitude:
        pass

# #include "osrm/engine_config.hpp"


cdef extern from "osrm/engine_config.hpp" namespace "EngineConfig":
    cdef cppclass Algorithm:
        pass


cdef extern from "osrm/engine_config.hpp" namespace "EngineConfig::Algorithm":
    cdef Algorithm CH
    cdef Algorithm CoreCH  # "Deprecated, will be removed in v6.0"
    cdef Algorithm MLD


cdef extern from "osrm/storage_config.hpp" namespace "osrm":
    struct StorageConfig:
        pass


cdef extern from "boost/filesystem/path.hpp" namespace "boost::filesystem":
    cdef cppclass path:
        path(const std_string& s)


cdef extern from "osrm/engine_config.hpp" namespace "osrm":
    cdef struct EngineConfig:
        # bool IsValid() const

        # enum class Algorithm:
        #     CH
        #     CoreCH // Deprecated, will be removed in v6.0
        #     MLD

        StorageConfig storage_config
        int max_locations_trip
        int max_locations_viaroute
        int max_locations_distance_table
        int max_locations_map_matching
        double max_radius_map_matching
        int max_results_nearest
        int max_alternatives
        cbool use_shared_memory
        path memory_file
        cbool use_mmap
        Algorithm algorithm
        std_string verbosity
        std_string dataset_name



# #include "osrm/json_container.hpp"
cdef extern from "osrm/json_container.hpp" namespace "osrm::json":
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
    cdef cppclass RouteParameters:
        pass
        # ...
        std_vector[Coordinate] coordinates



cdef extern from "osrm/osrm.hpp" namespace "osrm":
    cdef cppclass OSRM:
        OSRM(EngineConfig)
        # ...
        Status Route(RouteParameters &, Object &)


# #include "osrm/status.hpp"
cdef extern from "osrm/status.hpp" namespace "osrm":
    cdef cppclass Status:
        pass

cdef extern from "osrm/status.hpp" namespace "osrm::Status":
    cdef Status Ok
    cdef Status Error


# #include <exception>
# #include <iostream>
# #include <string>
# #include <utility>

# #include <cstdlib>

import sys


# int main(int argc, const char *argv[])
def main():
    # if (argc < 2) {
    #     std::cerr << "Usage: " << argv[0] << " data.osrm\n";
    #     return EXIT_FAILURE; }
    #     using namespace osrm;
    filename = sys.argv[1]
    # // Configure based on a .osrm base path, and no datasets in shared mem from osrm-datastore
    # EngineConfig config;
    cdef EngineConfig config
    # config.storage_config = {argv[1]};
    cdef std_string path_str
    path_stdstr = filename
    cdef path* storage_path = new path(path_stdstr)
    cdef StorageConfig storage_config
    storage_config = StorageConfig(storage_path)
    config.storage_config = storage_config
    # config.use_shared_memory = false;
    config.use_shared_memory = False
    # // We support two routing speed up techniques:
    # // - Contraction Hierarchies (CH): requires extract+contract pre-processing
    # // - Multi-Level Dijkstra (MLD): requires extract+partition+customize pre-processing
    # //
    # // config.algorithm = EngineConfig::Algorithm::CH;
    # config.algorithm = EngineConfig::Algorithm::MLD;
    config.algorithm = MLD
    # config.algorithm = Algorithm.MLD
    # // Routing machine with several services (such as Route, Table, Nearest, Trip, Match)
    # const OSRM osrm{config};
    cdef OSRM* osrm_obj = new OSRM(config)

    # // The following shows how to use the Route service; configure this service
    # RouteParameters params;
    cdef RouteParameters params;

    # // Route in monaco
    # params.coordinates.push_back({util::FloatLongitude{7.419758}, util::FloatLatitude{43.731142}});
    params.coordinates.push_back(Coordinate(FloatLongitude(7.419758), FloatLatitude(43.731142)))
    # params.coordinates.push_back({util::FloatLongitude{7.419505}, util::FloatLatitude{43.736825}});
    params.coordinates.push_back(Coordinate(FloatLongitude(7.419505), FloatLatitude(43.736825)))

    # // Response is in JSON format
    # json::Object result;
    cdef Object result

    # // Execute routing request, this does the heavy lifting
    # const auto status = Route(params, result);
    cdef Status status = osrm_obj.Route(params, result)

    # if (status == Status::Ok) {
    if <int>status == <int> Ok:
        return handle_ok(result)
    # }
    # else if (status == Status::Error) {
    elif <int>status == <int>Error:
        return handle_error(result)
    else:
        raise Exception("Unknown status")
    # }
# }


cdef handle_ok(Object result):
    # auto &routes = result.values["routes"].get<json::Array>();
    # cdef Array routes = result.values["routes"].get<Array>()
    routes = result.values["routes"].get()

    # // Let's just use the first route
    # auto &route = routes.values.at(0).get<json::Object>();
    # cdef Object route = routes.values.at(0).get<Object>()
    route = routes.values.at(0).get()
    # const auto distance = route.values["distance"].get<json::Number>().value;
    # cdef Number distance = route.values["distance"].get<Number>().value
    distance = route.values["distance"].get().value
    # const auto duration = route.values["duration"].get<json::Number>().value;
    # cdef Number duration = route.values["duration"].get<Number>().value
    duration = route.values["duration"].get().value

    # // Warn users if extract does not contain the default coordinates from above
    # if (distance == 0 || duration == 0) {
    if distance == 0 or duration == 0:
        # std::cout << "Note: distance or duration is zero. ";
        # std::cout << "You are probably doing a query outside of the OSM extract.\n\n";
        print(
            "Note: distance or duration is zero. "
            "You are probably doing a query outside of the OSM extract.\n")
    # }

    # std::cout << "Distance: " << distance << " meter\n";
    print("Distance: {} meter".format(distance))
    # std::cout << "Duration: " << duration << " seconds\n";
    print("Duration: {} seconds".format(duration))
    # return EXIT_SUCCESS;
    return 0


def handle_error(result):
    # const auto code = result.values["code"].get<json::String>().value;
    # cdef String code = result.values["code"].get().value
    code = result.values["code"].get().value
    # const auto message = result.values["message"].get<json::String>().value;
    # cdef String message = result.values["message"].get().value
    message = result.values["message"].get().value

    # std::cout << "Code: " << code << "\n";
    print("Code:", code)
    # std::cout << "Message: " << code << "\n";
    print("Message:", message)
    # return EXIT_FAILURE;
    return 1


if __name__ == '__main__':
    sys.exit(main())
