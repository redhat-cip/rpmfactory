#!/bin/bash
#
# Copyright (C) 2016 RedHat <softwarefactory@redhat.com>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 2 of
# the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

if [ "x${DEBUG}" == "x1" ]; then
  set -x
fi

rpmfactory_uri='rpmfactory.beta.rdoproject.org'
openstack_uri='https://git.openstack.org/openstack'
rpmfactory_user='jenkinsync'

if [ -z "${ZUUL_PROJECT}" ]; then
  echo '[ERROR] ZUUL_PROJECT is not set'
  exit
fi

trap_handler () {
  echo "[ERROR] Please check ${0}, an error occured..."
  exit
}

# Handle
#trap trap_handler ERR

# Clone RPMFactory Mirrors
git_url="git+ssh://${rpmfactory_user}@${rpmfactory_uri}:29418/${ZUUL_PROJECT}"

pushd "${ZUUL_PROJECT}"

  if [ -n "${ZUUL_REF}" ]; then
    if ! [ "${ZUUL_REF}" == 'master' ]; then
      git checkout master
    fi
  else
    echo '[ERROR] ZUUL_REF is not set'
    exit
  fi

  # Configure git seetings (for gerrit)
  git config user.username $rpmfactory_user
  git remote add upstream "${openstack_uri}/${ZUUL_PROJECT}"

  # Test push origin
  git remote -v|egrep -q origin'\s+.*\(push\)'
  if [ $? -eq 0 ]; then
    git remote set-url --push origin "${git_url}"
  fi

  git remote update
  git push --tags origin
  git branch -r --list 'upstream/*' | while read UPSTREAM_BRANCH; do
    git push origin "${UPSTREAM_BRANCH}:refs/heads/${UPSTREAM_BRANCH#upstream/}"
  done # while read UPSTREAM_BRANCH

popd

# sync-upstream.sh ends here
