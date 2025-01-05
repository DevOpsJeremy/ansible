<#
    .SYNOPSIS
        Downloads an object using the aws s3api command.
#>
[CmdletBinding()]
param (
    [string] $bucket,
    [string] $object,
    [string] $dest,
    [string] $region,
    [boolean] $force
)
$Ansible.Changed = $false
$destPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($dest)
if (!$force -and (Test-Path -LiteralPath $destPath)){
    return
}
try {
    aws s3api get-object --region $region --bucket $bucket --key $object $destPath
    $Ansible.Changed = $true
} catch {
    $Ansible.Error = $_.Exception.Message
    $Ansible.Failed = $true
}