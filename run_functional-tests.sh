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

# Set /etc/hosts
grep -q koji.rpmfactory.sftests.com /etc/hosts || echo koji.rpmfactory.sftests.com | sudo tee -a /etc/hosts
grep -q managesf.rpmfactory.sftests.com /etc/hosts || echo managesf.rpmfactory.sftests.com | sudo tee -a /etc/hosts
sudo sed -i /etc/hosts -e "s/^.*koji.rpmfactory.sftests.com/${KOJI_IP} koji koji.rpmfactory.sftests.com/" \
                  -e "s/^.*managesf.rpmfactory.sftests.com/${SF_IP} managesf managesf.rpmfactory.sftests.com/"

# Set instances /etc/hosts
read -d '' HOSTS <<EOF
${KOJI_IP} koji.rpmfactory.sftests.com koji
${SF_IP} managesf.rpmfactory.sftests.com rpmfactory.sftests.com
EOF
for h in koji.rpmfactory.sftests.com managesf.rpmfactory.sftests.com; do
    ssh-keygen -R $h
    ssh -t -t -o StrictHostKeyChecking=no $h "echo '${HOSTS}' | sudo tee -a /etc/hosts"
    if [ "$(ssh $h hostname -f)" != "$h" ]; then
        echo "Hostname setting didn't worked for $h:"
        ssh $h hostname -f
        exit 1
    fi
done

# Fix koji ansible files koji.conf
sed -i koji/ansible/roles/koji-rpmfactory/files/koji.conf -e 's/koji-rpmfactory.ring.enovance.com/koji.rpmfactory.sftests.com/'

# Install ansible galaxies
(cd koji/ansible; exec ansible-galaxy install -r Ansiblefile.yml --force)

# Start koji/ansible playbook
(cd koji/ansible; exec ansible-playbook -i preprod-hosts site.yml --diff --extra-vars "CN=koji.rpmfactory.sftests.com")


# Step3/ Import sf config
# Step4/ Import rdo project
# Step5/ Validate ?
