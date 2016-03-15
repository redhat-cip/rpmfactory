RPM Factory
===========

# An addition to Software Factory to build/store RPMs seamlessly

Software Factory is a CI platform that provides a powerful platform
to build software. It is based on Gerrit/Zuul/Jenkins and Nodepool.

RPM Factory is bits to add to a formal Software Factory:

* Default JJB macro to build and export RPM packages in RPM repositories
* Default Nodepool image preparation script

RPM Factory allows to perform gating both at Git repositories and
RPM repositories level.

RPM Factory can be used against an already deployed Koji or CBS.
But RPM Factory also comes with and Ansible playbook to deploy
a Koji instance.

# Running functional tests

Running functional test requires an Openstack Account.
A Software Factory and Koji instances will be spawned, RPM Factory
preparation will be done into the Software Factory instance and
finally a validation playbook is run and validate the default job
for the check and gate Zuul pipelines behave as expected.

```bash
source os.rc
./run_functional-tests.sh
```
