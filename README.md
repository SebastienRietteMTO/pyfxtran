# pyfxtran

This package is a lightweight wrapper around fxtran (https://github.com/pmarguinaud/fxtran).

The goal is to produce a python package that can be distributed via pypi.
A better way would be to write a real python binding around fxtran.

Installation:
pip install pyfxtran

Usage:
import fxtran
result = fxtran.run(filename, kwargs)

Documentation:
The wrapper does not add any functionality over fxtran. Full documentation can
be found with the fxtran tool.

Notes:
On first use, pyfxtran will download fxtran and compile it. The executable is then stored
in the user's directory, its name begins with .fxtran and is followed by the fxtran version number.
