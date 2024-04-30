#!/usr/bin/env python

"""The setup script."""

from setuptools import setup, find_packages

with open('README.rst') as readme_file:
    readme = readme_file.read()

with open('HISTORY.rst') as history_file:
    history = history_file.read()

requirements = ['Click>=7.0', ]

test_requirements = [ ]

setup(
    author="Vijayvithal",
    author_email='jahagirdar.vs@gmail.com',
    python_requires='>=3.6',
    classifiers=[
        'Development Status :: 2 - Pre-Alpha',
        'Intended Audience :: Developers',
        'License :: OSI Approved :: BSD License',
        'Natural Language :: English',
        'Programming Language :: Python :: 3',
        'Programming Language :: Python :: 3.6',
        'Programming Language :: Python :: 3.7',
        'Programming Language :: Python :: 3.8',
    ],
    description="Bluespec SystemVerilog wrapper over peakrdl code",
    entry_points={
        'console_scripts': [
            'peakrdl_bsv=peakrdl_bsv.cli:main',
        ],
    },
    install_requires=requirements,
    license="BSD license",
    long_description=readme + '\n\n' + history,
    include_package_data=True,
    keywords='peakrdl_bsv',
    name='peakrdl_bsv',
    packages=find_packages(include=['peakrdl_bsv', 'peakrdl_bsv.*']),
    test_suite='tests',
    tests_require=test_requirements,
    url='https://github.com/jahagirdar/peakrdl_bsv',
    version='0.1.0',
    zip_safe=False,
)
