#!/bin/bash

[ -z "${DEBUG}" ] || set -x
[ -z "${DOMAIN}" ] && DOMAIN="rpmfactory.sftests.com"

# Make sure a cloud is available
if [ -z "${OS_AUTH_URL}" ] || [ -z "${OS_USERNAME}" ]; then
    echo "Source your openrc first"
    exit 1
fi

PIP_DEPS=""

# Make sure ansible<2 is installed
if which ansible &> /dev/null; then
    if [ "$(ansible --version | awk '/ansible/ {print $2}' | cut -d. -f1)" != "1" ]; then
        PIP_DEPS+="ansible<2"
    fi
else
   PIP_DEPS+="ansible<2"
fi

if ! which openstack &> /dev/null; then
   PIP_DEPS+=" python-openstackclient"
fi

echo "Installing: $PIP_DEPS"
[ -n "${PIP_DEPS}" ] && sudo pip install $PIP_DEPS

# Stop previous stack
[ -z "${FRESH_START}" ] || {
    echo -e "[+] Removing nodepool slave"
    nova delete managesf.${DOMAIN} 2> /dev/null
    # FIXME: only destroy instance connected to nodepool network for this DOMAIN
    #for h in $(nova list | grep 'template-.*-image-\|rpmfactory-worker-default-' | awk '{ print $2 }'); do nova delete $h; done
    for ip in $(openstack ip floating list | awk '{ print $2 }'); do openstack ip floating delete $ip; done
    echo -e "[+] Deleting the stack"
    heat stack-delete ${DOMAIN}
    while [ ! -z "$(heat stack-list | grep ${DOMAIN})" ]; do echo -n "."; done
    echo -e "\n[+] Stack deleted"
}

# Check keypair
[ -f ~/.ssh/id_rsa ] || ssh-keygen -N '' -f ~/.ssh/id_rsa
KP_NAME=id_rsa_$(echo ${DOMAIN} | tr '.' '_')
openstack keypair show ${KP_NAME} || openstack keypair create --public-key ~/.ssh/id_rsa.pub ${KP_NAME}

# Start the stack
echo -e "[+] Starting the stack"
heat stack-create --template-file rpmfactory.hot.yaml ${DOMAIN} -P "key_name=${KP_NAME};domain=${DOMAIN}"
while [ -z "$(heat stack-show ${DOMAIN} | grep CREATE_COMPLETE)" ]; do echo -n "."; done
echo -e "\n[+] Stack started"

STACK_INFO=$(heat stack-show ${DOMAIN})
KOJI_IP=$(echo ${STACK_INFO} | sed 's/.*"Public address of the koji instance: \([^"]*\)".*/\1/')
SF_IP=$(echo ${STACK_INFO}     | sed 's/.*"Public address of the SF instance: \([^"]*\)".*/\1/')
SF_SLAVE_NETWORK=$(echo ${STACK_INFO}     | sed 's/.*"Nodepool slave network: \([^"]*\)".*/\1/')
if [ -z "${KOJI_IP}" ] || [ -z "${SF_IP}" ] || [ -z "${SF_SLAVE_NETWORK}" ]; then
    heat stack-show rpmfactory
    echo "ERROR: Couldn't get instances ip"
    exit 1
fi

# Set /etc/hosts to resolve sftests.com domain
grep -q koji.${DOMAIN} /etc/hosts || echo koji.${DOMAIN} | sudo tee -a /etc/hosts
grep -q managesf.${DOMAIN} /etc/hosts || echo managesf.${DOMAIN} | sudo tee -a /etc/hosts
sudo sed -i /etc/hosts -e "s/^.*koji.${DOMAIN}/${KOJI_IP} koji koji.${DOMAIN}/" \
                  -e "s/^.*managesf.${DOMAIN}/${SF_IP} managesf managesf.${DOMAIN}/"

# Set instances /etc/hosts so that "hostname -f" worked as expected (else it fails with 'host not found')
# Probably a cloud-init bug
read -d '' HOSTS <<EOF
${KOJI_IP} koji.${DOMAIN} koji
${SF_IP} managesf.${DOMAIN} ${DOMAIN}
EOF
for h in koji.${DOMAIN} managesf.${DOMAIN}; do
    echo "[+] Waiting for ssh $h:22"
    while true; do
        [ -z "$(ssh-keyscan -p 22 $h 2> /dev/null)" ] || break
        echo -n "."
    done
    # Reset known host key
    ssh-keygen -R $h
    echo "[+] Waiting for ssh access..."
    while true; do
        ssh -o BatchMode=yes -o StrictHostKeyChecking=no centos@$h hostname &> /dev/null && break
        echo -n "."
    done
    # Adds sftests.com to /etc/hosts
    ssh -t -t $h "echo '${HOSTS}' | sudo tee -a /etc/hosts"
done

# Fix ansible hardcoded value for tests
sed -i ansible/roles/koji-rpmfactory/files/koji.conf -e "s/koji-rpmfactory.ring.enovance.com/koji.${DOMAIN}/"
cat ~/.ssh/id_rsa.pub | tee ansible/roles/mirror-rpmfactory/files/authorized_keys > ansible/roles/koji-rpmfactory/files/authorized_keys


# Install ansible galaxies
(cd ansible; exec ansible-galaxy install -r Ansiblefile.yml --force)

# Start rpmfactory+koji deployment playbook
(cd ansible; exec ansible-playbook -i preprod-hosts rpmfactory-and-koji.yml --extra-vars "CN=koji.${DOMAIN} os_username=${OS_USERNAME} os_auth_url=${OS_AUTH_URL} os_password=${OS_PASSWORD} os_tenant_name=${OS_TENANT_NAME} nodepool_net=${SF_SLAVE_NETWORK}")

# Run rpmfactory integration test playbook
(cd ansible; exec ansible-playbook -i preprod-hosts rpmfactory-integration-tests.yml)

# TODO:
# make sure default security group allow ssh
# configure config repos
# run sf integration test to setup nodepool and swift
# import rdo projects
# validate
