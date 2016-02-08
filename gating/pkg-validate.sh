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
# DEBUG=1 WORKSPACE=/tmp/workspace_sim ZUUL_CHANGES=aodh-distgit:xyz^cinderclient-distgit:rdo-liberty:xyz \
# ZUUL_BRANCH=rdo-liberty ZUUL_URL=http://rpmfactory.beta.rdoproject.org/zuul/p ZUUL_REF="" pkg-validate.sh

source ./rpm-koji-gating-lib.common

echo -e "\n\n=== Start job for ${ZUUL_PROJECT} ==="

# Clean previous run
sanitize

# Fetch all involved projects
fetch_projects

# Build all SRPMS
build_srpms

# Start builds on koji
build_all_on_koji

# Check build status koji side
wait_for_all_built_on_koji

# Fetch all built packages
fetch_rpms

# Create the local repo
create_local_repo

# Run packstack test
echo -e "\n--- Run packstack test ---"
#$currentdir/run_packstack.sh \
#  ${rpmbuild}/RPMS/noarch/rdo-temp-release-1.0-1.noarch.rpm $url

echo "Simulate"
sleep 100
