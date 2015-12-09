#!/usr/bin/env python

import os
import sys
import yaml
import urlparse
import tempfile
import rdoinfo

from rdopkg.utils.cmd import git

# NOTE: USER need to be in the ptl-group of the project
# NOTE: USER need to have its key registered in its Gerrit account
# NOTE: USER need to have right to create a ref of Gerrit
# NOTE: project and openstack-project need to be created as empty on SF before running
# that script.

# NOTE: THIS IS JUST A QUICK POC


SF="rpmfactory.beta.rdoproject.org"
USER="fbo"
GERRITSF="ssh://%s@%s:29418/" % (USER, SF)

if len(sys.argv) < 3:
    sys.exit(1)

rdoinfo_file = sys.argv[1]
upstream_project = sys.argv[2]

select = [pkg for pkg in rdoinfo.parse_info_file(rdoinfo_file)['packages'] \
          if pkg['project'] == upstream_project][0]
if not select:
    print "Not found"

workdir = tempfile.mkdtemp()

distgit = select['distgit']
parts = urlparse.urlparse(distgit)
distgit = urlparse.urlunparse(['git', parts.netloc, parts.path, '', '', ''])
mirror = select['patches']
upstream = select['upstream']

print "Selected project struct from rdoinfo: %s" % select
print "Distgit is: %s" % distgit
print "Mirror is: %s" % mirror
print "Workdir is: %s" % workdir
print "Upstream is: %s" % upstream

print "\n--> Init %s on SF" % select['name']
# Create the distgit repo on SF
os.chdir(workdir)
git('clone', 'http://%s/r/%s' % (SF, select['name']), select['name'])
os.chdir(select['name'])
# Remove the managesf commit
initial = git('rev-list', '--max-parents=0', 'HEAD')
git('reset', '--hard', initial)
git('remote', 'add', 'upstream', distgit)
git('fetch', '--all')
git('rebase', 'remotes/upstream/master')
git('remote', 'remove', 'upstream')
git('remote', 'add',  'gerrit', GERRITSF + select['name'])
git('push', '-f', 'gerrit', 'master')

print "\n--> Init %s on SF" % select['project']
os.chdir(workdir)
git('clone', 'http://%s/r/%s' % (SF, select['project']), select['project'])
os.chdir(select['project'])
git('remote', 'add', 'mirror', mirror)
git('fetch', '--all')
git('checkout', '-b', 'master-patches')
initial = git('rev-list', '--max-parents=0', 'HEAD')
git('reset', '--hard', initial)
git('rebase', 'mirror/master-patches')
git('remote', 'remove', 'mirror')
git('remote', 'add',  'gerrit', GERRITSF + select['project'])
git('push', 'gerrit', 'master-patches')

print "\n--> Manage addtionnal patches for %s" % select['project']
git('remote', 'add', 'upstream', upstream)
git('fetch', '--all')
diffs = git('rev-list', '--max-parents=1', 'upstream/master..master-patches')
git('remote', 'remove', 'upstream')
print "Reset master-patches to upstream master"
diffs = diffs.split('\n')
diffs.reverse()
git('checkout', 'master-patches')
git('reset', '--hard', "%s~1" % diffs[0])
git('push', 'gerrit', '-f', 'master-patches')
p = 0
for diff in diffs:
    p += 1
    print "Create p%s" % p
    git('checkout', '-b', 'p%s' % p)
    git('cherry-pick', diff)
    git('review', '-i', 'master-patches') 
