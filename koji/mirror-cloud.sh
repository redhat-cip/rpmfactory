#!/bin/bash

TARGET='/srv/mirror/centos/7/cloud'

if [ -f /var/lock/subsys/rsync_updates ]; then
  echo "Updates via rsync already running."
  exit 0
fi
if [ -d ${TARGET} ] ; then
  touch /var/lock/subsys/rsync_updates
  rsync  -avSHP --delete --exclude "local*" --exclude "isos" --exclude "instance" rsync://mirrors.ircam.fr/pub/CentOS/7/cloud/ ${TARGET}/
  /bin/rm -f /var/lock/subsys/rsync_updates
  echo "Change SELinux context, (httpd_sys_content_t)."
  chcon -Rv --type=httpd_sys_content_t ${TARGET}
else
  echo "Target directory ${TARGET} not present."
fi
