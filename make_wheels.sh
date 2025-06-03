#!/usr/bin/bash

# This script builds the fxtran binary in a singularity container
# using a manylinux environment
# Then the executable is added to the bin directoy before building the wheel

set -e

VERSION=$(python3 <(cat src/pyfxtran/__init__.py; echo 'print(__version__)'))
FXTRAN_VERSION=$(python3 <(cat src/pyfxtran/__init__.py; echo 'print(FXTRAN_VERSION)'))
FXTRAN_REPO=$(python3 <(cat src/pyfxtran/__init__.py; echo 'print(FXTRAN_REPO)'))

ROOTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Get fxtran source code
function clone {
  previous=$PWD
  if [ -d "$1" ]; then
    rm -rf "$1"
  fi
  git clone $FXTRAN_REPO $1
  cd $1
  git checkout $FXTRAN_VERSION
  cd $previous
}

# Suppress pre-existing fxtran binary and source
rm -f $ROOTDIR/src/pyfxtran/bin/fxtran
rm -rf $ROOTDIR/src/pyfxtran/fxtran

# Build the source distribution without the fxtran binary
# but including fxtran source code
clone $ROOTDIR/src/pyfxtran/fxtran
cd $ROOTDIR
echo "graft src/pyfxtran/fxtran" > MANIFEST.in
python3 -m build --sdist -o wheelhouse/
rm -f MANIFEST.in
rm -rf $ROOTDIR/src/pyfxtran/fxtran
rm -rf build # needed to suppress reference to the fxtran module contained in the fxtran repository

# Temporary directory
export TMP_LOC=$(mktemp -d)
trap "\rm -rf $TMP_LOC" EXIT

# Containers
arch=$(python3 -c "import platform; print(platform.machine())")
if [ "$arch" == 'x86_64' ]; then
  container_uris="docker://quay.io/pypa/manylinux2014_x86_64 docker://quay.io/pypa/musllinux_1_2_x86_64"
else
  container_uris="docker://quay.io/pypa/manylinux2014_${arch}"
fi
for container_uri in $container_uris; do
  # Set up the container
  export CONTAINER_SIF_PATH="$TMP_LOC/$(echo $container_uri | awk -F '/' '{print $NF}').sif"
  singularity pull $CONTAINER_SIF_PATH $container_uri
  export CONTAINER_ROOT=/work
  export SINGULARITY_BINDPATH=$TMP_LOC:/work
  export REQUESTS_CA_BUNDLE=$TMP_LOC/ca-certificates.crt
  cp /etc/ssl/certs/ca-certificates.crt $TMP_LOC/ca-certificates.crt
  
  # Build fxtran inside the container
  rm -f $ROOTDIR/src/pyfxtran/bin/fxtran
  clone $TMP_LOC/fxtran
  cat - <<..EOF > $TMP_LOC/build_fxtran.sh
  cd /work/fxtran
  echo XXX \$(bash $ROOTDIR/src/pyfxtran/_get_make_options.sh)
  ldd --version
  make \$(bash $ROOTDIR/src/pyfxtran/_get_make_options.sh) all
..EOF
  chmod +x $TMP_LOC/build_fxtran.sh
  set +e # Build fails but executable is normally produced
  singularity run -i $CONTAINER_SIF_PATH /work/build_fxtran.sh
  set -e
  cp $TMP_LOC/fxtran/bin/fxtran $ROOTDIR/src/pyfxtran/bin/fxtran
  
  # Build the wheel inside the container to pick the right shared library
  cd $ROOTDIR
  cat - <<..EOF > $TMP_LOC/build_wheel.sh
  PY=/opt/python/cp310-cp310/bin
  \${PY}/python -m venv /work/env
  . /work/env/bin/activate
  \${PY}/pip install build auditwheel
  \${PY}/python -m build --wheel
  \${PY}/python -m auditwheel repair dist/pyfxtran-${VERSION}-py3-none-any.whl
..EOF
  chmod +x $TMP_LOC/build_wheel.sh
  singularity run -i $CONTAINER_SIF_PATH /work/build_wheel.sh
  
  # Cleaning
  rm -rf dist build
done
rm -f $ROOTDIR/src/pyfxtran/bin/fxtran
