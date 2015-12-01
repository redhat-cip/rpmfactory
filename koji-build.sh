#!/bin/bash

set -e

srpm=$1
dist='dist-centos7'
koji_internal_path=/mnt/koji/work/tasks/
koji_tasks_path='http://koji-ctrl.ring.enovance.com/kojifiles/work/tasks/'
koji_ui_tasks_uri='http://koji-ctrl.ring.enovance.com/koji/taskinfo?taskID='

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
    echo "Task $tid succeed. Fetching rpms ..."
    pkgs=$(egrep rpm$ /tmp/out2 | egrep -v src.rpm$ | sed "s|.*$koji_internal_path||")
    echo "$pkgs"
    for pkg in $pkgs; do
        echo "Fetching rpms $(basename "$pkg") ..."
        curl "$koji_tasks_path/$pkg" -o $(basename "$pkg")
    done
fi
