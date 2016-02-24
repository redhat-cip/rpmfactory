#!/bin/bash

TARGET='/srv/mirror/centos/7/cloud'
SRPM="${TARGET}/Source"

if [ -f /var/lock/subsys/rsync_updates ]; then
  echo "Updates via rsync already running."
  exit 0
fi
if [ -d ${TARGET} ] ; then
  touch /var/lock/subsys/rsync_updates
  if [ "$(hostname -f)" != "koji.rpmfactory.sftests.com" ]; then
    # Don't sync in pre-prod
    rsync  -avSHP --delete --exclude "local*" --exclude "isos" --exclude "instance" rsync://mirrors.ircam.fr/pub/CentOS/7/cloud/x86_64/ ${TARGET}/x86_64/
    # Sync also srpm files (only official mirror can use rsync, let use wget then :-()
    mkdir -p "${SRPM}"
    pushd "${SRPM}"
      wget -r --no-parent --quiet --reject "index.html*" http://vault.centos.org/centos/7/cloud/Source/
      mv vault.centos.org/centos/7/cloud/Source/* .
      rm -rf vault.centos.org
    popd
    for release in liberty kilo
    do
      pushd "${TARGET}"
        cd x86_64
        cp -r openstack-${release}/common openstack-${release}-common
        createrepo openstack-${release}-common
      popd
    done
  fi
  /bin/rm -f /var/lock/subsys/rsync_updates
  echo "Change SELinux context, (httpd_sys_content_t)."
  chcon -Rv --type=httpd_sys_content_t ${TARGET}
else
  echo "Target directory ${TARGET} not present."
fi
