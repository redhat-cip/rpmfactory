#!/bin/bash

set -e

srpm=$1
dist='dist-centos7'
koji_internal_path=/mnt/koji/work/tasks/
koji_server='koji-ctrl.ring.enovance.com'
koji_tasks_path="http://${koji_server}/kojifiles/work/tasks/"
koji_ui_tasks_uri="http://${koji_server}/koji/taskinfo?taskID="
user='centos'
key=$SECRETKEY

echo "Start build of: $1"
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
    echo "$pkgs"		
    for pkg in $pkgs; do		
        echo "Fetching rpms $(basename "$pkg") ..."		
        temppath='/srv/mirror/rpmfactory/${ZUUL_PROJECT}/${ZUUL_REF}/el/7/x86_64/' 
        ssh -i $key ${user}@${koji_server} mkdir -p $temppath
        ssh -i $key ${user}@${koji_server} cp $pkg $temppath
    done
fi

url="http://${koji_server}/$(echo $temppath | sed 's|/srv||')"
~/rpmfactory/build-release-rpm.sh $url 
scp -i $key ~/rpmbuild/RPMS/noarch/rdo-temp-release-1.0-1.noarch.rpm ${user}@${koji_server}:$temppath
ssh -i $key ${user}@${koji_server} createrepo $temppath
ssh -i $key ${user}@${koji_server} chcon -Rv --type=httpd_sys_content_t $temppath
