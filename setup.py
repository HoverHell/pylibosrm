#!/usr/bin/env python3

from setuptools import setup
from Cython.Build import cythonize
from distutils.extension import Extension

SETUP_KWARGS = dict(
    name='pylibosrm',
    version='0.1.0',
    packages=('pylibosrm',),
    url='https://github.com/HoverHell/pylibosrm',
    license='MIT',
    author='HoverHell',
    author_email='hoverhell@gmail.com',
    install_requires=(),
    tests_require=(),
    ext_modules=cythonize([
        Extension(
            "pylibosrm.osrm",
            sources=[
                # "pylibosrm/osrm.pxd",
                "pylibosrm/osrm.pyx"],

            # # TODO: build:
            # g++ -Wall -fexceptions -g \
            #     -I./osrm-backend/build \
            #     -I./osrm-backend \
            #     -I./osrm-backend/include \
            #     -I./osrm-backend/third_party/variant/include \
            #     -c wrapper.cpp -o wrapper.o
            # # TODO: link:
            # g++ \
            #     -L./osrm-backend/build \
            #     -L./osrm-backend \
            #     -o ./ ./wrapper.o \
            #     -static \
            #     -static-libgcc \
            #     ./osrm-backend/build/libosrm.a \
            #     /usr/lib/x86_64-linux-gnu/libboost_system.a \
            #     /usr/lib/x86_64-linux-gnu/libboost_iostreams.a \
            #     /usr/lib/x86_64-linux-gnu/libboost_filesystem.a \
            #     /usr/lib/x86_64-linux-gnu/libboost_thread.a \
            #     /usr/lib/x86_64-linux-gnu/librt.a \
            #     /usr/lib/x86_64-linux-gnu/libpthread.a

            include_dirs=[
                "./osrm-backend/include",
                "./osrm-backend/third_party/variant/include",
            ],
            libraries=[],
            language="c++",

        ),
    ]),
    description=(
        'libosrm Cython wrapper'),
    classifiers=(
        # https://github.com/HoverHell/python-pypi-template
        'License :: OSI Approved :: MIT License',
        'Development Status :: 2 - Pre-Alpha',
        # 'Development Status :: 3 - Alpha',
        # 'Development Status :: 4 - Beta',
        # 'Development Status :: 5 - Production/Stable',
        'Programming Language :: Python :: 3',
        'Programming Language :: Python :: 3 :: Only',
        'Programming Language :: Python :: 3.6',
        'Programming Language :: Python :: 3.7',
        'Programming Language :: Python :: 3.8',
        'Programming Language :: Python :: Implementation :: CPython',
        'Programming Language :: Python :: Implementation :: PyPy'))


if __name__ == '__main__':
    setup(**SETUP_KWARGS)
