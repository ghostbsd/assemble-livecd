#!/usr/bin/env sh

set -e -u

export cwd="`realpath | sed 's|/scripts||g'`"

# Only run as superuser
if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

liveuser=ghostbsd

livecd="/usr/local/ghostbsd-build"
base="/usr/local/ghostbsd-build/base"
iso="/usr/local/ghostbsd-build/iso"
software_packages="/usr/local/ghostbsd-build/software_packages"
base_packages="/usr/local/ghostbsd-build/base_packages"
release="/usr/local/ghostbsd-build/release"
cdroot="/usr/local/ghostbsd-build/cdroot"

kernrel="`uname -r`"

case $kernrel in
  '12.1-STABLE'|'12.1-PRERELEASE'|'12.0-STABLE') ;;
  *)
    echo "Using wrong kernel release. Use GhostBSD 20 to build iso."
    exit 1
    ;;
esac

desktop_list=`ls ${cwd}/packages | tr '\n' ' '`

helpFunction()
{
   echo "Usage: $0 -r release type"
   echo -e "\t-h for help"
   echo -e "\t-r Release: devel or release"
   exit 1 # Exit script after printing help
}

while getopts "d:r:" opt
do
   case "$opt" in
      'r') export release_type="$OPTARG" ;;
      'h') helpFunction ;;
      '?') helpFunction ;;
      *) helpFunction ;;
   esac
done


if [ ! -n "$release_type" ]
then
  export release_type="devel"
fi

# Source our functions
#. functions.sh

# version="20.03"
if [ "${release_type}" == "release" ] ; then
  version=`date "+-%y.%m"`
  time_stamp=""
else
  version=""
  time_stamp=`date "+-%Y-%m-%d"`
fi

label="GhostBSD"
isopath="/usr/local/ghostbsd-build/iso/${label}${version}${time_stamp}.iso"
union_dirs=${union_dirs:-"bin boot compat dev etc include lib libdata libexec \
man media mnt net proc rescue root sbin share tests tmp usr/home usr/local/etc \
var www"}


workspace()
{
  if [ -d ${release}/var/cache/pkg ]; then
    if [ "$(ls -A ${release}/var/cache/pkg)" ]; then
      umount ${release}/var/cache/pkg
    fi
  fi

  if [ -d "${release}" ] ; then
    if [ -d /usr/local/ghostbsd-build/dev ]; then
      if [ "$(ls -A /usr/local/ghostbsd-build/dev)" ]; then
        umount /usr/local/ghostbsd-build/dev
      fi
    fi
    chflags -R noschg ${release}
    rm -rf ${release}
  fi

  if [ -d "/usr/local/ghostbsd-build/cdroot" ] ; then
    chflags -R noschg /usr/local/ghostbsd-build/cdroot
    rm -rf /usr/local/ghostbsd-build/cdroot
  fi
  mkdir -p /usr/local/ghostbsd-build
  mkdir -p /usr/local/ghostbsd-build/base
  mkdir -p /usr/local/ghostbsd-build/iso
  mkdir -p /usr/local/ghostbsd-build/software_packages
  mkdir -p /usr/local/ghostbsd-build/base_packages
  mkdir -p ${release}
}

base()
{
  mkdir -p ${release}/etc
  cp /etc/resolv.conf ${release}/etc/resolv.conf
  mkdir -p ${release}/var/cache/pkg
  mount_nullfs /usr/local/ghostbsd-build/base ${release}/var/cache/pkg
  pkg-static -r ${release} -R ${cwd}/repos/usr/local/etc/pkg/repos/ \
-C GhostBSD install -y \
-g os-generic-kernel os-generic-userland os-generic-userland-lib32 \
os-generic-userland-devtools

  rm ${release}/etc/resolv.conf
  umount ${release}/var/cache/pkg
  touch ${release}/etc/fstab
  mkdir ${release}/cdrom
}

packages_software()
{
  cp -R ${cwd}/repos/ ${release}
  cp /etc/resolv.conf ${release}/etc/resolv.conf
  mkdir -p ${release}/var/cache/pkg
  mount_nullfs /usr/local/ghostbsd-build/software_packages ${release}/var/cache/pkg
  mount -t devfs devfs ${release}/dev
  cat ${cwd}/settings/common-packages | xargs pkg -c ${release} install -y
  mkdir -p ${release}/compat/linux/proc
  rm ${release}/etc/resolv.conf
  umount ${release}/var/cache/pkg

  cp -R ${cwd}/repos/ ${release}

}

