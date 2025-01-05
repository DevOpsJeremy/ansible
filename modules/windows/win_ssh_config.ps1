#!powershell
#
# Author: Jeremy Watkins

#AnsibleRequires -CSharpUtil Ansible.Basic
using namespace Ansible.Basic
using namespace System.Collections
using namespace System.Reflection

#region Enums & Classes
# Define valid keywords for the SSH configuration file
enum SshKeyword {
    Host
    Match
    AddKeysToAgent
    AddressFamily
    BatchMode
    BindAddress
    BindInterface
    CanonicalDomains
    CanonicalizeFallbackLocal
    CanonicalizeHostname
    CanonicalizeMaxDots
    CanonicalizePermittedCNAMEs
    CASignatureAlgorithms
    CertificateFile
    ChannelTimeout
    CheckHostIP
    Ciphers
    ClearAllForwardings
    Compression
    ConnectionAttempts
    ConnectionTimeout
    ControlMaster
    ControlPath
    ControlPersist
    DynamicForward
    EnableEscapeCommandline
    EnableSSHKeysign
    EscapeChar
    ExitOnForwardFailure
    FingerprintHash
    ForkAfterAuthentication
    ForwardAgent
    ForwardX11
    ForwardX11Timeout
    GatewayPorts
    GlobalKnownHostsFile
    GSSAPIAuthentication
    GSSAPIDelegateCredentials
    HashKnownHosts
    HostbasedAcceptedAlgorithms
    HostbasedAuthentication
    HostKeyAlgorithms
    HostKeyAlias
    Hostname
    IdentitiesOnly
    IdentityAgent
    IdentityFile
    IgnoreUnknown
    Include
    IPQoS
    KbdInteractiveAuthentication
    KbdInteractiveDevices
    KexAlgorithms
    KnownHostsCommand
    LocalCommand
    LocalForward
    LogLevel
    LogVerbose
    MACs
    NoHostAuthenticationForLocalhost
    NumberOfPasswordPrompts
    ObscureKeystrokeTiming
    PasswordAuthentication
    PermitLocalCommand
    PermitRemoteOpen
    PKCS11Provider
    Port
    PreferredAuthentications
    ProxyCommand
    ProxyJump
    ProxyUseFdpass
    PubkeyAcceptedAlgorithms
    PubkeyAuthentication
    RekeyLimit
    RemoteCommand
    RemoteForward
    RequestTTY
    RequiredRSASize
    RevokedHostKeys
    SecurityKeyProvider
    SendEnv
    ServerAliveCoundMax
    ServerAliveInterval
    SessionType
    SetEnv
    StdinNull
    StreamLocalBindMask
    StreamLocalBindUnlink
    StrictHostKeyChecking
    SyslogFacility
    TCPKeepAlive
    Tag
    Tunnel
    TunnelDevice
    UpdatedHostKeys
    User
    UserKnownHostsFile
    VerifyHostKeyDNS
    VisualHostKey
    XAuthLocation
}
# Define valid values for the ControlMaster option
enum ControlMasterOption {
    no
    yes
    ask
    auto
    autoask
}
# Define valid values for the StrictHostKeyChecking option
enum StrictHostKeyCheckingOption {
    ask
    yes
    no
    off
}
class ForwardAgent {
    [ValidateSet(
        'no',
        'yes'
    )]
    [string[]] $Options = 'no', 'yes'

    static [string] GetValueFromBoolean([boolean] $Boolean) {
        $value = switch ($Boolean){
            $true   {'yes'}
            $false  {'no'}
        }
        return $value
    }
}
# Define the SSH host configuration class. Contains properties for each available setting as well as the following method(s):
#   SshHostConfiguration()
#     - The class constructor ("new()")
#   GetLines()
#     - Converts the [SshHostConfiguration] object into the contents for an SSH configuration file. Example:
#       Host newHost
#           ControlMaster no
#           Port 2222
class SshHostConfiguration {
    [ControlMasterOption] $ControlMaster
    [string] $ControlPath
    [string] $ControlPersist
    [boolean] $ForwardAgent
    [string] $Name
    [string[]] $HostKeyAlgorithms
    [string] $Hostname
    [string] $IdentityFile
    [int] $Port = 22
    [string] $ProxyCommand
    [string] $ProxyJump
    [StrictHostKeyCheckingOption] $StrictHostKeyChecking
    [string] $User
    [string] $UserKnownHostsFile

