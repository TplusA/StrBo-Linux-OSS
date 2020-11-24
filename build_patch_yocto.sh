#! /bin/sh
#
# Apply patches not applied in upstream Yocto Project
#

STAMPFILE='.build_patch_yocto'

if test -f ${STAMPFILE}
then
    echo 'Skip applying local Yocto Project patches'
    exit 0
fi

PATCHES=" \
    0001-rust-Support-Raspberry-Pi-1.patch \
"

set -eu

echo 'Applying local Yocto Project patches...'
git submodule update yocto
cd yocto
for p in ${PATCHES}; do git am ../yocto_patches/${p}; done
cd ..

touch ${STAMPFILE}
