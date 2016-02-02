#!/bin/bash

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

# Run it standalone
# DEBUG=1 WORKSPACE=workspace_sim ZUUL_CHANGES=aodh-distgit:xyz \
# ZUUL_BRANCH=rdo-liberty ZUUL_URL=http://rpmfactory.beta.rdoproject.org/zuul/p ZUUL_REF="" \
# rpmfactory/koji-build.sh

source ./rpm-koji-gating-lib.common

echo "=== Start job for ${ZUUL_PROJECT} ==="

# Wait for other job to finish
# We want to make sure all jobs belonging to this change
# finish prior to run the "non scratch" build on Koji
# Furthermore we want to wait for the change to be on top
# of the shared queue before we start the build on koji
# wait_for_other_jobs.py handles the condition of releasing
# the wait.
[ -x /usr/local/bin/wait_for_other_jobs.py ] && /usr/local/bin/wait_for_other_jobs.py

# Clean previous run
sanitize

# Fetch all involved projects
zuul-cloner --workspace $workdir $rpmfactory_clone_url $ZUUL_PROJECT

# Build all SRPMS
pushd $ZUUL_PROJECT > /dev/null
pname=$(egrep "^Name:" *.spec | awk '{print $2}')
build_srpm
srpm=$(ls ${rpmbuild}/SRPMS/${pname}*.src.rpm)
popd > /dev/null

# Start builds on koji
start_build_on_koji $srpm $ZUUL_PROJECT "" 

# Check build status koji side
while ! -f "$workdir/${project}_meta/built"; do
  echo -e "\n--- Check koji build for $ZUUL_PROJECT ---"
  if [ -f "$workdir/${project}_meta/failed" ]; then
    echo -e "\n Build failed. Package not exported. Exit 1 !"
    exit 1
  fi
  sleep 10
done

echo -e "\n Build succeed. Package exported."
