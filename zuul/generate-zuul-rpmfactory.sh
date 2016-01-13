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
rpmfactory_user=$USER

GIT_RPMFACT=$(
  export LC_ALL=C
  ssh "$rpmfactory_uri" -l "$rpmfactory_user" -p 29418 \
    gerrit ls-projects \
      | sort \
      | sed '/config/d;/All-Users/d;s/\.git$//'
)

echo '# This file get appended to layout.yaml, thus the lack of'
echo "projects:"
for git in $GIT_RPMFACT;
do
  if [[ $git =~ -dist ]]; then
    echo "  - name: ${git}"
    echo "    check:"
    echo "      - pkg-validate"
    echo "      - delorean-ci"
  else
    echo "  - name: ${git}"
    echo "    check:"
    echo "      - tox-validate"
    echo "    periodic:"
    echo "      - upstream-update"
  fi
echo ''
done # for git in $GIT_RPMFACT

# sync-upstream.sh ends here
