#!/bin/bash

if [ $# != 2 ]; then
    echo "Usage: $0 <release pkg url> <repo url>" 1>&2
    exit 1
fi

set -ex

# try to workaround conflicts between pip and rpm

sudo pip uninstall pycrypto || :

# install ansible

sudo yum install -y epel-release
sudo yum install -y python-pip python-crypto git
sudo pip install -U ansible==1.9.2 > ansible_build; ansible --version    
sudo yum remove -y epel-release

# workaround https://bugzilla.redhat.com/show_bug.cgi?id=1284978

if ! rpm -q openstack-packstack; then
    sudo yum install -y http://buildlogs.centos.org/centos/7/cloud/x86_64/openstack-liberty/openstack-packstack-7.0.0-0.7.dev1661.gaf13b7e.el7.noarch.rpm http://buildlogs.centos.org/centos/7/cloud/x86_64/openstack-liberty/openstack-packstack-puppet-7.0.0-0.7.dev1661.gaf13b7e.el7.noarch.rpm http://buildlogs.centos.org/centos/7/cloud/x86_64/openstack-liberty/openstack-puppet-modules-7.0.1-1.el7.noarch.rpm
fi

cd $HOME

[ -d khaleesi ] || git clone https://github.com/redhat-openstack/khaleesi.git
[ -d khaleesi-settings ] || git clone https://github.com/redhat-openstack/khaleesi-settings.git

if [ ! -f .ssh/id_rsa ]; then
    ssh-keygen -N '' -f .ssh/id_rsa
fi
cat .ssh/id_rsa.pub | sudo tee -a /root/.ssh/authorized_keys
sudo cp .ssh/id_rsa* /root/.ssh/

# install ksgen

if ! type -p ksgen; then
    pushd khaleesi/tools/ksgen
    sudo python setup.py install
    popd
fi

pushd khaleesi

# workaround from https://review.gerrithub.io/#/c/253560/

git fetch https://review.gerrithub.io/redhat-openstack/khaleesi refs/changes/60/253560/8 && git checkout FETCH_HEAD

cp ansible.cfg.example ansible.cfg
touch ssh.config.ansible
echo "" >> ansible.cfg
echo "[ssh_connection]" >> ansible.cfg
echo "ssh_args = -F ssh.config.ansible" >> ansible.cfg

export TEST_MACHINE=localhost

ksgen --config-dir=settings generate --provisioner=manual --product=rdo --product-version=liberty --product-version-repo=production --distro=centos-7.0 --installer=packstack --installer-network=none --installer-messaging=none --installer-config=no_change --workarounds=enabled --extra-vars @../khaleesi-settings/hardware_environments/virt_default/hw_settings.yml  --extra-vars product.repo.production.CentOS.7="$2" --extra-vars product.rpmrepo.CentOS="$1" ksgen_settings.yml

anscmd="stdbuf -oL -eL ansible-playbook -b --become-method=sudo --become-user=root -vv --extra-vars @ksgen_settings.yml"

set +e

$anscmd -i local_hosts playbooks/full-job-no-test.yml

result=$?

if [[ $result == 0 ]]; then
    $anscmd -i hosts playbooks/post-deploy/packstack/validate-packstack-aio.yml
    result=$?
fi

infra_result=0
$anscmd -i hosts playbooks/collect_logs.yml &> collect_logs.txt || infra_result=1
$anscmd -i local_hosts playbooks/cleanup.yml &> cleanup.txt || infra_result=2

if [[ "$infra_result" != "0" && "$result" = "0" ]]; then
    # if the job/test was ok, but collect_logs/cleanup failed,
    # print out why the job is going to be marked as failed
    result=$infra_result
    cat collect_logs.txt
    cat cleanup.txt
fi

exit $result
