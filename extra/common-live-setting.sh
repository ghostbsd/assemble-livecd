#!/bin/sh

set -e -u

set_live_system()
{
  cp -Rf ${cwd}/extra/common-live-settings/base/override/root/* ${release}/root
  cp -Rf ${cwd}/scripts/pc-installdialog ${release}/etc/
  cp -Rf ${cwd}/scripts/openrc ${release}/etc/
  cp -Rf ${cwd}/scripts/rc.install ${release}/etc/
}
