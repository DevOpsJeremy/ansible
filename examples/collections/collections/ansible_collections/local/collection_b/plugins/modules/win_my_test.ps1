#!powershell

# Copyright: (c) 2025, Jeremy Watkins <jeremy.watkins@example.org>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic
using namespace Ansible.Basic

# define available arguments/parameters a user can pass to the module
$spec = @{
    options = @{
        name    = @{ type = 'str' ; required = $true }
        new     = @{ type = 'bool' ; required = $false ; default = $false }
    }
    supports_check_mode = $true
}

# seed the result dict in the object
# we primarily care about changed and state
# changed is if this module effectively modified the target
# state will include any data that you want your module to pass back
# for consumption, for example, in a subsequent task
$result = @{
    changed = $false
    original_message = ''
    message = ''
}

# the AnsibleModule object will be our abstraction working with Ansible
# this includes instantiation, a couple of common attr would be the
# args/params passed to the execution, as well as if the module
# supports check mode
$module = [AnsibleModule]::Create($args, $spec)

# if the user is working with this module in only check mode we do not
# want to make any changes to the environment, just return the current
# state with no modifications
if ($module.check_mode) {
    $module.Result = $result
    $module.ExitJson()
}

# manipulate or modify the state as needed (this is going to be the
# part where your module will do what it needs to do)
$result.original_message = $module.Params.name
$result.message = 'goodbye'

# use whatever logic you need to determine whether or not this module
# made any modifications to your target
if ($module.Params.new) {
    $result.changed = $true
}

$module.Result = $result

# during the execution of the module, if there is an exception or a
# conditional state that effectively causes a failure, run
# AnsibleModule.FailJson() to pass in the message and the result
if ($module.Params.name -eq 'fail me') {
    $module.FailJson("You requested this to fail")
}

# in the event of a successful module execution, you will want to
# simple AnsibleModule.ExitJson(), passing the key/value results
$module.ExitJson()