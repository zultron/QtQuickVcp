#!/bin/bash -e
#
# Build QtQuickVCP packages in Docker
#
# This script can be run manually or in Travis CI

###########################################################
# Configuration from environment, CL args and defaults
CMD=${CMD:-shell}
IMAGE=${IMAGE:-zultron/docker-dev}
TAG=${TAG:-latest}
JOBS=${JOBS:-2}
BUILD_SOURCE=${BUILD_SOURCE:-true}  # update Changelog & source pkg

# CL arguments
while getopts c:i:t:j:nh? opt; do
    case "$opt" in
	c) CMD=$OPTARG ;;
	i) IMAGE=$OPTARG ;;
	t) TAG=$OPTARG ;;
	j) JOBS=$OPTARG ;;
	n) BUILD_SOURCE=false ;;
	?|h|*) echo "Usage:  $0 [ -i DOCKER-IMAGE ] [ -t DOCKER-TAG ]" \
	    "[ -c ( deb [ -n ] | [ shell ] [ COMMAND ARG ... ] ) ]" >&2
	    exit 1 ;;
    esac
done
shift $(($OPTIND - 1))

###########################################################
# Set build parameters

# Arch-specific:
case ${TAG} in
    amd64_*|latest)
	BUILD_OPTS='-b'                  # Build all binary packages
	;;
    i386_*)                          # Machine arch: i386
	BUILD_OPTS="-a i386"             # - Set machine arch
	;;& # Fall through
    armhf_*)                             # Machine arch: armhf
	BUILD_OPTS="-a armhf"            # - Set machine arch
	;;& # Fall through
    i386_*|armhf_*)                  # Cross-compile/foreign arch
	BUILD_OPTS+=" -B"                # - Only build arch binary packages
	BUILD_OPTS+=" -d"                # - Root fs missing build deps; force
	BUILD_SOURCE=false               # - Don't build source package
	;;
    *) echo "Warning:  unknown tag '${TAG}'" >&2 ;;
esac

# Parallel jobs in `make`
export DEB_BUILD_OPTIONS="parallel=${JOBS}"

# UID/GID to carry into Docker
UID_GID=${UID_GID:-`id -u`:`id -g`}

# Bind source directory:  parent of $PWD for packages
BIND_SOURCE_DIR="$(readlink -f $PWD/..)"

# Directory containing this script
SCRIPT_DIR="$(dirname $0)"

# Make TAG accessible to called programs
export TAG

###########################################################
# Generate command line

declare -a BUILD_CL DOCKER_EXTRA_OPTS
case $CMD in
    "shell"|"") # Interactive shell (default)
	DOCKER_EXTRA_OPTS=( --privileged --interactive --tty )
	if test -z "$*"; then
	    BUILD_CL=( bash -i )
	else
	    BUILD_CL=( "$@" )
	fi
	;;
    "deb") # Build Debian packages
	DOCKER_EXTRA_OPTS=(
	    # Used in dpkg-buildpackage
	    -e DEB_BUILD_OPTIONS=$DEB_BUILD_OPTIONS
	    -e DH_VERBOSE=$DH_VERBOSE
	    # Used in scripts/build_source_package
	    -e DEBIAN_SUITE=$DEBIAN_SUITE
	    -e MAJOR_MINOR_VERSION=$MAJOR_MINOR_VERSION
	    -e PKGSOURCE=$PKGSOURCE
	    -e REPO_URL=$REPO_URL
	    -e TRAVIS_BRANCH=$TRAVIS_BRANCH
	    -e TRAVIS_PULL_REQUEST=$TRAVIS_PULL_REQUEST
	    -e TRAVIS_REPO=$TRAVIS_REPO
	    -e TRAVIS_REPO_SLUG=$TRAVIS_REPO_SLUG
	)

	BUILD_CL=( bash -xec "
            # update Changelog and build source package
            $SCRIPT_DIR/build_source_package $BUILD_SOURCE

            # build binary packages
            dpkg-buildpackage -uc -us ${BUILD_OPTS} -j$JOBS
            "
	)
	;;
    *)   echo "Unkown command '$CMD'" >&2; exit 1 ;;
esac

###########################################################
# Update container image with custom /etc/passwd

if test ${UID_GID/:*/} != 1000; then
    echo "Updating /etc/passwd for UID $TRAVIS_UID" >&2
    NEWTAG=${TAG}_custom
    docker build -t ${IMAGE}:${NEWTAG} - <<EOF
FROM ${IMAGE}:${TAG}
RUN sed -i "s/\${USER}:x:\${UID}:/\${USER}:x:${UID_GID/:*/}:/" /etc/passwd
ENV UID=${UID_GID/:*/}
EOF
else
    NEWTAG=${TAG}
fi

###########################################################
# Run build

set -x  # Show user the command

# Run the Docker container as follows:
# - Remove container after exit
# - Run interactively with terminal
# - Add any `DOCKER_EXTRA_OPTS` from above
# - As Travis CI user/group
# - Bind-mount home and source directories; start in source directory
# - Pass environment variable `TAG`
# - Set hostname to $IMAGE:$TAG (replace `/` and `:` with `-`)
# - Run build command as set above
# hide --it
exec docker run \
    --rm \
    "${DOCKER_EXTRA_OPTS[@]}" \
    -u ${UID_GID} -e USER=${USER} \
    -v ${HOME}:${HOME} -e HOME=${HOME} \
    -v ${BIND_SOURCE_DIR}:${BIND_SOURCE_DIR} -w ${PWD} \
    -e TAG=${TAG} \
    -h ${IMAGE//[\/:]/-}-${TAG} \
    ${IMAGE}:${NEWTAG} \
    "${BUILD_CL[@]}"
