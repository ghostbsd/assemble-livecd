#!/bin/sh

set -e -u

set_live_system()
{
  cp -Rf ${cwd}/extra/common-live-settings/base/override/root/* ${release}/root
  cp -Rf ${cwd}/settings/pc-installdialog ${release}/usr/local/sbin/
  cp -Rf ${cwd}/settings/rc.install ${release}/etc/
}
