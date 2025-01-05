<#
    .SYNOPSIS
        Set git configuration items using the ansible.windows.win_powershell module.
#>
[CmdletBinding()]
param (
    [string] $name,
    [string] $value,
    [ValidateSet(
        'local',
        'global',
        'system'
    )]
    [string] $scope = 'global'
)
$Ansible.Changed = $false
$currentValue = git config --$scope $name
if ([string]::IsNullOrEmpty($currentValue) -or $currentValue -notmatch [regex]::Escape($value)){
    $Ansible.Result = git config --$scope $name $value
    $Ansible.Changed = $true
}