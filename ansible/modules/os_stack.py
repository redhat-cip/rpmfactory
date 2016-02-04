#!/usr/bin/python
# coding: utf-8 -*-

# Copyright (c) 2016 Red Hat
#
# This module is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This software is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this software.  If not, see <http://www.gnu.org/licenses/>.


try:
    import shade
    HAS_SHADE = True
except ImportError:
    HAS_SHADE = False


DOCUMENTATION = '''
---
module: os_stack
short_description: Create/Delete Heat Stack from OpenStack
extends_documentation_fragment: openstack
version_added: "2.0.0.2"
author: "Tristan Cacqueray"
description:
   - Create or Delete heat instances from OpenStack.
options:
   name:
     required: true
   state:
     description:
        - present/absent to start/stop the stack
   template:
     description:
        - Template file path
   wait_for_complete:
     description:
        - Wait for operation completion (create or delete) and collect stack outputs
     default: True
   rollback_on_failure:
     description:
        - Rollback the stack on failure
     default: False
   timeout:
     description:
        - Maximum time for wait operations
     default: 180
requirements:
    - "python >= 2.6"
    - "https://review.openstack.org/changes/276487/revisions/7b83aa7279c5a6ca608c76a705b526361bed34a8/archive?format=tgz"
'''

EXAMPLES = '''
# Creates a new instance and attaches to a network and passes metadata to
# the instance
- os_stack:
       state: present
       name: my_stack
       template: ./mystack.yaml
       auth:
         auth_url: https://os_auth_url
         username: demo
         password: demo
         project_name: demo
'''


def main():
    argument_spec = openstack_full_argument_spec(
        name                = dict(required=True),
        template            = dict(default=None),
        wait_for_complete   = dict(default=True),
        rollback_on_failure = dict(default=False),
        timeout             = dict(default=180),
        state               = dict(default='present',
                                   choices=['absent', 'present']),
    )
    module = AnsibleModule(argument_spec)

    if not HAS_SHADE:
        module.fail_json(msg='shade is required for this module')

    name = module.params['name']
    state = module.params['state']
    timeout = int(module.params['timeout'])
    template = module.params['template']
    wait_for_complete = module.params['wait_for_complete']
    rollback_on_failure = module.params['rollback_on_failure']

    def wait_create_complete():
        start_time = time.time()
        while time.time() - start_time < timeout:
            ret = cloud.get_stack(name,
                    {'stack_status': 'CREATE_COMPLETE'})
            if ret:
                break
            time.sleep(0.5)

        if not ret:
            module.fail_json(msg="Stack didn't complete", **stack)
        stack.update(cloud.get_stack_outputs(ret['id']))

    try:
        cloud_params = dict(module.params)
        cloud_params.pop('userdata', None)
        cloud = shade.openstack_cloud(**cloud_params)

        if state == 'present':
            # Check if exists
            stack = cloud.get_stack(name)
            if stack:
                if wait_for_complete:
                    wait_create_complete()
                module.exit_json(changed=False, **stack)

            # Create stack
            stack = cloud.create_stack(name, template_file=template, wait=True,
                                       rollback=rollback_on_failure)
            if not stack:
                module.fail_json(msg="Couldn't create the stack")

            if not wait_for_complete:
                module.exit_json(changed=True, **stack)

            wait_create_complete()
            module.exit_json(changed=True, **stack)
        elif state == 'absent':
            # Check if exists
            stack = cloud.get_stack(name, {'stack_status': 'CREATE_COMPLETE'})
            if not stack:
                module.exit_json(changed=False)

            cloud.delete_stack(name)

            if not wait_for_complete:
                module.exit_json(changed=True)

            start_time = time.time()
            while time.time() - start_time < timeout:
                ret = cloud.get_stack(name)
                if not ret:
                    break
                time.sleep(0.5)
            if ret:
                module.fail_json(msg="Stack delete failed", **ret)
            module.exit_json(changed=True)

    except shade.OpenStackCloudException as e:
        module.fail_json(msg=str(e), extra_data=e.extra_data)

# this is magic, see lib/ansible/module_common.py
from ansible.module_utils.basic import *
from ansible.module_utils.openstack import *
if __name__ == '__main__':
    main()
