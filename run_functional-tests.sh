#!/bin/bash

[ -z "${DEBUG}" ] || set -x

# Make sure a cloud is available
if [ -z "${OS_AUTH_URL}" ] || [ -z "${OS_USERNAME}" ]; then
    echo "Source your openrc first"
    exit 1
fi

# Make sure ansible<2 is installed
if [ "$(ansible --version | awk '/ansible/ {print $2}' | cut -d. -f1)" != "1" ]; then
    sudo pip install 'ansible<2'
fi

# Stop previous stack
echo -e "[+] Deleting the stack"
heat stack-delete rpmfactory
while [ ! -z "$(heat stack-list | grep rpmfactory)" ]; do echo -n "."; done
echo -e "\n[+] Stack deleted"

# Check keypair
[ -f ~/.ssh/id_rsa ] || ssh-keygen -N '' -f ~/.ssh/id_rsa
openstack keypair show id_rsa || openstack keypair create --public-key ~/.ssh/id_rsa.pub id_rsa

# Start the stack
echo -e "[+] Starting the stack"
heat stack-create --template-file rpmfactory.hot.yaml rpmfactory
while [ -z "$(heat stack-show rpmfactory | grep CREATE_COMPLETE)" ]; do echo -n "."; done
echo -e "\n[+] Stack started"

KOJI_IP=$(heat stack-show rpmfactory | grep 'Public address of the koji instance' | sed 's/[^0-9\.]*//g')
SF_IP=$(heat stack-show rpmfactory | grep 'Public address of the SF instance' | sed 's/[^0-9\.]*//g')
if [ -z "${KOJI_IP}" ] || [ -z "${KOJI_IP}" ]; then
    heat stack-show rpmfactory
    echo "Couldn't get instances ip"
    exit 1
fi

# Set /etc/hosts to resolve sftests.com domain
grep -q koji.rpmfactory.sftests.com /etc/hosts || echo koji.rpmfactory.sftests.com | sudo tee -a /etc/hosts
grep -q managesf.rpmfactory.sftests.com /etc/hosts || echo managesf.rpmfactory.sftests.com | sudo tee -a /etc/hosts
sudo sed -i /etc/hosts -e "s/^.*koji.rpmfactory.sftests.com/${KOJI_IP} koji koji.rpmfactory.sftests.com/" \
                  -e "s/^.*managesf.rpmfactory.sftests.com/${SF_IP} managesf managesf.rpmfactory.sftests.com/"

# Set instances /etc/hosts so that "hostname -f" worked as expected (else it fails with 'host not found')
# Probably a cloud-init bug
read -d '' HOSTS <<EOF
${KOJI_IP} koji.rpmfactory.sftests.com koji
${SF_IP} managesf.rpmfactory.sftests.com rpmfactory.sftests.com
EOF
for h in koji.rpmfactory.sftests.com managesf.rpmfactory.sftests.com; do
    echo "[+] Waiting for ssh $h:22"
    while true; do
        [ -z "$(ssh-keyscan -p 22 $h 2> /dev/null)" ] || break
        echo -n "."
    done
    # Reset known host key
    ssh-keygen -R $h
    echo "[+] Waiting for ssh access..."
    while true; do
        ssh -o StrictHostKeyChecking=no centos@$h hostname &> /dev/null && break
        echo -n "."
    done
    # Adds sftests.com to /etc/hosts
    ssh -t -t $h "echo '${HOSTS}' | sudo tee -a /etc/hosts"
done

# Fix ansible hardcoded value for tests
sed -i koji/ansible/roles/koji-rpmfactory/files/koji.conf -e 's/koji-rpmfactory.ring.enovance.com/koji.rpmfactory.sftests.com/'
cat ~/.ssh/id_rsa.pub | tee koji/ansible/roles/mirror-rpmfactory/files/authorized_keys > koji/ansible/roles/koji-rpmfactory/files/authorized_keys


# Install ansible galaxies
(cd koji/ansible; exec ansible-galaxy install -r Ansiblefile.yml --force)

# Start koji/ansible playbook
(cd koji/ansible; exec ansible-playbook -i preprod-hosts site.yml --diff --extra-vars "CN=koji.rpmfactory.sftests.com")

# TODO:
# call sfconfig.sh
# configure config repos
# run sf integration test to setup nodepool and swift
# import rdo projects
# validate
