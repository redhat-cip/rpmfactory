#!/bin/sh
#
# Setup Koji builders/Repos/Targets

for i in $(seq 1 2);
do
  koji add-host "koji-build0${i}" x86_64
  koji add-host-to-channel "koji-build0${i}" createrepo
  koji edit-host --capacity=6 "koji-build0${i}"
done

koji add-tag dist-centos7
koji add-tag --parent dist-centos7 --arches "x86_64" dist-centos7-build

# external-repo order is important (koji dismiss epoch and version priority)
koji add-external-repo -p 5 -t dist-centos7-build dist-centos7-rdo http://koji-ctrl.ring.enovance.com/mirror/centos/7/cloud/\$arch/openstack-liberty/
koji add-external-repo -p 10 -t dist-centos7-build dist-centos7-repo-updates http://ftp.free.fr/mirrors/ftp.centos.org/7/updates/\$arch/
koji add-external-repo -p 15 -t dist-centos7-build dist-centos7-repo http://ftp.free.fr/mirrors/ftp.centos.org/7/os/\$arch/
koji add-external-repo -p 20 -t dist-centos7-build dist-centos7-epel http://epel.mirrors.ovh.net/epel/7/\$arch/

koji add-target dist-centos7 dist-centos7-build
koji add-group-pkg dist-centos7-build build bash bzip2 coreutils cpio diffutils findutils gawk gcc grep sed gcc-c++ gzip info patch redhat-rpm-config rpm-build shadow-utils tar unzip util-linux-ng which make
koji add-group-pkg dist-centos7-build srpm-build bash gnupg make redhat-rpm-config rpm-build shadow-utils wget rpmdevtools
koji regen-repo dist-centos7-build
