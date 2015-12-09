import os
import sys
import shlex
import urlparse
import subprocess

from rdopkg.utils.cmd import git

from sfrdoinit import rdoinfo


class Tool:
    def __init__(self):
        self.debug = None
        if "DEBUG" in os.environ:
            self.debug = sys.stdout
        self.env = os.environ.copy()

    def exe(self, cmd, cwd=None):
        if self.debug:
            self.debug.write("\n\ncmd = %s\n" % cmd)
            self.debug.flush()
        cmd = shlex.split(cmd)
        ocwd = os.getcwd()
        if cwd:
            os.chdir(cwd)
        try:
            p = subprocess.Popen(cmd, stdout=subprocess.PIPE,
                                 stderr=subprocess.STDOUT,
                                 env=self.env)
            output = p.communicate()[0]
            if self.debug:
                self.debug.write(output)
        finally:
            os.chdir(ocwd)
        return output


class ManageSfUtils(Tool):
    def __init__(self, url, user, passwd):
        Tool.__init__(self)
        self.base_cmd = "sfmanager --url %s " \
            "--auth %s:%s " % (url, user, passwd) 

    def createProject(self, name, options=None):
        cmd = self.base_cmd + " project create --name %s " % name
        if options:
            for k, v in options.items():
                cmd = cmd + " --" + k + " " + v

        self.exe(cmd)

    def deleteProject(self, name):
        cmd = self.base_cmd + " project delete --name %s" % name
        self.exe(cmd)

    def addUsertoProjectGroups(self, project, email, groups):
        cmd = self.base_cmd + " membership add --project %s " % project
        cmd = cmd + " --user %s --groups %s" % (email, groups)
        self.exe(cmd)


def fetch_project_infos(rdoinfo_file, upstream_project):
    select = [pkg for pkg in rdoinfo.parse_info_file(rdoinfo_file)['packages'] \
              if pkg['project'] == upstream_project]
    if not select:
        return None
    return select[0]


def flatten_infos(select):
    distgit = select['distgit']
    parts = urlparse.urlparse(distgit)
    # Change scheme to from ssh to git (avoid the need of being authenticated)
    distgit = urlparse.urlunparse(['git', parts.netloc, parts.path, '', '', ''])
    mirror = select['patches']
    upstream = select['upstream']
    return upstream, distgit, mirror


def init_distgit(sfdistgit, distgit, sf, gerritsf, workdir):
    print "\n--> Init %s on SF" % sfdistgit
    # Create the distgit repo on SF
    os.chdir(workdir)
    git('clone', 'http://%s/r/%s' % (sf, sfdistgit), sfdistgit)
    os.chdir(sfdistgit)
    git('remote', 'add',  'gerrit', gerritsf + sfdistgit)
    git('checkout', '-b', 'rdo-liberty')
    # Find inital commit (in order to remove the one added by SF)
    initial = git('rev-list', '--max-parents=0', 'HEAD')
    # Remove the managesf commit
    git('reset', '--hard', initial)
    git('remote', 'add', 'upstream', distgit)
    git('fetch', '--all')
    git('rebase', 'remotes/upstream/rdo-liberty')
    git('remote', 'remove', 'upstream')
    git('push', '-f', 'gerrit', 'rdo-liberty')

def init_mirror(name, mirror, upstream, sf, gerritsf, workdir):
    print "\n--> Init %s on SF" % name
    os.chdir(workdir)
    git('clone', 'http://%s/r/%s' % (sf, name), name)
    os.chdir(name)
    git('remote', 'add',  'gerrit', gerritsf + name)
    # Find inital commit (in order to remove the one added by SF)
    initial = git('rev-list', '--max-parents=0', 'HEAD')
    # Remove the managesf commit
    git('reset', '--hard', initial)
    git('remote', 'add', 'mirror', mirror)
    git('fetch', '--all')
    # Upstream use master-patches (current for liberty)
    # But will use a more logical name here 
    git('checkout', '-b', 'liberty-patches')
    git('checkout', '-b', 'stable/liberty')
    # Today for liberty upstream use master-patches
    git('checkout', 'liberty-patches')
    git('rebase', 'mirror/master-patches')
    git('remote', 'remove', 'mirror')
    git('push', 'gerrit', 'liberty-patches')

    print "\n--> Push %s upstream stable/liberty in mirror stable/liberty" % name
    git('checkout', 'stable/liberty')
    git('remote', 'add', 'upstream', upstream)
    git('fetch', '--all')
    git('rebase', 'upstream/stable/liberty')
    git('remote', 'remove', 'upstream')
    git('push', 'gerrit', '-f', 'stable/liberty')

    print "\n--> Push %s upstream master in mirror master" % name
    git('checkout', 'master')
    git('remote', 'add', 'upstream', upstream)
    git('fetch', '--all')
    git('rebase', 'upstream/master')
    git('remote', 'remove', 'upstream')
    git('push', 'gerrit', '-f', 'master')

    print "\n--> Push %s upstream tags on mirror" % name
    # Need Create Reference/Forge Author/Forge commiter for refs/tags/* and Project Owner
    git('push', 'gerrit', '--tags')

    print "\n--> Find addtionnal patches for %s in liberty-patches" % name
    git('checkout', 'liberty-patches')
    hashes = git('--no-pager', 'log', '--pretty=format:%H').split('\n')
    tags = None
    for h in hashes:
        tags = git('tag', '-l', '--points-at', h)
        if tags:
            tags = tags.split('\n')
            break
    if not tags:
        return
    tag = tags[0]
    print "Most recent tag found in liberty-patches is %s" % tag
    diffs = git('rev-list', '--max-parents=1', '%s..liberty-patches' % tag)
    diffs = diffs.split('\n')
    diffs.reverse()
    print "%s reviews attached to liberty-patches to create ..." % len(diffs)

    print "\n--> First reset liberty-patches to %s" % tag
    git('reset', '--hard', tag)
    git('push', 'gerrit', '-f', 'liberty-patches')

    p = 0
    for diff in diffs:
        p += 1
        print "Create rdo-patch-%s (%s) in liberty-patches" % (p, diff)
        git('checkout', '-b', 'rdo-patch-%s' % p)
        git('cherry-pick', diff)
        git('review', '-i', '-y', 'liberty-patches') 
