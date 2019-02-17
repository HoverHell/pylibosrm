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
            "pylibosrm.osrm_wrapper",
            sources=[
                # "pylibosrm/osrm.pxd",
                "pylibosrm/osrm_wrapper.pyx"],
            extra_compile_args=(
                # # libosrm.so building:
                # /usr/bin/c++
                # -DBOOST_FILESYSTEM_NO_DEPRECATED
                # -DBOOST_RESULT_OF_USE_DECLTYPE
                # -DBOOST_SPIRIT_USE_PHOENIX_V3
                # -DBOOST_TEST_DYN_LINK
                # -DOSRM_PROJECT_DIR=\\\"osrm-backend\\\"
                # -D_FILE_OFFSET_BITS=64
                # -D_LARGEFILE_SOURCE
                # -Iosrm-backend/include
                # -Iosrm-backend/build/include
                # -isystem osrm-backend/third_party/sol2
                # -isystem osrm-backend/third_party/variant/include
                # -isystem osrm-backend/third_party/rapidjson/include
                # -isystem osrm-backend/third_party/microtar/src
                # -isystem osrm-backend/third_party/geometry.hpp-0.9.2/include
                # -isystem osrm-backend/third_party/cheap-ruler-cpp-2.5.4/include
                # -isystem osrm-backend/third_party/protozero/include
                # -isystem osrm-backend/third_party/vtzero/include
                # -isystem osrm-backend/third_party/libosmium/include
                # -isystem /usr/include/lua5.3
                # -Werror=all
                # -Werror=extra
                # -Werror=uninitialized
                # -Werror=unreachable-code
                # -Werror=unused-variable
                # -Werror=unreachable-code
                # -Wno-error=cpp
                # -Wpedantic
                # -Werror=strict-overflow=1
                # -Wno-error=maybe-uninitialized
                # -U_FORTIFY_SOURCE
                # -D_FORTIFY_SOURCE=2
                # -iagnostics-color=auto
                # -fPIC
                # -ftemplate-depth=1024
                # -ffunction-sections
                # -ata-sections
                # -std=c++14
                # -O3
                # -DNDEBUG
                # -o
                # CMakeFiles/alias-bench.dir/alias.cpp.o
                # -c
                # osrm-backend/src/benchmarks/alias.cpp
            ),
            extra_link_args=(
                # # libosrm.so linking:
                # /usr/bin/c++
                # -fPIC
                # -Werror=all
                # -Werror=extra
                # -Werror=uninitialized
                # -Werror=unreachable-code
                # -Werror=unused-variable
                # -Werror=unreachable-code
                # -Wno-error=cpp
                # -Wpedantic
                # -Werror=strict-overflow=1
                # -Wno-error=maybe-uninitialized
                # -U_FORTIFY_SOURCE
                # -D_FORTIFY_SOURCE=2
                # -iagnostics-color=auto
                # -fPIC
                # -ftemplate-depth=1024
                # -ffunction-sections
                # -ata-sections
                # -std=c++14
                # -O3
                # -DNDEBUG
                # -fuse-ld=gold
                # -Wl,--disable-new-dtags
                # -fuse-ld=gold
                # -Wl,--disable-new-dtags
                # -Wl,--gc-sections
                # -Wl,-O1
                # -Wl,--hash-style=gnu
                # -Wl,--sort-common
                # -shared
                # -Wl,-soname,libosrm.so
                # -o libosrm.so
                #   CMakeFiles/osrm.dir/src/osrm/osrm.cpp.o
                #   CMakeFiles/ENGINE.dir/...
                # -lboost_regex
                # -lboost_date_time
                # -lboost_chrono
                # -lboost_filesystem
                # -lboost_iostreams
                # -lboost_thread
                # -lboost_system
                # -lpthread
                # -ltbb
                # -ltbbmalloc
                # -lrt
                # -lz

                # # experimenting:
                # '-Wl,-Bstatic',
                # '-lstdc++',
                # '-static-libgcc',
                # './osrm-backend/build/libosrm.a',
                # '/usr/lib/x86_64-linux-gnu/libboost_system.a',
                # '/usr/lib/x86_64-linux-gnu/libboost_iostreams.a',
                # '/usr/lib/x86_64-linux-gnu/libboost_filesystem.a',
                # '/usr/lib/x86_64-linux-gnu/libboost_thread.a',
                # '/usr/lib/x86_64-linux-gnu/librt.a',
                # '/usr/lib/x86_64-linux-gnu/libpthread.a',
                # '-Wl,-Bdynamic',
            ),
            # # example binary build:
            # g++ -Wall -fexceptions -g \
            #     -I./osrm-backend/build \
            #     -I./osrm-backend \
            #     -I./osrm-backend/include \
            #     -I./osrm-backend/third_party/variant/include \
            #     -c wrapper.cpp -o wrapper.o
            # # example binary link:
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

            include_dirs=(
                "./osrm-backend/include",
                "./osrm-backend/third_party/variant/include",
            ),
            library_dirs=(
                './osrm-backend/build',
            ),
            libraries=(
                ':libosrm.a',
                'boost_regex',
                'boost_date_time',
                'boost_chrono',
                'boost_filesystem',
                'boost_iostreams',
                'boost_thread',
                'boost_system',
                'pthread',
                'tbb',
                'tbbmalloc',
                'rt',
                'z',
            ),
            language="c++",

        ),
    ]),
    description=(
        'libosrm Cython wrapper'),
    classifiers=[
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
        'Programming Language :: Python :: Implementation :: PyPy',
    ])


if __name__ == '__main__':
    setup(**SETUP_KWARGS)
