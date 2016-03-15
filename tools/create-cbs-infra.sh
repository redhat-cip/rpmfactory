#!/bin/bash
# https://cbs.centos.org/koji/taginfo?tagID=194

koji add-tag --arches "x86_64" buildsys7
koji add-tag --arches "x86_64" el7-build

koji add-external-repo -t el7-build dist-centos7-rdo
koji add-external-repo -t el7-build centos7-os http://mirror.centos.org/centos/7/os/\$arch/
koji add-external-repo -t el7-build centos7-updates http://mirror.centos.org/centos/7/updates/\$arch/
koji add-target buildsys7 el7-build

koji add-tag cloud7-openstack-liberty-candidate
koji add-tag cloud7-openstack-common-candidate

koji add-external-repo -t cloud7-el7-build centos7-updates
koji add-external-repo -t cloud7-openstack-liberty-el7-build centos7-updates
koji add-external-repo -t cloud7-openstack-liberty-el7-build centos7-os

koji add-tag --arches "x86_64" cloud7-openstack-liberty-el7-build
koji add-tag --arches "x86_64" cloud7-openstack-common-el7-build

# Fix inheritance (parent are a bit strange)
## cloud7-openstack-common-candidate
koji add-tag-inheritance --priority 1 cloud7-openstack-common-el7-build buildsys7
koji add-tag-inheritance --priority 2 cloud7-openstack-common-el7-build cloud7-openstack-common-candidate
koji add-target cloud7-openstack-common-el7 cloud7-openstack-common-el7-build cloud7-openstack-common-candidate

## cloud7-openstack-liberty-candidate
koji add-tag-inheritance --priority 1 cloud7-openstack-liberty-el7-build buildsys7
koji add-tag-inheritance --priority 2 cloud7-openstack-liberty-el7-build cloud7-openstack-liberty-candidate
koji add-tag-inheritance --priority 3 cloud7-openstack-liberty-el7-build cloud7-openstack-common-candidate
koji add-target cloud7-openstack-liberty-el7 cloud7-openstack-liberty-el7-build cloud7-openstack-liberty-candidate

## Build group
koji add-group buildsys7 build
koji add-group buildsys7 srpm-build
# https://github.com/hguemar/rdo-rpm-macros
koji add-group-pkg buildsys7 build bash bzip2 coreutils cpio diffutils findutils gawk gcc grep sed gcc-c++ gzip info patch redhat-rpm-config rpm-build shadow-utils tar unzip util-linux-ng which make rdo-rpm-macros
koji add-group-pkg buildsys7 srpm-build bash gnupg make redhat-rpm-config rpm-build shadow-utils wget rpmdevtools rdo-rpm-macros

## Add repos
koji add-external-repo -t cloud7-openstack-liberty-el7-build dist-centos7-rdo
koji add-external-repo -t cloud7-openstack-liberty-el7-build dist-centos7-repo-updates
koji add-external-repo -t cloud7-openstack-liberty-el7-build dist-centos7-epel
koji add-external-repo -t cloud7-openstack-liberty-el7-build dist-centos7-extras
koji add-external-repo -t cloud7-openstack-liberty-el7-build dist-centos7-plus
koji add-external-repo -t cloud7-openstack-common-el7-build dist-centos7-rdo
koji add-external-repo -t cloud7-openstack-common-el7-build dist-centos7-repo-updates
koji add-external-repo -t cloud7-openstack-common-el7-build dist-centos7-epel
koji add-external-repo -t cloud7-openstack-common-el7-build dist-centos7-extras
koji add-external-repo -t cloud7-openstack-common-el7-build dist-centos7-plus

## Regen repos
koji regen-repo cloud7-openstack-liberty-el7-build
koji regen-repo cloud7-openstack-common-el7-build
