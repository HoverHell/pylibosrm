
/*
 * A CPP wraper around OSRM library that simplifies the interfaced structures,
 * for easier integration with Cython.
 */

#include "osrm/match_parameters.hpp"
#include "osrm/nearest_parameters.hpp"
#include "osrm/route_parameters.hpp"
#include "osrm/table_parameters.hpp"
#include "osrm/trip_parameters.hpp"

#include "osrm/coordinate.hpp"
#include "osrm/engine_config.hpp"
#include "osrm/json_container.hpp"
#include "util/json_renderer.hpp"

#include "osrm/osrm.hpp"
#include "osrm/status.hpp"

#include <exception>
#include <iostream>
#include <string>
#include <utility>

#include <cstdlib>
#include <iomanip>

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
  config.max_locations_distance_table = 10000;  // max 10000x10000; default is 100x100;

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
  if (_debug) { std::cerr << "osrm_simple.osrm_route: Initializing params...\n"; }
  // The following shows how to use the Route service; configure this service
  osrm::RouteParameters params;

  params.coordinates.push_back({
    osrm::util::FloatLongitude{from_lon},
    osrm::util::FloatLatitude{from_lat}});
  params.coordinates.push_back({
    osrm::util::FloatLongitude{to_lon},
    osrm::util::FloatLatitude{to_lat}});

  // Response is in JSON-structure format
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


std::string osrm_table(
  osrm::OSRM *osrm,
  uint64_t from_size, double from_lon[], double from_lat[],
  uint64_t to_size, double to_lon[], double to_lat[],
  double route_result[],
  // ord('s') == 115 == duration_seconds;
  // ord('m') == 109 == distance_meters;
  int mode=115,
  bool _debug=false
) {
  if (_debug) { std::cerr << "osrm_simple.osrm_table: Initializing params...\n"; }

  std::string errors = "";
  osrm::TableParameters params;

  // params.coordinates current index.
  uint64_t counter = 0;
  uint64_t idx;

  if (mode == 115) {
    params.annotations = osrm::TableParameters::AnnotationsType::Duration;
  } else {
    params.annotations = osrm::TableParameters::AnnotationsType::Distance;
  }
  // params.annotations = osrm::TableParameters::AnnotationsType::All;

  for (idx = 0; idx < from_size; idx++) {
    params.coordinates.push_back({
        osrm::util::FloatLongitude{from_lon[idx]},
        osrm::util::FloatLatitude{from_lat[idx]}});
    params.sources.push_back(counter);
    // if (_debug) { std::cerr << "Source #" << idx << " @" << params.coordinates.size() << " (" << counter << "): " << std::fixed << std::setprecision(10) << from_lon[idx] << "," << from_lat[idx] << ".\n"; }
    counter++;
  }
  for (idx = 0; idx < to_size; idx++) {
    params.coordinates.push_back({
        osrm::util::FloatLongitude{to_lon[idx]},
        osrm::util::FloatLatitude{to_lat[idx]}});
    params.destinations.push_back(counter);
    // if (_debug) { std::cerr << "Destination #" << idx << ", @" << params.coordinates.size() << " (" << counter << "): " << std::fixed << std::setprecision(10) << to_lon[idx] << "," << to_lat[idx] << ".\n"; }
    counter++;
  }

  // Response is in JSON-structure format
  osrm::json::Object result;

  if (_debug) { std::cerr << "osrm_simple.osrm_table: Calling Table()...\n"; }
  const auto status = osrm->Table(params, result);

  if (status == osrm::Status::Ok) {
    if (_debug) { std::cerr << "osrm_simple.osrm_table: Status Ok;\n"; }

    const auto &result_array = result.values.at(mode == 115 ? "durations" : "distances").get<osrm::json::Array>().values;
    // if (_debug) { std::cerr << "osrm_simple.osrm_table: result JSON:"; osrm::util::json::render(std::cerr, result); std::cerr << "\n"; }
    if (_debug) { std::cerr << "osrm_simple.osrm_table: result array size: " << result_array.size() << ";\n"; }
    if (result_array.size() != from_size) {
      return "Internal error: Result array size mismatch: expected " +
        std::to_string(from_size) +
        ", got " +
        std::to_string(result_array.size()) + ".\n"; }
    for (uint64_t from_idx = 0; from_idx < result_array.size(); from_idx++) {
      const auto result_matrix = result_array[from_idx].get<osrm::json::Array>().values;
      if (_debug) { if (from_idx == 0) { std::cerr << "osrm_simple.osrm_table: result array row size: " << result_matrix.size() << ";\n"; }; }
      if (result_matrix.size() != to_size) {
        return "Internal error: Result row size mismatch: expected " +
          std::to_string(to_size) +
          ", got " +
          std::to_string(result_matrix.size()) + ".\n"; }
      for (uint64_t to_idx = 0; to_idx < result_matrix.size(); to_idx++) {
        // rows are `from`s, each row is of `to_size` elements.
        route_result[from_idx * to_size + to_idx] = result_matrix[to_idx].get<osrm::json::Number>().value;
      }
    }

  } else if (status == osrm::Status::Error) {
    if (_debug) { std::cerr << "osrm_simple.osrm_table: Status is Error;\n"; }
    // asprintf(
    //   &route_result.errors,
    //   "error result: %s %s",
    //   result.values["code"].get<osrm::json::String>().value,
    //   result.values["message"].get<osrm::json::String>().value);
    errors = (
      "error result: " +
      result.values["code"].get<osrm::json::String>().value +
      " " +
      result.values["message"].get<osrm::json::String>().value);
  }

  if (_debug) { std::cerr << "osrm_simple.osrm_table: Returning.\n"; }
  return errors;
}
