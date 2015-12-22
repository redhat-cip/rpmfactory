#!/bin/bash
#
# Copyright (C) 2015 RedHat <softwarefactory@redhat.com>
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
distgit_uri='https://github.com/openstack-packages'
openstack_uri='https://git.openstack.org/openstack'
#rpmfactory_user='jenkinsync'
rpmfactory_user='sbadia'

if [ -n "${ZUUL_PROJECT}" ]; then
  GIT_RPMFACT="${ZUUL_PROJECT}"
else
  GIT_RPMFACT=$(
    export LC_ALL=C
    ssh "$rpmfactory_uri" -l "$rpmfactory_user" -p 29418 \
      gerrit ls-projects \
        | sort \
        | sed '/config/d;s/\.git$//'
  )
fi

trap_handler () {
  echo "[ERROR] Please check ${0}, an error occured..."
  exit
}

# Handle
#trap trap_handler ERR

for git in $GIT_RPMFACT;
do

  # Clone RPMFactory Mirrors
  git_url="git+ssh://${rpmfactory_user}@${rpmfactory_uri}:29418/${git}"

  if [ -n "${ZUUL_PROJECT}" ]; then
    pushd "${ZUUL_PROJECT}"
  else
    pushd "$(mktemp -d rpmfactory.XXXXXXXX)"
    git clone -q "${git_url}"
    cd "${git}"
  fi

  # Configure git seetings (for gerrit)
  git config user.username $rpmfactory_user
  git config user.name 'Jenkins Sync RPMFactory'
  #FIXME (use a real email, but I don't want to spam sf mailing)
  git config user.email 'sebastien.badia@enovance.com'

  if [[ $git =~ -dist ]]; then
    upstream_name="${git//-distgit/}"
    upstream_uri="${distgit_uri}/${upstream_name}"
  else
    upstream_uri="${openstack_uri}/${git}"
  fi

  # Add OpenStack or Distgit upstream
  git remote add upstream "${upstream_uri}"

  # Test push origin
  git remote -v|egrep -q origin'\s+.*\(push\)'
  if [ $? -eq 0 ]; then
    git remote set-url --push origin "${git_url}"
  fi

  git remote update
  echo git push --tags origin
  git branch -r --list 'upstream/*' | while read UPSTREAM_BRANCH; do
    echo git push origin "${UPSTREAM_BRANCH}:refs/heads/${UPSTREAM_BRANCH#upstream/}"
  done # while read UPSTREAM_BRANCH

  popd

done # for git in $GIT_RPMFACT

# sync-upstream.sh ends here
