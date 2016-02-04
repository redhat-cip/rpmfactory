#!/bin/bash

# Prepare ansible and ansible2 venv
[ -d .venv ] || virtualenv .venv
[ -d .venv2 ] || virtualenv .venv2
ANSIBLE=$(pwd)/.venv/bin/ansible
ANSIBLE2=$(pwd)/.venv2/bin/ansible

[ -f ${ANSIBLE} ] || .venv/bin/pip install 'ansible<2'
[ -f ${ANSIBLE2} ] || {
    .venv2/bin/pip install 'ansible>=2' 'git+git://github.com/openstack-infra/shade'
    # Apply local shade patch...
    # https://review.openstack.org/changes/276487/revisions/7b83aa7279c5a6ca608c76a705b526361bed34a8/archive?format=tgz
    for patch in $(pwd)/ansible/modules/os_stack.py.shade_patches/0*[123]*.patch; do
        (cd .venv2/lib/python2.7/site-packages/shade/; patch -p2 --batch) < ${patch}
    done
}
