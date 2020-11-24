#! /bin/sh
#
# Build Strbo distribution.
#
# The distribution consists of
# - an image file suitable for dumping to eMMC flash memory via dd;
# - package files for the package management system.
#
# Check strbo_build_main/tmp-glibc/deploy/ for results.
#

info() { printf "%s\n" "$*" >&2; }
warn() { printf "%s\n" "Warning: $*" >&2; }
fail() { printf "%s\n" "Fatal error: $*" >&2; exit 1; }

TIME_START_SCRIPT="$(date)"

umask 0022

if [ -z "$STRBO_BUILD_CONTINUE_ON_ERROR" ]
then
    set -e
else
    warn "Will continue on error because STRBO_BUILD_CONTINUE_ON_ERROR is set to '$STRBO_BUILD_CONTINUE_ON_ERROR'."
fi

WANT_SETUP=yes
WANT_MAIN_DISTRO=yes
WANT_RECOVERY_DISTRO=yes
WANT_FLASH_IMAGE=yes

if test "x${RELEASE_VERSION}" = x
then
    RELEASE_VERSION='V3.0.4'
    export RELEASE_VERSION
fi

RELEASE_LINE='V3'
RELEASE_FLAVOR='free'
REFERENCE_FLAVOR=
export RELEASE_LINE
export RELEASE_FLAVOR
export REFERENCE_FLAVOR

set -u

# Fix for "gpg: signing failed: Inappropriate ioctl for device"
if tty >/dev/null 2>&1
then
    GPG_TTY=$(tty)
    export GPG_TTY
fi

if test $WANT_SETUP = yes
then
    ./build_patch_yocto.sh

    cat <<EOF >build_options.config
################################################
#
# Build options
#

# Date/time stamp for image versioning, assign empty string to use Yocto
# defaults. This number is also used for the os-release package version.
DISTRO_DATETIME="$(date +%Y%m%d%H%M%S)"

# Git SHA1 from which the distribution is built
DISTRO_GIT_COMMIT="$(git rev-parse HEAD)"

# Build production image without profiling support (no) or development image
# with profiling support enabled (yes)
WITH_PROFILING=no

################################################
EOF

    info "Checking for GPG 2.1 or later to enable special configuration..."

    if gpg2 --version | head -n 1 | grep "gpg (GnuPG) 2.[12]" >/dev/null
    then
        info "Found GPG 2.1 or later."
        GPG_PINENTRYMODE_TWEAK="--pinentry-mode loopback"
        if test -f ~/.gnupg/gpg-agent.conf && grep allow-loopback-pinentry <~/.gnupg/gpg-agent.conf >/dev/null; then :; else
            info "Adding allow-loopback-pinentry to ~/.gnupg/gpg-agent.conf..."
            echo 'allow-loopback-pinentry' >> ~/.gnupg/gpg-agent.conf
        fi
    fi
fi

if test ! -d 'downloads'
then
    mkdir 'downloads'
fi

#
# Why is all of this so complicated?
#
# Turns out that BitBake and Poky aren't as flexible and customizable as they
# are advertizing themselves. As a result, instead of just building an full
# image with a single command and have BitBake do the rest, we have to manually
# create the various images and use different top-level configuration files.
#
# In fact, we are forced to build two separate Linux distributions!
#
# The problem here is that we need to build two different Linux kernels, each
# in its own binary format, so we have to define KERNEL_IMAGETYPE twice.
# However, it seems to be impossible to do this. Doing it in a recipe file is
# supposed to have (only) local effect, so this sounds right, but it didn't
# work at all. Doing it in a global configuration file allows us to define
# KERNEL_IMAGETYPE, and it does have an effect, but it can be defined only once
# so that all images are built using a single type.
#
# The correct KERNEL_IMAGETYPE and PREFERRED_PROVIDER of the virtual kernel
# package (this is also part of the problem, by the way: there is supposed to
# be only one kernel) are defined in two distro configuration files, and we
# choose one of them in local.conf as needed. And because the name "local.conf"
# is hard-coded (!!!) into BitBake, we are using a local.conf.in template and
# rewrite it the way it is needed. OMG.
#
# See also http://comments.gmane.org/gmane.linux.embedded.yocto.general/3491
#

NEED_PERMISSIONS_FIXUP=no

if test $WANT_MAIN_DISTRO = yes
then
    info "Building main partition..."

    ./build_part.sh main
    NEED_PERMISSIONS_FIXUP=yes
fi

if test $WANT_RECOVERY_DISTRO = yes
then
    info "Building recovery partition..."

    ./build_part.sh recovery
    NEED_PERMISSIONS_FIXUP=yes
fi

if test $WANT_FLASH_IMAGE = yes
then
    info "Building disk image..."

    ./build_part.sh flashimage
fi

if test $WANT_SETUP = yes && test $NEED_PERMISSIONS_FIXUP != yes && test $WANT_FLASH_IMAGE != yes
then
    ./build_part.sh main-config
    ./build_part.sh recovery-config
fi

#
# Fix up any problems with permissions. Some of the license files are deployed
# as readable only by the user, not by group or world. This happens for files
# extracted from source archives which contain files with these "bad"
# permissions assigned.
#

if test $NEED_PERMISSIONS_FIXUP = yes
then
    info "Checking that file modes allow read access by group and world..."
    if test -d strbo_build_main/tmp-glibc/deploy
    then
        find strbo_build_main/tmp-glibc/deploy ! -perm /o+r -exec chmod o+r {} \;
    fi
    if test -d strbo_build_recovery/tmp-glibc/deploy
    then
        find strbo_build_recovery/tmp-glibc/deploy ! -perm /o+r -exec chmod o+r {} \;
    fi
fi

TIME_DONE="$(date)"
info "Build script started at:      ${TIME_START_SCRIPT}"
info "Build script done at:         ${TIME_DONE}"

info "Done building streaming board distribution."
