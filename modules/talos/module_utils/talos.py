from ansible.module_utils.basic import AnsibleModule

class Talosctl():
    def __init__(self, module: AnsibleModule):
        self.module = module

    def test(self):
        test = self.module.run_command(['talosctl'])
        if test[0] == 0:
            return
        self.module.fail_json(rc=test[0], stdout=test[1], stderr=test[2])
    
    def run_command(self, cmd, exit=True, diff=None, changed=True, **kwargs):
        self.test()
        cmd_args = ['talosctl', cmd]
        if self.module.params['cluster']:
            cmd_args += ['--cluster', self.module.params['cluster']]
        if self.module.params['context']:
            cmd_args += ['--context', self.module.params['context']]
        if self.module.params['endpoints']:
            cmd_args += ['--endpoints'] + self.module.params['endpoints']
        if self.module.params['nodes']:
            cmd_args += ['--nodes'] + self.module.params['nodes']
        if self.module.params['talosconfig']:
            cmd_args += ['--talosconfig', self.module.params['talosconfig']]
        for key, value in kwargs.items():
            if not value:
                continue
            if isinstance(value, list):
                cmd_args += [key] + value
            elif isinstance(value, bool):
                cmd_args += [key]
            else:
                cmd_args += [key, str(value)]
        cmd_result = self.module.run_command(cmd_args)
        if not exit:
            return cmd_result
        result = { 'rc': cmd_result[0], 'stdout': cmd_result[1], 'stderr': cmd_result[2], 'changed': changed }
        if diff:
            result['diff'] = diff
        self.module.exit_json(**result)