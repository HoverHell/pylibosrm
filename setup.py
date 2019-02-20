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
                "pylibosrm/osrm_wrapper.pyx"
            ],
            extra_compile_args=[
                '-fopenmp',
            ],
            extra_link_args=[
                '-fopenmp',
            ],
            include_dirs=[
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