    SshHostConfiguration() {}
    [string[]] GetLines() {
        $return = @()
        $return += ConvertTo-SshConfigString -Key Host -Value $this.Name
        $return += foreach ($property in $this.PSObject.Properties | Where-Object Name -ne Name){
            if ((![string]::IsNullOrEmpty($property.Value) -and $property.Key -ne 'port') -or ($property.Key -eq 'port' -and $property.Value -gt 0)){
                $value = switch ($property.Value){
                    { $_ -is [boolean] }    { [ForwardAgent]::GetValueFromBoolean($_) }
                    Default                 { $property.Value }
                }
                ConvertTo-SshConfigString -Key $property.Name -Value $value -Child
            }
        }
        return $return
    }
}
# Define the SSH configuration class. Contains a Hosts property with [SshHostConfiguration] objects and a Path property with the path to the config file. Also contains the following method(s):
#   SshConfiguration(string Path)
#     - The class constructor using an SSH config file. Creates a new SshConfiguration instance from the provided file.
#   SshConfiguration(SshHostConfiguration[] Hosts)
#     - The class constructor using SshHostConfiguration objects. Creates a new SshConfiguration instance from the provided host config objects.
#   GetHostConfiguration(string Name)
#     - Gets the host object by name. Returns nothing if no name matches.
#   RemoveHostConfiguration(string Name)
#     - Removes the host object by name from the Hosts property and returns the removed host object.
#   GetLines()
#     - Converts the [SshHostConfiguration] objects into the contents for an SSH configuration file.
class SshConfiguration {
    [SshHostConfiguration[]] $Hosts
    [string] $Path

    SshConfiguration([string] $Path) {
        $this.Path = $Path

        $content = [System.IO.File]::ReadAllLines($Path)
        if ([string]::IsNullOrEmpty($content)){
            return
        }

        try {
            $keyValuePairList = $content | ConvertFrom-SshConfigString
        } catch {
            throw $_
        }

        if ($keyValuePairList[0].Key -notin [SshKeyword]::Host, [SshKeyword]::Match){
            throw "Invalid SSH configuration. Found: $($keyValuePairList[0].Key). Expected: $([SshKeyword]::Host), $([SshKeyword]::Match)."
        }

        $sshHostConfig = $null
        foreach ($kvp in $keyValuePairList){
            if ($kvp.Key -in [SshKeyword]::Host, [SshKeyword]::Match){
                if ($sshHostConfig){
                    $this.Hosts += [SshHostConfiguration] $sshHostConfig
                }
                $sshHostConfig = [SshHostConfiguration]::new()
            }
            $key = if ($kvp.Key -eq 'Host') { 'Name' } else { $kvp.Key }
            $sshHostConfig.$Key = $kvp.Value.Trim("`"'")
        }

        $this.Hosts += [SshHostConfiguration] $sshHostConfig
    }
    SshConfiguration([SshHostConfiguration[]] $Hosts) {
        $this.Hosts = $Hosts
    }
    [SshHostConfiguration] GetHostConfiguration([string] $Name) {
        return $this.Hosts | Where-Object Name -eq $Name
    }
    [SshHostConfiguration] RemoveHostConfiguration([string] $Name) {
        $removeHost = $this.Hosts | Where-Object Name -eq $Name
        $this.Hosts = $this.Hosts | Where-Object Name -ne $Name
        return $removeHost
    }
    [string[]] GetLines() {
        $return = foreach ($hostConfig in $this.Hosts){
            $hostConfig.GetLines()
        }
        return $return
    }
}
#endregion Enums & Classes

#region Functions
# Gets the key/value of the SSH configuration line. Example:
#   From:
#     IdentityFile ~/.ssh/id_ecdsa
#   To:
#     Key           Value
#     ---           -----
#     IdentityFile  ~/.ssh/id_ecdsa
function ConvertFrom-SshConfigString {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline)]
        [string] $InputObject
    )
    Process {
        if ($InputObject -match '.+(=| ).+'){
            $regex = [regex]::Match($InputObject.Trim(), '(?<key>[^\s=]+)(?: |=)(?<value>.*)')
            return [PSCustomObject] @{
                Key = [SshKeyword] $regex.Groups['key'].Value
                Value = $regex.Groups['value'].Value
            }
        }
    }
}
# Converts a key/value pair into a string for use in an SSH config file. The Child parameter indents the number of spaces specified by Indent.
function ConvertTo-SshConfigString {
    [CmdletBinding()]
    param (
        [string] $Key,
        [string] $Value,
        [switch] $Child,
        [int] $Indent = 4
    )
    $spaces = if ($Child){
        ' ' * $Indent
    }
    return '{0}{1} {2}' -f $spaces, $Key, $Value
}
#endregion Functions

