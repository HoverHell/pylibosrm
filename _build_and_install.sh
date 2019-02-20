#!/bin/sh
# Everything including `clone`.

set -Eeu

if ! which sudo ; then sudo(){ "$@"; }; fi

sudo apt install -y \
     build-essential git cmake pkg-config \
     libbz2-dev libxml2-dev libzip-dev libboost-all-dev \
     lua5.2 liblua5.2-dev libtbb-dev \
     python3-dev

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT
cd "$workdir"

git clone --recurse-submodules https://github.com/HoverHell/pylibosrm.git
cd pylibosrm

./_build_osrm.sh

./setup.py build
./setup.py bdist_wheel
# ./setup.py install
pip install ./dist/*.whl
