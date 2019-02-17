#include "osrm/match_parameters.hpp"
#include "osrm/nearest_parameters.hpp"
#include "osrm/route_parameters.hpp"
#include "osrm/table_parameters.hpp"
#include "osrm/trip_parameters.hpp"

#include "osrm/coordinate.hpp"
#include "osrm/engine_config.hpp"
#include "osrm/json_container.hpp"

#include "osrm/osrm.hpp"
#include "osrm/status.hpp"

#include <exception>
#include <iostream>
#include <string>
#include <utility>

#include <cstdlib>

// Additional struct-wrapper for easier Cythonability.
// struct osrm_holder_struct {
//   osrm::OSRM osrm_obj;
// };
struct osrm_holder_struct {
  void *osrm_obj;
};
typedef struct osrm_holder_struct osrm_holder_t;

typedef long long unsigned int ptr_t;


osrm::OSRM *osrm_initialize(const char *filename, bool _debug=false) {
  // Configure based on a .osrm base path, and no datasets in shared mem from osrm-datastore
  osrm::EngineConfig config;

  config.storage_config = {filename};
  config.use_shared_memory = false;

  // We support two routing speed up techniques:
  // - Contraction Hierarchies (CH): requires extract+contract pre-processing
  // - Multi-Level Dijkstra (MLD): requires extract+partition+customize pre-processing
  //
  // config.algorithm = osrm::EngineConfig::Algorithm::CH;
  config.algorithm = osrm::EngineConfig::Algorithm::MLD;

  // Routing machine with several services (such as Route, Table, Nearest, Trip, Match)
  osrm::OSRM *osrm = new osrm::OSRM(config);
  return osrm;
}


struct route_result_struct {
  double distance_meters = 0;
  double duration_seconds = 0;
  // char *errors;
  std::string errors = "";
};


route_result_struct osrm_route(
  osrm::OSRM *osrm,
  double from_lon, double from_lat,
  double to_lon, double to_lat,
  bool _debug=false
) {
  if (_debug) { std::cerr << "Initializing params...\n"; }
  // The following shows how to use the Route service; configure this service
  osrm::RouteParameters params;

  params.coordinates.push_back({
    osrm::util::FloatLongitude{from_lon},
    osrm::util::FloatLatitude{from_lat}});
  params.coordinates.push_back({
    osrm::util::FloatLongitude{to_lon},
    osrm::util::FloatLatitude{to_lat}});

  // Response is in JSON format
  osrm::json::Object result;

  if (_debug) { std::cerr << "osrm_simple.osrm_route: Calling Route()...\n"; }
  const auto status = osrm->Route(params, result);

  route_result_struct route_result;
  if (status == osrm::Status::Ok) {
    if (_debug) { std::cerr << "osrm_simple.osrm_route: Status Ok;\n"; }
    auto &routes = result.values["routes"].get<osrm::json::Array>();

    if (_debug) { std::cerr << "osrm_simple.osrm_route: Filling result from the first route...;\n"; }
    // Let's just use the first route
    auto &route = routes.values.at(0).get<osrm::json::Object>();
    route_result.distance_meters = route.values["distance"].get<osrm::json::Number>().value;
    route_result.duration_seconds = route.values["duration"].get<osrm::json::Number>().value;

    // Warn users if extract does not contain the default coordinates from above
    if (route_result.distance_meters == 0 || route_result.duration_seconds == 0) {
      if (_debug) { std::cerr << "osrm_simple.osrm_route: Result is empty;\n"; }
      // asprintf(&route_result.errors, "empty_result: Suspiciously empty distance / duration");
      route_result.errors = "empty_result: Suspiciously empty distance / duration";
    }

  } else if (status == osrm::Status::Error) {
    if (_debug) { std::cerr << "osrm_simple.osrm_route: Status is Error;\n"; }
    // asprintf(
    //   &route_result.errors,
    //   "error result: %s %s",
    //   result.values["code"].get<osrm::json::String>().value,
    //   result.values["message"].get<osrm::json::String>().value);
    route_result.errors = (
      "error result: " +
      result.values["code"].get<osrm::json::String>().value +
      " " +
      result.values["message"].get<osrm::json::String>().value);
  }
  if (_debug) { std::cerr << "osrm_simple.osrm_route: Returning.\n"; }
  return route_result;
}