rc()
{
  chroot ${release} sysrc -f /etc/rc.conf root_rw_mount="YES"
  chroot ${release} sysrc -f /etc/rc.conf hostname='livecd'
  chroot ${release} sysrc -f /etc/rc.conf sendmail_enable="NONE"
  chroot ${release} sysrc -f /etc/rc.conf sendmail_submit_enable="NO"
  chroot ${release} sysrc -f /etc/rc.conf sendmail_outbound_enable="NO"
  chroot ${release} sysrc -f /etc/rc.conf sendmail_msp_queue_enable="NO"
  # DEVFS rules
  chroot ${release} sysrc -f /etc/rc.conf devfs_system_ruleset="devfsrules_common"
  # Load the following kernel modules
  chroot ${release} sysrc -f /etc/rc.conf kld_list="linux linux64 cuse"
  chroot ${release} rc-update add devfs default
  chroot ${release} rc-update add moused default
  chroot ${release} rc-update add dbus default
  chroot ${release} rc-update add hald default
#  chroot ${release} rc-update add webcamd default
  chroot ${release} rc-update add powerd default
  chroot ${release} rc-update delete netmount default
#  chroot ${release} rc-update add cupsd default
  chroot ${release} rc-update add avahi-daemon default
  chroot ${release} rc-update add avahi-dnsconfd default
  chroot ${release} rc-update add ntpd default
  chroot ${release} sysrc -f /etc/rc.conf ntpd_sync_on_start="YES"
}

user()
{
  echo "Adding user"
  chroot ${release} pw useradd ghostbsd -c "Live User" \
-d "/usr/home/${liveuser}" -g wheel -G operator,video -m \
-s /usr/local/bin/fish -k /usr/share/skel -w yes
}

extra_config()
{
  . ${cwd}/extra/common-live-setting.sh
  . ${cwd}/extra/common-base-setting.sh
  . ${cwd}/extra/setuser.sh
#  . ${cwd}/extra/dm.sh
  . ${cwd}/extra/finalize.sh
  . ${cwd}/extra/autologin.sh
  . ${cwd}/extra/gitpkg.sh
#  . ${cwd}/extra/mate-live-settings.sh
  set_live_system
  setup_liveuser
  setup_base
  setup_autologin
  final_setup
  echo "gop set 0" >> ${release}/boot/loader.rc.local
  chroot ${release} cap_mkdb /etc/login.conf
  mkdir -p ${release}/usr/local/share/ghostbsd
#  echo "${desktop}" > ${release}/usr/local/share/ghostbsd
#/desktop
}

#xorg()
#{
#  if [ -n "${desktop}" ] ; then
#    install -o root -g wheel -m 755 "${cwd}/xorg/bin/xconfig" "/usr/local/ghostb
# sd-build/release/usr/local/bin/"
#    install -o root -g wheel -m 755 "${cwd}/xorg/rc.d/xconfig" "/usr/local/ghost
#bsd-build/release/usr/local/etc/rc.d/"
#    if [ -f "${release}/sbin/openrc-run" ] ; then
#      install -o root -g wheel -m 755 "${cwd}/xorg/init.d/xconfig" "/usr/local/g
#hostbsd-build/release/usr/local/etc/init.d/"
#    fi
#    if [ ! -d "${release}/usr/local/etc/X11/cardDetect/"
#] ; then
#      mkdir -p ${release}/usr/local/etc/X11/cardDetect
#    fi
#    install -o root -g wheel -m 755 "${cwd}/xorg/cardDetect/XF86Config.vesa" "/u
#sr/local/ghostbsd-build/release/usr/local/etc/X11/cardDetect/"
#    install -o root -g wheel -m 755 "${cwd}/xorg/cardDetect/XF86Config.scfb" "/u
#sr/local/ghostbsd-build/release/usr/local/etc/X11/cardDetect/"
#    install -o root -g wheel -m 755 "${cwd}/xorg/cardDetect/XF86Config.virtualbo
#x" "${release}/usr/local/etc/X11/cardDetect/"
#    install -o root -g wheel -m 755 "${cwd}/xorg/cardDetect/XF86Config.vmware" "
#${release}/usr/local/etc/X11/cardDetect/"
#    install -o root -g wheel -m 755 "${cwd}/xorg/cardDetect/XF86Config.nvidia" "
#${release}/usr/local/etc/X11/cardDetect/"
#    install -o root -g wheel -m 755 "${cwd}/xorg/cardDetect/XF86Config.intel" "/
#usr/local/ghostbsd-build/release/usr/local/etc/X11/cardDetect/"
#    install -o root -g wheel -m 755 "${cwd}/xorg/cardDetect/XF86Config.modesetti
#ng" "${release}/usr/local/etc/X11/cardDetect/"
#  fi
# }

