#!/bin/sh

set -Eeu

(
    cd osrm-backend
    mkdir -p build
    cd build
    cmake ..
    # -DBUILD_SHARED_LIBS=ON
    # -DENABLE_MASON=ON
    make
)
