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

osrm_holder_t *osrm_initialize(const char *filename) {
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
  osrm::OSRM osrm{config};

  osrm_holder_t *osrm_holder;
  osrm_holder = (typeof(osrm_holder))malloc(sizeof(*osrm_holder));
  osrm_holder->osrm_obj = &osrm;
  return osrm_holder;
}


struct route_result_struct {
  double distance_meters = 0;
  double duration_seconds = 0;
  // char *errors;
  std::string errors = "";
};


route_result_struct osrm_route(
  osrm_holder_t *osrm_holder,
  double from_lon, double from_lat,
  double to_lon, double to_lat
) {
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

  // Execute routing request, this does the heavy lifting
  const osrm::OSRM *osrm_obj = static_cast<osrm::OSRM*>(osrm_holder->osrm_obj);

  const auto status = osrm_obj->Route(params, result);

  route_result_struct route_result;
  if (status == osrm::Status::Ok) {
    auto &routes = result.values["routes"].get<osrm::json::Array>();

    // Let's just use the first route
    auto &route = routes.values.at(0).get<osrm::json::Object>();
    route_result.distance_meters = route.values["distance"].get<osrm::json::Number>().value;
    route_result.duration_seconds = route.values["duration"].get<osrm::json::Number>().value;

    // Warn users if extract does not contain the default coordinates from above
    if (route_result.distance_meters == 0 || route_result.duration_seconds == 0) {
      // asprintf(&route_result.errors, "empty_result: Suspiciously empty distance / duration");
      route_result.errors = "empty_result: Suspiciously empty distance / duration";
    }

  } else if (status == osrm::Status::Error) {
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
  return route_result;
}