uzip()
{
  umount ${release}/dev
  install -o root -g wheel -m 755 -d "/usr/local/ghostbsd-build/cdroot"
  mkdir "/usr/local/ghostbsd-build/cdroot/data"
  makefs -t ffs -f '10%' -b '10%' "/usr/local/ghostbsd-build/cdroot/data/usr.ufs" "${release}/usr"
  mkuzip -o "/usr/local/ghostbsd-build/cdroot/data/usr.uzip" "/usr/local/ghostbsd-build/cdroot/data/usr.ufs"
  rm -r "/usr/local/ghostbsd-build/cdroot/data/usr.ufs"
}

ramdisk()
{
  ramdisk_root="/usr/local/ghostbsd-build/cdroot/data/ramdisk"
  mkdir -p "${ramdisk_root}"
  cd "${release}"
  tar -cf - rescue | tar -xf - -C "${ramdisk_root}"
  cd "${cwd}"
  install -o root -g wheel -m 755 "settings/init.sh.in" "${ramdisk_root}/init.sh"
  sed "s/@VOLUME@/GHOSTBSD/" "settings/init.sh.in" > "${ramdisk_root}/init.sh"
  mkdir "${ramdisk_root}/dev"
  mkdir "${ramdisk_root}/etc"
  touch "${ramdisk_root}/etc/fstab"
  cp ${release}/etc/login.conf ${ramdisk_root}/etc/login.conf
  makefs -b '10%' "/usr/local/ghostbsd-build/cdroot/data/ramdisk.ufs" "${ramdisk_root}"
  gzip "/usr/local/ghostbsd-build/cdroot/data/ramdisk.ufs"
  rm -rf "${ramdisk_root}"
}

mfs()
{
  for dir in ${union_dirs}; do
    echo ${dir} >> /usr/local/ghostbsd-build/cdroot/data/uniondirs
    cd ${release} && tar -cpzf /usr/local/ghostbsd-build/cdroot/data/mfs.tgz ${union_dirs}
  done
}

boot()
{
  cd "${release}"
  tar -cf - boot | tar -xf - -C "/usr/local/ghostbsd-build/cdroot"
  cp COPYRIGHT /usr/local/ghostbsd-build/cdroot/COPYRIGHT
  cd "${cwd}"
  cp LICENSE /usr/local/ghostbsd-build/cdroot/LICENSE
  cp -R boot/ /usr/local/ghostbsd-build/cdroot/boot/
  mkdir /usr/local/ghostbsd-build/cdroot/etc
  cd /usr/local/ghostbsd-build/cdroot
  cd "${cwd}"
}

image()
{
  sh scripts/mkisoimages.sh -b $label $isopath /usr/local/ghostbsd-build/cdroot
  ls -lh $isopath
  cd /usr/local/ghostbsd-build/iso
  shafile=$(echo ${isopath} | cut -d / -f6).sha256
#  torrent=$(echo ${isopath} | cut -d / -f6).torrent
#  tracker1="http://tracker.openbittorrent.com:80/announce"
#  tracker2="udp://tracker.opentrackr.org:1337"
#  tracker3="udp://tracker.coppersurfer.tk:6969"
  echo "Creating sha256 \"/usr/local/ghostbsd-build/iso/${shafile}\""
  sha256 `echo ${isopath} | cut -d / -f6` > /usr/local/ghostbsd-build/iso/${shafile}
#  transmission-create -o /usr/local/ghostbsd-build/iso/${torrent} -t ${tracker1} -t ${tracker3} -t ${tracker3} ${isopath}
#  chmod 644 /usr/local/ghostbsd-build/iso/${torrent}
  cd -
}

workspace
base
packages_software
user
# xorg
rc
extra_config
uzip
ramdisk
mfs
boot
image
