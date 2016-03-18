RPM Factory
===========

# Additions to Software Factory to build/store RPMs seamlessly

Software Factory is a CI platform that provides a powerful environment
to build software. It is based on Gerrit/Zuul/Jenkins and Nodepool.

RPM Factory is additions to add to a [Software Factory](http://github.com/redhat-cip/software-factory):

* Gating scripts designed to communicate with a Koji builder
* Default JJB macros to build and export RPM packages in RPM repositories
* Default Nodepool image preparation script

RPM Factory allows to perform RPM projects gating two levels:
* at Git repositories
* at RPM repositories

RPM Factory can be used against an already deployed Koji or CBS.
But RPM Factory also comes with and Ansible playbook to deploy
a Koji instance.

# Deploy RPM Factory specialization on an existing SF

RPM Factory comes with an Ansible playbook to ease SF specialization.

This is quite safe to apply it to running SF. Here is the list of
actions that will be performed by the playbook:

- Copy koji client certificate on the SF node
- Install koji client certificate in Jenkins Credential Binding
- Create and activate sfrdobender service user
- Install sfrdobender private key in Jenkins Credential Binding
- Create gating_script project on SF if not exists 
- Push RPM Factory gating scripts in gating_script git repo
- Install RPM Factory Jobs macros (JJB) in the config repo
- Install RPM Factory base nodepool image in the config repo


First configure the role: roles/sf-rpmfactory/defaults/main.yml

```YAML
---
# SF Access
fqdn: "SF hostname"
# SF password to access services as admin
admin_password: "SF password"

# Defaut for bender service user
bender_name: "sfrdobender"
bender_email_name: "sfrdobender"
# Password to be set for that user. Please set a strong one
bender_password: "Service user password"

# Koji server
# Leave it blank
koji_server:
koji_client_cert_path:

```
 
Then prepare an inventory file and run the playbook:

```bash
cat << EOF > /tmp/inv
[managesf]
<SF host>
EOF
cd ansible

# Todo file config

ansible-playbook -i /tmp/inv rpmfactory.yml
```

# Configure jobs to use RPM Factory gating scripts

## Package validation in the "Check" pipeline

Here is an example of job that will request a build againt the koji
build server using the dist-centos7 target. base-pkg-validation builder
is installed by RPM Factory specialization playbook.

base-pkg-validation builder will only perform scratch builds
aginst the koji builder.

Not that by default if koji is given as kojicmd then the koji server
that is used is the one configured before running the Ansible playbook.

Note also that a .spec file should be present at the root of
the git repository this job will handle.

```YAML
- job:
    name: 'package-validate'
    defaults: global
    builders:
      - base-pkg-validation:
          buildtarget: "dist-centos7"
          kojicmd: "koji"
      - shell: |
          # Just built packages are available by installing the below temp release package
          # /home/jenkins/rpmbuild/RPMS/noarch/rpmfactory-temp-release-1.0-1.noarch.rpm
          # Run here tests againts built packages
    triggers:
      - zuul
    wrappers:
      - credentials-binding:
        - file:
           credential-id: <Credential UUID>
           variable: CLIENTSECRET
    node: jenkins-slave-node
```

## Package validation and export in the "Gate" pipeline

Here is an example of a job that should be used in the gate pipeline
to build and store package in Koji. The used builder "base-pkg-exportation"
is a bit special, indeed it is able to wait for other voting jobs (in the Zuul
shared queue belonging to the change currentlty gated) to succeed before triggering
the "no scratch build" on koji.

```YAML
- job:
    name: 'package-export'
    defaults: global
    builders:
      - base-pkg-exportation:
          buildtarget: "dist-centos7"
          kojicmd: "koji"
      - shell: |
          echo "Package has been built and stored on koji !"
    triggers:
      - zuul
    wrappers:
      - credentials-binding:
        - file:
           credential-id: <Credential UUID>
           variable: CLIENTSECRET
    node: rpmfactory-base-worker
```

## An example of zuul configuration for a project

```YAML
projects:
  - name: p1-packaging
    check:
      - package-validate
    gate:
      - package-validate
      - package-export
``` 

# Deploy only koji

TODO

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
