# T+A Streaming Board --- Open Source Software Edition

## Cloning

Please clone this repository with

    $ git clone --recursive <url>

In case you didn't use the `--recursive` option for cloning, you will end up
with a clone without any submodules. To fix this, run

    $ git submodule init
    $ git submodule update

to clone the missing submodules.

## Building

On a Linux host, run

    $ ./build.sh

to build the firmware image. This can take several hours.

After successful build, the image file is found in directory
`strbo_build_main/tmp-glibc/deploy/images/raspberrypi/` and is named
`strbo-image-raspberrypi-<timestamp>.emmc.image`. You can use `dd` to
flash the image to a Raspberry Pi Compute Module 1, 3, or 3+.

Enjoy!

## Contact

Please note that we cannot offer support for our Open Source Software Edition.
To report bugs or send in patches, please contact the maintainer
[Robert Tiemann](mailto:r.tiemann@ta-hifi.com?Subject=T+A%20OSS:%20<please%20fill%20in%20subject>)
via e-mail.

Postal address:

    T+A elektroakustik GmbH & Co. KG
    Planckstrasse 11
    32052 Herford
    Germany
