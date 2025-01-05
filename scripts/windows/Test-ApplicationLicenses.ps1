<#
    .SYNOPSIS
        Validate a Windows application license meets a specified status using the ansible.windows.win_powershell module.
    .EXAMPLE
        - name: Check if Excel has a valid license
          ansible.windows.win_powershell:
            script: "{{ lookup('file', 'Test-ApplicationLicense.ps1') }}"
            parameters:
              application_id: "{{ application_id }}"
              license_status: "{{ license_status }}"
#>
[CmdletBinding()]
param (
    [System.Guid] $application_id,
    [int[]] $license_status
)
$Ansible.Changed = $false
$cimInstance = Get-CimInstance -ClassName SoftwareLicensingProduct -Filter "ApplicationID = '$($application_id.Guid)'" | Where-Object -Property LicenseStatus -in $license_status
if ([string]::IsNullOrEmpty($cimInstance)){
    $Ansible.Failed = $true
    return
}
$Ansible.Result = $cimInstance