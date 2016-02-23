Summary: A nice project p1 to test
Name: p1
Version: 1.0
Release: 1
License: GPL
Source: http://rpmfactory.sftests.com:8999/p1-1.0.tgz
Packager: John Doe <john@doe.com>

%description
What did you expect ?

%prep
%setup -q -n p1

%install
mkdir -p %{buildroot}/srv/p1
cp run_tests.sh %{buildroot}/srv/p1

%files
%attr(0755,root,root) /srv/p1
