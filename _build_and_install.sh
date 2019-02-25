#!/bin/sh
# Everything including `clone`.

set -Eeu

if ! which sudo ; then sudo(){ "$@"; }; fi

sudo apt update -y
sudo apt install -y \
     build-essential git cmake pkg-config \
     libbz2-dev libxml2-dev libzip-dev libboost-all-dev \
     lua5.2 liblua5.2-dev libtbb-dev \
     python3 python3-dev python3-pip

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT
cd "$workdir"

git clone --recurse-submodules https://github.com/HoverHell/pylibosrm.git
cd pylibosrm

./_build_osrm.sh

if which pip; then
    PIP=pip
else
    PIP=pip3
fi

"$PIP" install Cython numpy

./setup.py build
./setup.py bdist_wheel
# ./setup.py install
"$PIP" install ./dist/*.whl
