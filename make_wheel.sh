#!/usr/bin/bash

# This script builds the fxtran binary in a singularity container
# using a manylinux environment
# Then the executable is added to the bin directoy before building the wheel

set -e

# Temporary directory
export TMP_LOC=$(mktemp -d)
trap "\rm -rf $TMP_LOC" EXIT
ROOTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Get fxtran
FXTRAN_VERSION=$(python3 <(cat src/pyfxtran/__init__.py; echo 'print(FXTRAN_VERSION)'))
FXTRAN_REPO=$(python3 <(cat src/pyfxtran/__init__.py; echo 'print(FXTRAN_REPO)'))
git clone $FXTRAN_REPO $TMP_LOC/fxtran
cd $TMP_LOC/fxtran
git checkout $FXTRAN_VERSION

# Container
container_uri=docker://quay.io/pypa/manylinux2014_x86_64
export CONTAINER_SIF_PATH="$TMP_LOC/$(echo $container_uri | awk -F '/' '{print $NF}').sif"
singularity pull $CONTAINER_SIF_PATH $container_uri
export CONTAINER_ROOT=/work
export SINGULARITY_BINDPATH=$TMP_LOC:/work
export REQUESTS_CA_BUNDLE=$TMP_LOC/ca-certificates.crt
cp /etc/ssl/certs/ca-certificates.crt $TMP_LOC/ca-certificates.crt

# Build fxtran inside the container
cat - <<EOF > $TMP_LOC/build_fxtran.sh
cd /work/fxtran
make STATIC=1
EOF
chmod +x $TMP_LOC/build_fxtran.sh
set +e # Build fails but executable is normally produced
singularity run -i $CONTAINER_SIF_PATH /work/build_fxtran.sh
set -e
cp $TMP_LOC/fxtran/bin/fxtran $ROOTDIR/src/pyfxtran/bin/fxtran

# Build the wheel
cd $ROOTDIR
python3 -m build --sdist --wheel
VERSION=$(python3 <(cat src/pyfxtran/__init__.py; echo 'print(__version__)'))
python3 -m auditwheel repair dist/pyfxtran-${VERSION}-py3-none-any.whl
