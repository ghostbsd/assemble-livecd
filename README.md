assemble-livecd
===============
Live media creator for GhostBSD distribution

## Introduction
The purpose of this tool is quickly generate live images for GhostBSD.

## Features
* Build GhostBSD from packages
* Hybrid DVD/USB image

## System requirements
* Latest version of GhostBSD 
* 20GB of free disk space
* 4GB of free memory

Note: GhostBSD should be used to build ISO.

## Initial setup
Make sure to have linux64 kernel module loaded
```
kldload linux64
sysrc -f /etc/rc.conf kld_list="linux64"
```
Clone the repo:
```
git clone https://www.github.com/vimanuelt/assemble-livecd.git
```
## Starting a build
#### Enter the directory for running the LiveCD build script:
```
cd assemble-livecd
```

#### To build a GhostBSD 
```
./build.sh -r release
```
or
```
./build.sh -r devel
```

## Burn an image to cd:
```
cdrecord /usr/local/ghostbsd-build/iso/GhostBSD-2020-04.iso
```

## Write an image to usb stick:
```
dd if=/usr/local/ghostbsd-build/iso/GhostBSD-2020-04.iso of=/dev/da0 bs=4m
```

## Once at a shell prompt, enter the following commands
```
su
dhcpcd
cd /etc
./rc.install
```
