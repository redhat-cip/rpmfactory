#!/bin/bash

set -e

dist='dist-centos7'
koji_server='koji-rpmfactory.ring.enovance.com'
koji_ui_tasks_uri="http://${koji_server}/koji/taskinfo?taskID="

rpmbuild="${HOME}/rpmbuild"
rpmfactorydir=$(dirname "$0")

workdir=$(mktemp -d)

zuul_ref=$(echo $ZUUL_REF |awk -F/ '{print $NF}')
temprepopath="/tmp/${ZUUL_PROJECT}/${zuul_ref}/x86_64/"
url="file://$temprepopath" 
validatedurl="http://${koji_server}/kojifiles/repos/dist-centos7-build/latest/x86_64"

function build_srpm() {
  spectool -g ./*.spec -C ${rpmbuild}/SOURCES/
  rsync --exclude="*.spec" ./* ${rpmbuild}/SOURCES/
  rpmbuild -bs ./*.spec
}

function build_on_koji() {
  local srpm=$1
  local targetdir=$2
  echo "Start build of: $srpm"
  # Note: (sbadia) If you don't use a scratch build, you must register your package
  # before. Using for example:
  #   $ koji add-pkg --owner kojiadmin dist-centos7 sf-sshpubkeys
  #   $ koji build dist-centos7 /tmp/sf-sshpubkeys-0.1-1.el7.centos.src.rpm
  set +e
  koji build --scratch "$dist" "$srpm" &> $workdir/out
  set -e
  tid=$(grep 'Created' $workdir/out | awk -F': ' '{print $2}')
  echo "Task id is: $tid"
  echo "Task console is: ${koji_ui_tasks_uri}${tid}"
  while true; do
    koji taskinfo -vr "$tid" &> $workdir/out2
    state=$(egrep "^State:" $workdir/out2 | awk -F': ' '{print $2}')
    if [ "$state" = "closed" -o "$state" = "failed" ]; then
        echo "Task $tid finished with status: $state"
        break
    else
        echo "Task $tid is processing: $state ..."
        sleep 5
    fi
  done
  if [ "$state" = "failed" ]; then
    echo "Task $tid failed. exit 1."
    return 1
  fi
  if [ "$state" = "closed" ]; then
    echo "Task $tid succeed."
    koji download-task $tid
    rsync --exclude="*.src.rpm" ./*.rpm ${targetdir}/
    rm -f ./*.rpm
    return 0
  fi
  return 2
}

# Cleaning and generate build tree
[ -d ${temprepopath} ] && rm -Rf ${temprepopath}
mkdir -p $temprepopath
[ -d "${rpmbuild}" ] && rm -Rf "${rpmbuild}"
rpmdev-setuptree

# Do we have a spec file here
[ -f *.spec ] || {
  echo "Unable to find a spec file in the local directory"
  exit 1
}

# Build the SRPM
build_srpm
srpm=$(ls ${rpmbuild}/SRPMS/*.src.rpm)

if build_on_koji $srpm $temprepopath; then
  # Create local repo with the output of build_on_koji
  createrepo $temprepopath
  $rpmfactorydir/build-release-rpm.sh $url $validatedurl
  rm rdo-temp-release.spec
  # Run packstack
  $rpmfactorydir/run_packstack.sh ${rpmbuild}/RPMS/noarch/rdo-temp-release-1.0-1.noarch.rpm $url
else
  echo "Build failed on koji" 
  exit 1
fi
