#! /bin/sh

WORKDIRS="strbo_build_main strbo_build_recovery"
ITEMS="cache tmp-glibc bitbake.lock bitbake-cookerdaemon.log conf/local.conf conf/sanity_info"

for D in $WORKDIRS
do
    for I in $ITEMS
    do
        echo "Removing $D/$I"
        rm -rf "$D/$I"
    done
done

echo "Removing py2"
rm -rf 'py2'

echo "Removing build_options.config"
rm -f 'build_options.config'

echo "Reverting submodules to original state"
git submodule update
rm -f .build_patch_yocto
