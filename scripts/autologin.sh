#!/bin/sh

set -e -u


setup_autologin()
{
  echo "# ${liveuser} user autologin" >> ${release}/etc/gettytab
  echo "${liveuser}:\\" >> ${release}/etc/gettytab
  echo ":al=${liveuser}:ht:np:sp#115200:" >> ${release}/etc/gettytab
  sed -i "" "/ttyv0/s/Pc/${liveuser}/g" ${release}/etc/ttys
 }
