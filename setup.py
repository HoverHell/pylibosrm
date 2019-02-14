#!/usr/bin/env python3

from setuptools import setup


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
