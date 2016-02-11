#!/bin/bash
# Initial import from RDO repo into a koji install (for rebuild).

SRPMS='/srv/mirror/centos/7/cloud/Source/openstack-liberty/'

# Add packages from RDO mirror and import it in ~/rpmbuild
for packages in ${SRPMS}/*.src.rpm
do
  [[ -e $packages ]] || break
  koji add-pkg --owner jenkins cloud7-openstack-liberty-el7-build "$(basename $(echo $packages|cut -d '.' -f 1|sed 's/-[0-9].*//'))"
  koji add-pkg --owner jenkins cloud7-openstack-liberty-candidate "$(basename $(echo $packages|cut -d '.' -f 1|sed 's/-[0-9].*//'))"
  rpm -i "$packages"
done

# Rebuilds the srpms files
for sourcepkg in ~/rpmbuild/SPECS/*.spec
do
  [[ -e $sourcepkg ]] || break
  rpmbuild -bs "$sourcepkg";
done

# And finaly rebuild using Koji
for srcpkg in ~/rpmbuild/SRPMS/*.src.rpm
do
  [[ -e $srcpkg ]] || break
  koji build --nowait --quiet --noprogress cloud7-openstack-liberty-el7 "$srcpkg";
done
