#!/usr/bin/python

# Copyright: (c) 2024, Jeremy Watkins <DevOpsJeremy@gmail.com>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)
from __future__ import (absolute_import, division, print_function)
__metaclass__ = type

DOCUMENTATION = r'''
---
module: apply_config

short_description: This is my test module

# If this is part of a collection, you need to use semantic versioning,
# i.e. the version is of the form "2.5.0" and not "2.4".
version_added: "1.0.0"

description: This is my longer description explaining my test module.

options:
    name:
        description: This is the message to send to the test module.
        required: true
        type: str
    new:
        description:
            - Control to demo if the result of this module is changed or not.
            - Parameter description can be a list as well.
        required: false
        type: bool
# Specify this value according to your collection
# in format of namespace.collection.doc_fragment_name
# extends_documentation_fragment:
#     - my_namespace.my_collection.my_doc_fragment_name

author:
    - Your Name (@yourGitHubHandle)
'''

EXAMPLES = r'''
# Pass in a message
- name: Test with a message
  my_namespace.my_collection.my_test:
    name: hello world

# pass in a message and have changed true
- name: Test with a message and changed output
  my_namespace.my_collection.my_test:
    name: hello world
    new: true

# fail the module
- name: Test failure of the module
  my_namespace.my_collection.my_test:
    name: fail me
'''

RETURN = r'''
# These are examples of possible return values, and in general should use other names for return values.
original_message:
    description: The original name param that was passed in.
    type: str
    returned: always
    sample: 'hello world'
message:
    description: The output message that the test module generates.
    type: str
    returned: always
    sample: 'goodbye'
'''
# Relative to the playbook's directory, store this module in:
#   - ./collections/ansible_collections/tools/talos/plugins/modules/apply_config.py
# Then call with:
#   - name: Apply Talos configuration
#     tools.talos.apply_config:
#       nodes: "{{ cluster_controller_ip }}"
#       endpoints: "{{ cluster_controller_ip }}"
#       talosconfig: "{{ talos_config_file }}"
#       file: "{{ machine_config_file }}"
#       # If deploying a new configuration, insecure is mandatory. https://www.talos.dev/v1.9/introduction/getting-started/#apply-configuration
#       insecure: true
import re
from ansible.module_utils.basic import AnsibleModule
# From the playbook's directory, import the talos & tools modules from:
#   - ./collections/ansible_collections/tools/talos/plugins/module_utils/talos.py
#   - ./collections/ansible_collections/tools/talos/plugins/module_utils/tools.py
from ansible_collections.tools.talos.plugins.module_utils.talos import Talosctl
from ansible_collections.tools.talos.plugins.module_utils.tools import *

def is_changed(output):
    return not bool(re.match(r'No changes\.', output[2].splitlines()[-1]))

def is_maint_mode(output):
    return bool(re.match(r'Node is running in maintenance mode and does not have a config yet', output[2].splitlines()[-1]))

def get_diff(output, join=False):
    return strip_leading_lines(remove_up_to_match(output[2], '^Config diff:'), join)

def run_module():
    module = AnsibleModule(
        argument_spec=dict(
            # Global options
            cluster=dict(type='str', required=False),
            context=dict(type='str', required=False),
            endpoints=dict(type='list', required=False),
            nodes=dict(type='list', required=False),
            talosconfig=dict(type='str', required=False),

            # Command specific options
            cert_fingerprint=dict(type='list', required=False),
            config_patch=dict(type='list', required=False),
            file=dict(type='str', required=True),
            insecure=dict(type='bool', required=False, default=False),
            mode=dict(type='str', required=False, default='auto', choices=['auto', 'interactive', 'no-reboot', 'reboot', 'staged', 'try']),
            timeout=dict(type='int', required=False, default=60)
        ),
        supports_check_mode=True
    )
    cmd = 'apply-config'
    cmd_args = {
        '--cert-fingerprint': module.params['cert_fingerprint'],
        '--config-patch': module.params['config_patch'],
        '--file': module.params['file'],
        '--insecure': module.params['insecure'],
        '--mode': module.params['mode'],
        '--dry-run': True
    }
    if module.params['timeout']:
        # The timeout value must be provided in a time format (e.g.: 10s)
        cmd_args['--timeout'] = str(module.params['timeout']) + 's'
    talosctl = Talosctl(module)

    # Run the command with --dry-run to check if the configuration has changed
    dry_run_result = talosctl.run_command(cmd=cmd, exit=False, **cmd_args)
    cmd_args['--dry-run'] = False

    # If dry run fails, fail the module
    if dry_run_result[0] != 0:
        module.fail_json(rc=dry_run_result[0], stdout=dry_run_result[1], stderr=dry_run_result[2], msg=dry_run_result[2])

    base_args = { 'changed': is_changed(dry_run_result) }
    
    diff = None
    # If currently running in diff mode, add the diff to the output
    if module._diff:
        if base_args['changed']:
            diff = get_diff(dry_run_result)
        base_args['diff'] = diff
    
    # If running in check mode, or if there are no changes, exit
    if module.check_mode or not base_args['changed']:
        module.exit_json(**base_args)
    
    # If there are changes and not in check mode, run apply-config
    talosctl.run_command(cmd, exit=True, diff=diff, **cmd_args)

def main():
    run_module()

if __name__ == '__main__':
    main()