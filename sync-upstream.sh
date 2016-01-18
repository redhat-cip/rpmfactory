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
# sfrdobender@rpmfactory.beta.rdoproject.org (in core-group of each projects, see python-sfrdo)
rpmfactory_user='sfrdobender'

if [ -z "${ZUUL_PROJECT}" ]; then
  echo '[ERROR] ZUUL_PROJECT is not set'
  exit
else
  echo "= Run ${0} on project ${ZUUL_PROJECT} ="
fi

trap_handler () {
  echo "[ERROR] Please check ${0}, an error occured..."
  exit
}

# Handle
trap trap_handler ERR

# Clone RPMFactory Mirrors
git_url="git+ssh://${rpmfactory_user}@${rpmfactory_uri}:29418/${ZUUL_PROJECT}"

pushd "${ZUUL_PROJECT}"

  if [ -n "${ZUUL_REF}" ]; then
    git checkout master
  fi

  upstream_url=$(sfrdo infos --name "${ZUUL_PROJECT}"|grep 'upstream is'|awk '{ print $4 }')

  echo "Local project (sync): ${git_url}"
  echo "Upstream project    : ${upstream_url}"

  # Configure git seetings (for gerrit)
  git config user.username "${rpmfactory_user}"
  git remote add upstream "${upstream_url}"

  # Test push origin
  git remote -v|egrep -q origin'\s+.*\(push\)'
  if [ $? -eq 0 ]; then
    git remote set-url --push origin "${git_url}"
  fi

  echo "Fetch upstream branchs and refs"
  git remote update
  git branch -r --list 'upstream/*' | while read UPSTREAM_BRANCH; do
    echo "Push upstream changes on ${UPSTREAM_BRANCH}"
    git push -f origin "${UPSTREAM_BRANCH}:refs/heads/${UPSTREAM_BRANCH#upstream/}"
  done # while read UPSTREAM_BRANCH
  echo "Push upstream tags"
  git push --tags origin

popd

# sync-upstream.sh ends here
