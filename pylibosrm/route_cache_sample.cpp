
#include <vector>
#include <string>
#include <unordered_map>
#include <iostream>
#include <fstream>
#include <msgpack.hpp>


void example_msgpack_a() {
    // serializes this object.
    std::vector<std::string> vec;
    vec.push_back("Hello");
    vec.push_back("MessagePack");

    // serialize it into simple buffer.
    msgpack::sbuffer sbuf;
    msgpack::pack(sbuf, vec);

    // deserialize it.
    msgpack::object_handle oh =
        msgpack::unpack(sbuf.data(), sbuf.size());

    // print the deserialized object.
    msgpack::object obj = oh.get();
    std::cout << obj << std::endl;  //=> ["Hello", "MessagePack"]

    // convert it into statically typed object.
    std::vector<std::string> rvec;
    obj.convert(rvec);
}


class myclass {
private:
    std::string m_str;
    std::vector<int> m_vec;
public:
    MSGPACK_DEFINE(m_str, m_vec)
};

void example_msgpack_b() {
    std::vector<myclass> vec;
    // add some elements into vec...

    // you can serialize myclass directly
    msgpack::sbuffer sbuf;
    msgpack::pack(sbuf, vec);

    msgpack::object_handle oh =
        msgpack::unpack(sbuf.data(), sbuf.size());

    msgpack::object obj = oh.get();

    // you can convert object to myclass directly
    std::vector<myclass> rvec;
    obj.convert(rvec);
}


void example_unordered_map_a() {
    // Create an empty unordered_map
    std::unordered_map<std::string, int> wordMap;

    // Insert Few elements in map
    wordMap.insert( { "First", 1 });
    wordMap.insert(	{ "Second", 2 });
    wordMap.insert(	{ "Third", 3 });

    // Overwrite value of an element
    wordMap["Third"] = 8;

    // Iterate Over the unordered_map and display elements
    for (std::pair<std::string, int> element : wordMap) {
        std::cout << element.first << " :: " << element.second << std::endl;
    }
}

void example_msgpack_unordered_map(){
    std::unordered_map<std::string, int> m { {"ABC", 1}, {"DEF", 3} };
    std::stringstream ss;
    msgpack::pack(ss, m);

    auto oh = msgpack::unpack(ss.str().data(), ss.str().size());
    msgpack::object obj = oh.get();

    std::cout << obj << std::endl;
    assert(obj.as<decltype(m)>() == m);
}


/* ********************* */

typedef std::unordered_map<double, double> _to_lat_to_duration_seconds;
typedef std::unordered_map<double, _to_lat_to_duration_seconds> _to_lon_to_cache;
typedef std::unordered_map<double, _to_lon_to_cache> _from_lat_to_cache;
typedef std::unordered_map<double, _from_lat_to_cache> _from_lon_to_cache;
typedef _from_lon_to_cache route_cache_data;

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


route_cache_data load_cache(std::string filename="./_tstcache.msgp") {
    std::ifstream fobj(filename);
    std::stringstream fstream;
    fstream << fobj.rdbuf();
    std::string fdata = fstream.str();

    auto objhandle = msgpack::unpack(fdata.data(), fdata.size());
    msgpack::object obj = objhandle.get();

    std::cout << obj << std::endl;
    return obj.as<route_cache_data>();
}

void dump_cache(std::string filename="./_tstcache.msgp") {
    std::ofstream fobj(filename);
}

int main(){
    auto cache = load_cache();
}
