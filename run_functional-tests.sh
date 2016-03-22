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
    nova list
    managesf_server_id=$(nova list | grep "managesf.${DOMAIN}" | awk '{ print $2 }')
    [ -z "$managesf_server_id" ] || {
        echo -e "[+] Shutdown managesf instance ($managesf_server_id)"
        nova stop $managesf_server_id
    }
    for h in $(nova list | grep "slave_net" | grep "rpmfactory-base-worker" | awk '{ print $2 }'); do
        echo -e "[+] Removing nodepool slave ($h)"
        nova delete $h
        fip_id=$(openstack ip floating list | grep $h | awk '{ print $2 }')
        [ -z "$fip_id" ] || {
            echo -e "[+] Removing nodepool slave floating ip ($fip_id)"
            openstack ip floating delete $fip_id
        }
    done
    echo -e "[+] Deleting the stack"
    heat stack-delete ${DOMAIN}
    let RETRY=300
    while [ ! -z "$(heat stack-list | grep ${DOMAIN})" ]; do
        echo -n "."
        let RETRY-=1
        [ $RETRY -gt 0 ] || { echo "Fail to delete stack, retrying..."; break; }
        sleep 0.5
    done
    heat stack-delete ${DOMAIN}
    let RETRY=300
    while [ ! -z "$(heat stack-list | grep ${DOMAIN})" ]; do
        echo -n "."
        let RETRY-=1
        [ $RETRY -gt 0 ] || { echo "Fail to delete stack"; heat stack-show ${DOMAIN}; exit 1; }
        sleep 0.5
    done
    echo -e "\n[+] Stack deleted"
}

# Check keypair
[ -f ~/.ssh/id_rsa ] || ssh-keygen -N '' -f ~/.ssh/id_rsa
KP_NAME=id_rsa_$(echo ${DOMAIN} | tr '.' '_')
openstack keypair show ${KP_NAME} || openstack keypair create --public-key ~/.ssh/id_rsa.pub ${KP_NAME}

# Start the stack
echo -e "[+] Starting the stack"
heat stack-create --template-file rpmfactory.hot.yaml ${DOMAIN} -P "key_name=${KP_NAME};domain=${DOMAIN}"
RETRY=1800
while [ -z "$(heat stack-show ${DOMAIN} | grep CREATE_COMPLETE)" ]; do
    echo -n "."
    let RETRY-=1
    [ $RETRY -gt 0 ] || { echo "Fail to start stack"; heat stack-show ${DOMAIN}; exit 1; }
    sleep 0.5
done
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

# Update security group for nodepool slave (default secgroup) and access to temp webserver for validation test
echo -e "[+] Make sure security group are set"
neutron security-group-rule-create default --protocol tcp --port-range-min 22 --port-range-max 22 --remote-ip-prefix 0.0.0.0/0
MANAGESF_SECGROUP=$(neutron security-group-list | grep sf_ext_secgroup_http | awk '{ print $4 }')
if [ -z "${MANAGESF_SECGROUP}" ]; then
    echo "ERROR: Couldn't get sf_ext_secgroup_http security group from:"
    neutron security-group-list
    exit 1
fi
neutron security-group-rule-create ${MANAGESF_SECGROUP} --protocol tcp --port-range-min 8999 --port-range-max 8999 --remote-ip-prefix 0.0.0.0/0
echo -e "\n[+] Security group configured"

# Set /etc/hosts to resolve sftests.com domain
grep -q koji.${DOMAIN} /etc/hosts || echo koji.${DOMAIN} | sudo tee -a /etc/hosts
grep -q managesf.${DOMAIN} /etc/hosts || echo managesf.${DOMAIN} | sudo tee -a /etc/hosts
sudo sed -i /etc/hosts -e "s/^.*koji.${DOMAIN}/${KOJI_IP} koji koji.${DOMAIN}/" \
                  -e "s/^.*managesf.${DOMAIN}/${SF_IP} managesf managesf.${DOMAIN} ${DOMAIN}/"

# Set instances /etc/hosts so that "hostname -f" worked as expected (else it fails with 'host not found')
# Probably a cloud-init bug
read -d '' HOSTS <<EOF
${KOJI_IP} koji.${DOMAIN} koji
${SF_IP} managesf.${DOMAIN} ${DOMAIN}
EOF
for h in koji.${DOMAIN} managesf.${DOMAIN}; do
    echo "[+] Waiting for ssh $h:22"
    RETRY=300
    while true; do
        [ -z "$(ssh-keyscan -p 22 $h 2> /dev/null)" ] || break
        echo -n "."
        let RETRY-=1
        [ $RETRY -gt 0 ] || { echo "Fail to connect $h"; exit 1; }
        sleep 0.5
    done
    # Reset known host key
    ssh-keygen -R $h
    echo "[+] Waiting for ssh access..."
    RETRY=300
    while true; do
        ssh -o BatchMode=yes -o StrictHostKeyChecking=no centos@$h hostname &> /dev/null && break
        echo -n "."
        let RETRY-=1
        [ $RETRY -gt 0 ] || { echo "Fail to ssh $h"; exit 1; }
        sleep 0.5
    done
    # Adds sftests.com to /etc/hosts
    ssh -t -t $h "echo '${HOSTS}' | sudo tee -a /etc/hosts"
done

# Fix ansible hardcoded value for tests
sed -i ansible/roles/koji-rpmfactory/files/koji.conf -e "s/koji-rpmfactory.ring.enovance.com/koji.${DOMAIN}/"
cat ~/.ssh/id_rsa.pub | tee ansible/roles/mirror-rpmfactory/files/authorized_keys > ansible/roles/koji-rpmfactory/files/authorized_keys

# Install ansible galaxies
(cd ansible; exec ansible-galaxy install -r Ansiblefile.yml --force)

# Create inventory
inventory="
[koji]
koji.${DOMAIN}

[managesf]
managesf.${DOMAIN}

# Defined for koji-hub role
#TODO(sbadia) fix hub upstream
[koji_web]
koji.${DOMAIN}

[koji_ca]
koji.${DOMAIN}

[koji_db]
koji.${DOMAIN}

[koji_builder]
koji.${DOMAIN}

[koji_hub]
koji.${DOMAIN}
"

echo "$inventory" | sudo tee /tmp/inventory

# Start rpmfactory+koji deployment playbook
(cd ansible; exec ansible-playbook -i /tmp/inventory rpmfactory-and-koji.yml --extra-vars "CN=koji.${DOMAIN}")

# Run rpmfactory integration test playbook
EXTRA_VAR="os_username=${OS_USERNAME} os_auth_url=${OS_AUTH_URL} os_password=${OS_PASSWORD} os_tenant_name=${OS_TENANT_NAME} nodepool_net=${SF_SLAVE_NETWORK}"
EXTRA_VAR+=" sf_domain=${DOMAIN} sf_managesf_ip=${SF_IP} sf_koji_ip=${KOJI_IP}"
(cd ansible; exec ansible-playbook -i /tmp/inventory rpmfactory-integration-tests.yml --extra-vars "${EXTRA_VAR}")
