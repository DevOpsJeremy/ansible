<#
    .SYNOPSIS
        Validate the XML file stucture. Use with ansible.windows.win_powershell.
#>
[CmdletBinding()]
param (
    [string[]] $files
)
$Ansible.Changed = $false
$failedFiles = foreach ($file in $files){
    try {
        $null = [xml] ([System.IO.File]::ReadAllText($file))
    } catch {
        @{
            file = $file
            error = $_.Exception.Message
        }
    }
}
if ($failedFiles){
    $Ansible.Failed = $true
    $Ansible.Result = $failedFiles
}