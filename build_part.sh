#! /bin/bash
#
# Build parts of the Strbo distribution.
#
# The parts consist of
# - an image file containing the boot loader and related files;
# - an image file containing the Linux system;
# - package files for the package management system.
#
# Check strbo_build_*/tmp-glibc/deploy/ for results.
#
# Note: The OE script sourced below is a GNU Bash script, so we really need
#       that unholy /bin/bash shebang.
#

if test $# -ne 1
then
    echo "Usage: $0 (main|recovery|flashimage)"
    exit 1
fi

umask 0022

ORIGINAL_SYSTEM_NAME="$1"
SYSTEM_NAME=$(echo -n $ORIGINAL_SYSTEM_NAME | sed 's/-config$//')

if test x"$SYSTEM_NAME" = 'xflashimage'
then
    SYSTEM_BUILD_NAME='main'
else
    SYSTEM_BUILD_NAME="$SYSTEM_NAME"
fi

case ${SYSTEM_BUILD_NAME}
in
    main)
        SUBST_DISTRO='s/@DISTRO@/strbo-main/g'
        BUILD_DIR='strbo_build_main'
        OTHER_BUILD_DIR='strbo_build_recovery'
        ;;
    recovery)
        SUBST_DISTRO='s/@DISTRO@/strbo-recovery/g'
        BUILD_DIR='strbo_build_recovery'
        OTHER_BUILD_DIR='strbo_build_main'
        ;;
    *)
        echo "Invalid system name \"$1\"."
        exit 1
        ;;
esac

OTHER_DEPLOY_DIR_IMAGE="${PWD}/${OTHER_BUILD_DIR}/tmp-glibc/deploy/images/raspberrypi"
SUBST_OTHER_DEPLOY_DIR=';s,@OTHER_DEPLOY_DIR_IMAGE@,'"${OTHER_DEPLOY_DIR_IMAGE}"',g'

#
# Previously generated options for the complete build.
#
. build_options.config

#
# Set up environment for BitBake.
#
. yocto/oe-init-build-env "${BUILD_DIR}"

if [ -z "$STRBO_BUILD_CONTINUE_ON_ERROR" ]; then
    set -e
fi

rm -f conf/local.conf

if test "x${DISTRO_DATETIME}" = x
then
    echo "Variable DISTRO_DATETIME not set."
    exit 1
else
    SUBST_DATETIME=';s/@DISTRO_DATETIME@/'"${DISTRO_DATETIME}"'/g'
fi

if test "x${DISTRO_GIT_COMMIT}" = x
then
    echo "Variable DISTRO_GIT_COMMIT not set."
    exit 1
else
    SUBST_GITCOMMIT=';s/@DISTRO_GIT_COMMIT@/'"${DISTRO_GIT_COMMIT}"'/g'
fi

SUBST_NIGHTLY_PACKAGES=';s/@WITH_NIGHTLY_PACKAGES@/# /g'

if test "x${RELEASE_VERSION}" = x
then
    SUBST_VERSION=';s/@WITH_DISTRO_VERSION@/# /g'
else
    SUBST_VERSION=';s/@WITH_DISTRO_VERSION@//g;s/@DISTRO_VERSION@/'"$RELEASE_VERSION"'/g'

    if test "x${RELEASE_VERSION}" = 'xnightly' || echo "x${RELEASE_VERSION}" | grep -q '^xnightly-'
    then
        SUBST_NIGHTLY_PACKAGES=';s/@WITH_NIGHTLY_PACKAGES@//g'
    fi
fi

if test "x${RELEASE_LINE}" = x
then
    echo "Variable RELEASE_LINE not set."
    exit 1
else
    SUBST_LINE=';s/@WITH_DISTRO_LINE@//g;s/@DISTRO_LINE@/'"$RELEASE_LINE"'/g'
fi

if test "x${RELEASE_FLAVOR}" = x
then
    echo "Variable RELEASE_FLAVOR not set."
    exit 1
else
    SUBST_FLAVOR=';s/@WITH_DISTRO_FLAVOR@//g;s/@DISTRO_FLAVOR@/'"$RELEASE_FLAVOR"'/g'
fi

set -u

SUBSTS="${SUBST_DISTRO}${SUBST_DATETIME}${SUBST_GITCOMMIT}${SUBST_VERSION}${SUBST_LINE}${SUBST_FLAVOR}${SUBST_OTHER_DEPLOY_DIR}${SUBST_NIGHTLY_PACKAGES}"

#
# We are now in the build directory; the sourced script changed the directory
# for us... Anyway, we may now run bitbake to build parts of our distribution.
#

sed "$SUBSTS" conf/local.conf.in >conf/local.conf

if test "x$SYSTEM_NAME" != "x$ORIGINAL_SYSTEM_NAME"
then
    exit 0
fi

case ${SYSTEM_NAME}
in
    main)
        time (
        echo "Running Bitbake to build boot and main partition images..."
        time bitbake ${STRBO_BUILD_CONTINUE_ON_ERROR:+-k} strbo-main-image strbo-main-boot-image
        echo "Running Bitbake to populate SDK..."
        time bitbake ${STRBO_BUILD_CONTINUE_ON_ERROR:+-k} -c populate_sdk strbo-main-image
        echo "Creating RPM package index..."
        time bitbake ${STRBO_BUILD_CONTINUE_ON_ERROR:+-k} package-index
        )
        ;;
    recovery)
        time (
        # must be built one after the other because dependencies cannot be formulated
        # in a way that it actually works
        echo "Running Bitbake to build recovery image..."
        time bitbake ${STRBO_BUILD_CONTINUE_ON_ERROR:+-k} strbo-recovery-image
        echo "Running Bitbake to build recovery boot image..."
        time bitbake ${STRBO_BUILD_CONTINUE_ON_ERROR:+-k} strbo-recovery-boot-image

        # dito, we need to put image files built by previous recipes into this image
        echo "Running Bitbake to build recovery data image..."
        time bitbake ${STRBO_BUILD_CONTINUE_ON_ERROR:+-k} strbo-recovery-data-image
        )
        ;;
    flashimage)
        time (
        echo "Running Bitbake to clean state for full disk image..."
        time bitbake ${STRBO_BUILD_CONTINUE_ON_ERROR:+-k} -c cleansstate strbo-image
        echo "Running Bitbake to build full disk image..."
        time bitbake ${STRBO_BUILD_CONTINUE_ON_ERROR:+-k} strbo-image
        )
        ;;
esac
