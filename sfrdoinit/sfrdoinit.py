import os
import sys
import tempfile

from sfrdoinit import sfrdo

# NOTE: USER need to have its key registered in its Gerrit account
# NOTE: USER need to have right to create a ref of Gerrit

# RPMFACTORY access definitions
SF="rpmfactory.beta.rdoproject.org"
USER="fbo"
EMAIL="fboucher@redhat.com"
GERRITSF="ssh://%s@%s:29418/" % (USER, SF)
ADMIN="admin"
PASSWD="" # Admin password
SYNCUSEREMAIL="root@rpmfactory.beta.rdoproject.org" # jenkinsync User

if len(sys.argv) < 3:
    print "Usage:"
    print "%s <rdoinfo.yml> <project-name>" % sys.argv[0]
    sys.exit(1)

rdoinfo_file = sys.argv[1]
upstream_project = sys.argv[2]


selected = sfrdo.fetch_project_infos(rdoinfo_file,
                                     upstream_project)

if not os.path.isfile(rdoinfo_file):
    print "Rdoinfo db file not found."
    sys.exit(1)
if not selected:
    print "Upstream project not found in the rdoinfo db."
    sys.exit(1)

workdir = tempfile.mkdtemp()

upstream, distgit, mirror = sfrdo.flatten_infos(selected)
name = selected['project']
sfdistgit = "%s-distgit" % name

print "Name is: %s" % name
print "Name of distgit on SF is: %s" % sfdistgit
print "Distgit is: %s" % distgit
print "Mirror is: %s" % mirror
print "Workdir is: %s" % workdir
print "Upstream is: %s" % upstream

msf = sfrdo.ManageSfUtils('http://' + SF, ADMIN, PASSWD)

print ""
print "--> Clean proviously initialized project"
msf.deleteProject(name)
msf.deleteProject(sfdistgit)

print "--> Create project mirror: %s" % name
msf.createProject(name)
msf.addUsertoProjectGroups(name, EMAIL, "ptl-group core-group")
msf.addUsertoProjectGroups(name, SYNCUSEREMAIL, "core-group ptl-group")

print "--> Create project distgit: %s" % sfdistgit
msf.createProject(sfdistgit)
msf.addUsertoProjectGroups(sfdistgit, EMAIL, "ptl-group core-group")
msf.addUsertoProjectGroups(sfdistgit, SYNCUSEREMAIL, "core-group ptl-group")

sfrdo.init_distgit(sfdistgit, distgit, SF, GERRITSF, workdir)
sfrdo.init_mirror(name, mirror, upstream, SF, GERRITSF, workdir)
