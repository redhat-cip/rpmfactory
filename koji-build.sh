#!/bin/bash

set -e

dist='dist-centos7'
koji_server='koji-ctrl.ring.enovance.com'
koji_ui_tasks_uri="http://${koji_server}/koji/taskinfo?taskID="
user='centos'
key=$SECRETKEY
ssh_opts="-i ${key} -oStrictHostKeyChecking=no -oPasswordAuthentication=no -oKbdInteractiveAuthentication=no -oChallengeResponseAuthentication=no"
zuul_ref=$(echo $ZUUL_REF |awk -F/ '{print $NF}')

rpmdev-setuptree
spectool -g *.spec -C ~/rpmbuild/SOURCES
rsync --exclude="*.spec" ./* ~/rpmbuild/SOURCES/
rpmbuild -bs *.spec
srpm=$(ls ~/rpmbuild/SRPMS/*.src.rpm)

echo "Start build of: $srpm"
set +e
koji build --scratch "$dist" "$srpm" &> /tmp/out
set -e
tid=$(grep 'Created' /tmp/out | awk -F': ' '{print $2}')
echo "Task id is: $tid"
echo "Task console is: ${koji_ui_tasks_uri}${tid}"
while true; do
    koji taskinfo -vr "$tid" &> /tmp/out2
    state=$(egrep "^State:" /tmp/out2 | awk -F': ' '{print $2}')
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
    exit 1
fi
if [ "$state" = "closed" ]; then
    echo "Task $tid succeed."
    pkgs=$(egrep rpm$ /tmp/out2 | egrep -v src.rpm$)
    for pkg in $pkgs; do
        temppath="/srv/mirror/rpmfactory/${ZUUL_PROJECT}/${zuul_ref}/x86_64/"
        ssh $ssh_opts ${user}@${koji_server} sudo mkdir -p $temppath
        ssh $ssh_opts ${user}@${koji_server} sudo cp $pkg $temppath
    done
fi

url="http://${koji_server}/$(echo $temppath | sed 's|/srv||')"
validatedurl=http://${koji_server}/mirror/centos/7/cloud/x86_64/openstack-liberty/
$WORKSPACE/rpmfactory/build-release-rpm.sh $url $validatedurl
scp $ssh_opts ~/rpmbuild/RPMS/noarch/rdo-temp-release-1.0-1.noarch.rpm ${user}@${koji_server}:/tmp/
ssh $ssh_opts ${user}@${koji_server} sudo cp /tmp/rdo-temp-release-1.0-1.noarch.rpm $temppath
ssh $ssh_opts ${user}@${koji_server} sudo createrepo $temppath
ssh $ssh_opts ${user}@${koji_server} sudo chcon -Rv --type=httpd_sys_content_t $temppath
echo "URL temporary repository: ${url}"

$WORKSPACE/rpmfactory/run_packstack.sh $url/rdo-temp-release-1.0-1.noarch.rpm $url
