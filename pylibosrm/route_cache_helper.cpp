
#include <iostream>
#include <fstream>
#include <sstream>
#include <unordered_map>
#include <msgpack.hpp>

typedef std::unordered_map<double, double> _dst_lat_to_duration_seconds;
typedef std::unordered_map<double, _dst_lat_to_duration_seconds> _dst_lon_to_cache;
typedef std::unordered_map<double, _dst_lon_to_cache> _src_lat_to_cache;
typedef std::unordered_map<double, _src_lat_to_cache> _src_lon_to_cache;
typedef _src_lon_to_cache route_cache_data;


route_cache_data load_cache(std::string filename) {
    route_cache_data empty = {};
    std::ifstream fobj(filename);
    if (fobj.fail()) { return empty; }
    std::stringstream fstream;
    fstream << fobj.rdbuf();
    std::string fdata = fstream.str();
    if (fdata.size() == 0) { return empty; }
    auto objhandle = msgpack::unpack(fdata.data(), fdata.size());
    msgpack::object obj = objhandle.get();
    // XXXXX: this might segfault on even slightly not-up-to-taste structures.
    return obj.as<route_cache_data>();
}

void dump_cache(route_cache_data cache, std::string filename) {
    std::stringstream fstream;
    msgpack::pack(fstream, cache);
    std::ofstream fobj(filename);
    fobj << fstream.rdbuf();
}
