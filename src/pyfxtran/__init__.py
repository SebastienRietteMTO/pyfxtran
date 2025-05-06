#!/usr/bin/env python3

"""
Lightweight wrapper around fxtran
"""

from pathlib import Path
import tempfile
import subprocess
import os
import shutil
import argparse

__version__ = '0.1.1'

FXTRAN_VERSION = 'd89af8c67cf2e134ed43b5e689d639a9e07215ff'
FXTRAN_REPO = 'https://github.com/pmarguinaud/fxtran.git'


def run(filename, options=None):
    """
    Main function: installs fxtran if not available, runs it and return the result
    :param filename: name of the FORTRAN file
    :param options: options (dict) to give to fxtran
    """

    parser = os.path.join(Path.home(), f'.fxtran_{FXTRAN_VERSION}')

    # Installation
    if not os.path.exists(parser):
        with tempfile.TemporaryDirectory() as tempdir:
            subprocess.run(['git', 'clone', f'{FXTRAN_REPO}', '.'], cwd=tempdir,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
            subprocess.run(['git', 'checkout', f'{FXTRAN_VERSION}'], cwd=tempdir,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
            with open(os.path.join(tempdir, 'src/makefile'), 'r', encoding='UTF-8') as makefile:
                content = makefile.readlines()
            for i, line in enumerate(content):
                if line.startswith('all: '):
                    line = line.replace('\n', ' ') + '$(TOP)/bin/fxtran_stat\n'
                    content[i] = line
            content += ['\n',
                        '$(TOP)/bin/fxtran_stat: FXTRAN_ALPHA.h fxtran.o $(TOP)/lib/libfxtran_stat.a\n',
                        '	@mkdir -p ../bin\n',
                        '	$(CC) -o $(TOP)/bin/fxtran_stat fxtran.o $(RPATH) -L$(TOP)/lib -lfxtran_stat $(LDFLAGS)\n',
                        '\n',
                        '$(TOP)/lib/libfxtran_stat.a: $(OBJ)\n',
                        '	cd cpp && make\n',
                        '	@mkdir -p ../lib\n',
                        '	ar -rs $(TOP)/lib/libfxtran_stat.a $(OBJ) cpp/*.o\n']

            with open(os.path.join(tempdir, 'src/makefile'), 'w', encoding='UTF-8') as makefile:
                makefile.writelines(content)
            # Compilation is known to produce an error due to perl
            # We do not check status but only the existence of the executable
            subprocess.run(['make', 'all'], cwd=tempdir,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
            if not os.path.exists(os.path.join(tempdir, 'bin/fxtran_stat')):
                raise RuntimeError('fxtran compilation has failed')
            shutil.move(os.path.join(tempdir, 'bin/fxtran_stat'), parser)

    # Execution
    return subprocess.run([parser, filename] + ([] if options is None else options),
                          stdout=subprocess.PIPE, check=True, encoding='UTF-8').stdout


def main():
    """
    Entry point to output on stdout the transformed version of a FORTRAN file
    :param filename: name of the FORTRAN file
    """
    parser = argparse.ArgumentParser()
    parser.add_argument('filename', help='FORTRAN file name')
    args = parser.parse_args()
    print(run(args.filename, ['-o', '-']))
