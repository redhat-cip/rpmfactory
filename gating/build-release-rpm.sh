#!/bin/sh

# Copyright (C) 2016 Red Hat, Inc
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

if [ $# != 2 ]; then
    echo "Usage: $0 <temp repo url> <validated repo url>" 1>&2
    exit 1
fi

cat > rdo-temp-release.spec <<EOS
Summary: yum repo files for testing
Name: rdo-temp-release
Version: 1.0
Release: 1
License: GPL
Requires: epel-release
BuildArch: noarch

%description

%prep

%build

%install
rm -rf \$RPM_BUILD_ROOT

mkdir -p \$RPM_BUILD_ROOT/etc/yum.repos.d

cat > \$RPM_BUILD_ROOT/etc/yum.repos.d/rdo-temp-release.repo <<EOF
[validated]
name=validated packages for RDO testing
baseurl=$2
enabled=1 
gpgcheck=0 

[temp]
name=temporary packages for RDO testing
baseurl=$1
enabled=1 
gpgcheck=0 
EOF

%clean
rm -rf \$RPM_BUILD_ROOT

%files
%defattr(-,root,root)
/etc/yum.repos.d/*

%changelog
EOS

rpmbuild -bb rdo-temp-release.spec

# build-release-rpm.sh ends here
