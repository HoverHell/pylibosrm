#!/usr/bin/env python3

from setuptools import setup
from Cython.Build import cythonize
from distutils.extension import Extension
import numpy


EXT_COMMON = dict(
    language="c++",
    extra_compile_args=[
        '-fopenmp',
        '-std=c++14',
    ],
    extra_link_args=[
        '-fopenmp',
    ],
)

SETUP_KWARGS = dict(
    name='pylibosrm',
    version='0.1.2',
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
            sources=["pylibosrm/osrm_wrapper.pyx"],
            # sources=["pylibosrm/osrm_wrapper.pyx", "pylibosrm/osrm_simple.cpp"],
            include_dirs=[
                numpy.get_include(),
                "./osrm-backend/include",
                "./osrm-backend/third_party/variant/include",
            ],
            library_dirs=[
                './osrm-backend/build',
            ],
            libraries=[
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
            ],
            **EXT_COMMON),
        Extension(
            "pylibosrm.route_cache",
            sources=["pylibosrm/route_cache.pyx"],
            # sources=["pylibosrm/route_cache.pyx", "pylibosrm/route_cache_helper.cpp"],
            include_dirs=[
                numpy.get_include(),
                './msgpack-c/include/',
            ],
            library_dirs=[
            ],
            libraries=[
            ],
            **EXT_COMMON),
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
