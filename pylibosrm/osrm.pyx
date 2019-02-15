# distutils: language = c++
# cython: language_level=3

# # cpp wrapping example:
# cdef extern from "Rectangle.h" namespace "shapes":
#     cdef cppclass Rectangle:
#         Rectangle(int, int, int, int)
# cdef Rectangle *rec = new Rectangle(1, 2, 3, 4)
# del rec #delete heap allocated object

from . cimport osrm

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
    cdef osrm.EngineConfig config
    # config.storage_config = {argv[1]};
    config.storage_config = [filename]
    # config.use_shared_memory = false;
    config.use_shared_memory = False
    # // We support two routing speed up techniques:
    # // - Contraction Hierarchies (CH): requires extract+contract pre-processing
    # // - Multi-Level Dijkstra (MLD): requires extract+partition+customize pre-processing
    # //
    # // config.algorithm = EngineConfig::Algorithm::CH;
    # config.algorithm = EngineConfig::Algorithm::MLD;
    config.algorithm = osrm.MLD
    # config.algorithm = osrm.Algorithm.MLD
    # // Routing machine with several services (such as Route, Table, Nearest, Trip, Match)
    # const OSRM osrm{config};
    cdef osrm.OSRM* osrm_obj = new osrm.OSRM(config)

    # // The following shows how to use the Route service; configure this service
    # RouteParameters params;
    cdef osrm.RouteParameters params;

    # // Route in monaco
    # params.coordinates.push_back({util::FloatLongitude{7.419758}, util::FloatLatitude{43.731142}});
    params.coordinates.push_back([osrm.FloatLongitude(7.419758), osrm.FloatLatitude(43.731142)])
    # params.coordinates.push_back({util::FloatLongitude{7.419505}, util::FloatLatitude{43.736825}});
    params.coordinates.push_back([osrm.FloatLongitude(7.419505), osrm.FloatLatitude(43.736825)])

    # // Response is in JSON format
    # json::Object result;
    cdef osrm.Object result

    # // Execute routing request, this does the heavy lifting
    # const auto status = osrm.Route(params, result);
    cdef osrm.Status status = osrm_obj.Route(params, result)

    # if (status == Status::Ok) {
    if status == osrm.Status.Ok:
        return handle_ok(result)
    # }
    # else if (status == Status::Error) {
    elif status == osrm.Status.Error:
        return handle_error(result)
    else:
        raise Exception("Unknown status")
    # }
# }


cdef handle_ok(osrm.Object result):
    # auto &routes = result.values["routes"].get<json::Array>();
    # cdef osrm.Array routes = result.values["routes"].get<osrm.Array>()
    routes = result.values["routes"].get()

    # // Let's just use the first route
    # auto &route = routes.values.at(0).get<json::Object>();
    # cdef osrm.Object route = routes.values.at(0).get<osrm.Object>()
    route = routes.values.at(0).get()
    # const auto distance = route.values["distance"].get<json::Number>().value;
    # cdef osrm.Number distance = route.values["distance"].get<osrm.Number>().value
    distance = route.values["distance"].get().value
    # const auto duration = route.values["duration"].get<json::Number>().value;
    # cdef osrm.Number duration = route.values["duration"].get<osrm.Number>().value
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
    # cdef osrm.String code = result.values["code"].get().value
    code = result.values["code"].get().value
    # const auto message = result.values["message"].get<json::String>().value;
    # cdef osrm.String message = result.values["message"].get().value
    message = result.values["message"].get().value

    # std::cout << "Code: " << code << "\n";
    print("Code:", code)
    # std::cout << "Message: " << code << "\n";
    print("Message:", message)
    # return EXIT_FAILURE;
    return 1


if __name__ == '__main__':
    sys.exit(main())
