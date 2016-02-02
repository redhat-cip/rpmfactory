#!/bin/bash

# Run it standalone
# DEBUG=1 WORKSPACE=workspace_sim ZUUL_CHANGES=aodh-distgit:xyz^cinderclient-distgit:rdo-liberty:xyz \
# ZUUL_BRANCH=rdo-liberty ZUUL_URL=http://rpmfactory.beta.rdoproject.org/zuul/p ZUUL_REF="" rpmfactory/koji-build.sh

source ./rpm-koji-gating-lib.common

echo "=== Start job for ${ZUUL_PROJECT} ==="

# Clean previous run
init_build_tree

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
create_loca_repo

# Run packstack test
$rpmfactorydir/run_packstack.sh \
  ${rpmbuild}/RPMS/noarch/rdo-temp-release-1.0-1.noarch.rpm $url
