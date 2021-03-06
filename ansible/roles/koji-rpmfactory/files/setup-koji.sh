#!/bin/bash
#
# Setup Koji builders/Repos/Targets

if [ "x${DEBUG}" == "x1" ]; then
  set -x
fi

builder=$1

if [ -z "${builder}" ]; then
  echo "./${0} <builder>"
  exit
fi

koji add-host "${builder}" x86_64
koji add-host-to-channel "${builder}" createrepo
koji edit-host --capacity=6 "${builder}"

koji add-tag dist-centos7
koji add-tag --parent dist-centos7 --arches "x86_64" dist-centos7-build

# external-repo order is important (koji dismiss epoch and version priority)
koji add-external-repo -p 5 -t dist-centos7-build dist-centos7-repo-updates http://mirror.centos.org/centos-7/7/updates/\$arch/
koji add-external-repo -p 10 -t dist-centos7-build dist-centos7-repo http://mirror.centos.org/centos-7/7/os/\$arch/
koji add-external-repo -p 15 -t dist-centos7-build dist-centos7-epel http://epel.mirrors.ovh.net/epel/7/\$arch/
koji add-external-repo -p 20 -t dist-centos7-build dist-centos7-extras http://mirror.centos.org/centos-7/7/extras/\$arch/
koji add-external-repo -p 25 -t dist-centos7-build dist-centos7-plus http://mirror.centos.org/centos-7/7/centosplus/\$arch/

koji add-target dist-centos7 dist-centos7-build

koji add-group dist-centos7-build build
koji add-group dist-centos7-build srpm-build

koji add-group-pkg dist-centos7-build build bash bzip2 coreutils cpio diffutils findutils gawk gcc grep sed gcc-c++ gzip info patch redhat-rpm-config rpm-build shadow-utils tar unzip util-linux-ng which make
koji add-group-pkg dist-centos7-build srpm-build bash gnupg make redhat-rpm-config rpm-build shadow-utils wget rpmdevtools

# Keep this task at background. No builder (kojid) available at this moment.
koji regen-repo --nowait dist-centos7-build
