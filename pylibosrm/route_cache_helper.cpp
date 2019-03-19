
#include <mutex>
#include <iostream>
#include <fstream>
#include <sstream>
#include <unordered_map>
#include <msgpack.hpp>

typedef std::unordered_map<double, double> _dst_lat_to_duration_seconds;
typedef std::unordered_map<double, _dst_lat_to_duration_seconds> _dst_lon_to_cache;
typedef std::unordered_map<double, _dst_lon_to_cache> _src_lat_to_cache;
typedef std::unordered_map<double, _src_lat_to_cache> _src_lon_to_cache;
/*  // Same as:
typedef std::unordered_map<
    double, // from_lon
    std::unordered_map<
        double,  // from_lat
        std::unordered_map<
            double,  // to_lon
            std::unordered_map<
                double,  // to_lat
                double  // duration_seconds
    >>>> route_cache_data;
*/
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

/* A hashmap of memory address -> mutex, to be used for the `_dst_lon_to_cache` variables. */
class MutexMap {
public:
    std::unordered_map<size_t, std::mutex*> mutexes;
    std::mutex self_mutex;

    std::mutex* get_mutex(void* ptr) {
        size_t ptr_value = reinterpret_cast<size_t>(ptr);
        std::lock_guard<std::mutex> lock(this->self_mutex);
        auto value = this->mutexes[ptr_value];
        if (! value) {
            value = new std::mutex();
            this->mutexes[ptr_value] = value;
        }
        return value;
    }

    /*
     * Delete all non-locked mutexes.
     *
     * Should generally not be done while 'get_mutex' is being used in another
     * thread: there is a possible race between a mutex being returned and it
     * getting locked, where it might get deleted by this method.
     */
    size_t cleanup_mutexes() {
        size_t result = 0;
        std::lock_guard<std::mutex>(this->self_mutex);
        auto mutexes = this->mutexes;
        auto iter = mutexes.begin();
        while (iter != mutexes.end()) {
            auto mutex = iter->second;
            if (mutex->try_lock()) {
                iter = mutexes.erase(iter);
                result++;
                mutex->unlock();
                delete mutex;
            } else {
                iter++;
            }
        }
        return result;
    }

};
MutexMap MUTEX_MAP;  // = new MutexMap();