# Define the spec of the module
$spec = @{
    options = @{
        ssh_config_file             = @{ type = 'str' ; default = "$env:USERPROFILE\.ssh\config" }
        state                       = @{ type = 'str' ; default = 'present' ; choices = 'present', 'absent' }
        host                        = @{ type = 'str' ; required = $true }
        controlmaster               = @{ type = 'str' ; default = 'no' ; choices = 'no', 'yes', 'ask', 'auto', 'autoask' }
        controlpath                 = @{ type = 'str' }
        controlpersist              = @{ type = 'str' }
        forward_agent               = @{ type = 'bool' ; default = $false }
        host_key_algorithms         = @{ type = 'str' }
        hostname                    = @{ type = 'str' }
        identity_file               = @{ type = 'str' }
        proxycommand                = @{ type = 'str' }
        proxyjump                   = @{ type = 'str' }
        port                        = @{ type = 'int' ; default = 22 }
        strict_host_key_checking    = @{ type = 'str' ; default = 'ask' ; choices = 'ask', 'yes', 'no', 'off', 'accept-new' }
        user                        = @{ type = 'str' }
        user_known_hosts_file       = @{ type = 'str' }
    }
    mutually_exclusive = @(
        , @(
            'proxycommand',
            'proxyjump'
        )
    )
    supports_check_mode = $true
}
$module = [AnsibleModule]::Create($args, $spec)
$module.Result.changed = $false

# Cudtom scripts to add to $module.Params
$paramScripts = @{
    # Checks the bound parameters. Example:
    #   Arguments:
    #     host: myHost
    #     state: present
    #     strict_host_key_checking: no
    #
    #   Usage:
    #     $module.Params.CheckParams(@('host', 'state'))
    #
    # The above example returns False. The mandatory parameters host and state do exist, but the user also used strict_host_key_checking, which causes this to return False. If the user included strict_host_key_checking in the OptionalParams or AllowOthers=true, this would return True.
    CheckParams = {
        param (
            [Parameter(Mandatory)]
            # Mandatory parameters to check. If any of these are not used, this returns False
            [string[]] $MandatoryParams,
            # Optional parameters to check. These may or may not be used, but they won't cause the method to return False
            [string[]] $OptionalParams = @(),
            # Whether or not to accept additional prameters
            [boolean] $AllowOthers = $false
        )
        $boundKeys = ($this.GetEnumerator() | Where-Object { ![string]::IsNullOrEmpty($_.Value) }).Key
        if ((Compare-Object -ReferenceObject $MandatoryParams -DifferenceObject $boundKeys).SideIndicator -contains '<='){
            return $false
        }
        if (!$AllowOthers -and (Compare-Object -ReferenceObject ($MandatoryParams + $OptionalParams) -DifferenceObject $boundKeys).SideIndicator -contains '=>'){
            return $false
        }
        return $true
    }
    # Returns all keys, or if values are provided it excludes those keys from the list
    GetKeys = {
        param (
            [string[]] $ExcludeKeys
        )
        $this.Keys | Where-Object { $_ -notin $ExcludeKeys }
    }
}
# Add the scripts to $module.Params
foreach ($script in $paramScripts.GetEnumerator()){
    $module.Params | Add-Member -MemberType ScriptMethod -Name $script.Key -Value $script.Value
}

# If the ssh_config_file doesn't exist and the state is 'absent', exit. If state isn't absent, create the config file and mark the result as changed.
if (!(Test-Path -LiteralPath $module.Params.ssh_config_file)) {
    if ($module.Params.state -eq 'absent') {
        $module.ExitJson()
    }
    [void] (New-Item -Path $module.Params.ssh_config_file -Force)
    $module.Result.changed = $true
}

# Get the SSH configuration object from the config file
$ssh_config = [SshConfiguration]::new($module.Params.ssh_config_file)
# Removes the host from the list and returns it to the ssh_host_config variable
$ssh_host_config = $ssh_config.RemoveHostConfiguration($module.Params.host)

# If 'absent'--if the ssh_host_config exists, return the config without the host. If it doesn't exist, it's already satisfied so exit.
if ($module.Params.state -eq 'absent'){
    if ($ssh_host_config){
        $module.Result.result = $ssh_config.GetLines() 
        $module.Result.result | Set-Content -LiteralPath $module.Params.ssh_config_file
        $module.Result.changed = $true
    }
    $module.ExitJson()
}

# If no host is found, create a new host
if (!$ssh_host_config){
    $ssh_host_config = [SshHostConfiguration] @{
        Name = $module.Params.host
    }
}

# For each parameter provided, loop through and set the new value on the host
foreach ($param in $module.Params.GetKeys(@('host', 'ssh_config_file', 'state'))){
    if (![string]::IsNullOrEmpty($module.Params.$param) -and $ssh_host_config.$($param.Replace('_', '')) -ne $module.Params.$param){
        $ssh_host_config.$($param.Replace('_', '')) = $module.Params.$param
        $module.Result.changed = $true
    }
}

# Add the host back into the Hosts list, output the config text, and exit
$ssh_config.Hosts += $ssh_host_config
$module.Result.result = $ssh_config.GetLines() 
$module.Result.result | Set-Content -LiteralPath $module.Params.ssh_config_file
$module.ExitJson()