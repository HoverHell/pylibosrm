#!/bin/sh -x

echo " ======= python + debian-stretch"
docker run --rm python:3.7-stretch sh -c 'curl https://raw.githubusercontent.com/HoverHell/pylibosrm/master/_build_and_install.sh | sh -x'

echo " ======= ubuntu bionic"
docker run --rm -it ubuntu:18.04 bash -c 'apt -y update && apt -y install curl && curl https://raw.githubusercontent.com/HoverHell/pylibosrm/master/_build_and_install.sh | sh -x'

echo " ======= ubuntu xenial"
docker run --rm -it ubuntu:16.04 bash -c 'apt -y update && apt -y install curl && curl https://raw.githubusercontent.com/HoverHell/pylibosrm/master/_build_and_install.sh | sh -x'
