#!/bin/sh

if [ $# != 1 ]; then
    echo "Usage: $0 <url>" 1>&2
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
