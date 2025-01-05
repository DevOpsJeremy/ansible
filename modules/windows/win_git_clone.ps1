#!powershell
#
# Author: Jeremy Watkins

#AnsibleRequires -CSharpUtil Ansible.Basic
using namespace Ansible.Basic
using namespace System.IO

#region Enums
enum RepositoryProperty {
    Name
    Url
    Path
    Commit
    RefSpec
    Submodules
}
enum RefSpecType {
    tag
    branch
}
#endregion Enums

#region Classes
# Defines a git refspec (such as a branch or tag)
class RefSpec {
    [string] $Name
    [RefSpecType] $Type

    [string] ToString() {
        return $this.Name
    }

    # Get the refspec from a repository. This method tries to get a branch and if no branch, runs git config --get remote.origin.fetch to get the remote fetch reference. If it's not a tag, this method fails. This may happen if the repo is tracking a specific commit, in the case of 'git switch --detach 7061f916ab541d810d594e5071bf45a4981ae943'
    static [RefSpec] GetRefSpec([string] $RepositoryPath){
        $return = if ($branch = [Git]::GetBranch($RepositoryPath)){
            @{  
                Name = $branch
                Type = [RefSpecType]::Branch
            }
        } else {
            $fetchRef = [Git]::Cmd(@('config','--get','remote.origin.fetch'), $RepositoryPath).split(':')[1]
            if ($fetchRef -notmatch 'tags'){
                throw "Ref is not a branch or a tag."
            }
            @{
                Name = $fetchRef -replace 'refs/tags/'
                Type = [RefSpecType]::Tag
            }
        }
        return $return
    }
}

# A class representing  various git functionality
class Git {
    #region Static methods
    # Runs ad-hoc git commands. Arguments are passed in as an array of strings. This method is used by all other [Git] methods to run the respective git commands.
    static [string[]] Cmd([string[]] $Arguments) {
        $return = $null
        try {
            $return = (git $Arguments)
            if ($?){
            } else {
            }
        } catch { throw $_ }
        return $return
    }

    # Runs ad-hoc git commands from a specified directory
    static [string[]] Cmd([string[]] $Arguments, [string] $RepositoryPath) {
        Push-Location -LiteralPath $RepositoryPath
        $return = [Git]::Cmd($Arguments)
        Pop-Location
        return $return
    }

    # Runs git branch --show-current to get the current branch
    static [string] GetBranch([string] $RepositoryPath) {
        return [Git]::Cmd(@('branch', '--show-current'), $RepositoryPath)
    }

    # Runs git rev-parse HEAD to get the current local commit
    static [string] GetCommit([string] $RepositoryPath) {
        return [Git]::Cmd(@('rev-parse','HEAD'), $RepositoryPath)
    }

    # Runs git config --get remote.origin.url to get the remote URL configured in the repo
    static [Uri] GetRemoteOriginUrl([string] $RepositoryPath) {
        return [string] ([Git]::Cmd(@('config','--get','remote.origin.url'), $RepositoryPath))
    }

    # Runs git rev-parse --is-inside-work-tree to test if a directory is a git repository
    static [boolean] IsRepo([string] $RepositoryPath) {
        $revParse = [Git]::Cmd(@('rev-parse', '--is-inside-work-tree'), $RepositoryPath)
        try {
            return [boolean]::Parse($revParse)
        } catch {
            return $false
        }
    }

    # Gets the remote URL for a repo and compares it with the provided URL to see if they match
    static [boolean] MatchRepo([string] $RepositoryPath, [Uri] $RepositoryUrl) {
        return [Git]::GetRemoteOriginUrl($RepositoryPath).AbsoluteUri -match [regex]::Escape($RepositoryUrl.AbsoluteUri)
    }

    # Runs git config --file .gitmodules --get-regexp '^submodule\..*' to get a list of all submodules in a repository. It then transforms them and returns as [Submodule] objects.
    static [Submodule[]] GetSubmodules([Repository] $Repository) {
        [SubmoduleConfig[]] $configs = [Git]::Cmd(
            @(
                'config', 
                '--file', 
                ($Repository.Path, '.gitmodules' -join '/'), 
                '--get-regexp', 
                '^submodule\..*'
            )
        ) | Select-String -Pattern '^submodule\.(?<submodule>[^\.]+)\.(?<variable>[^ ]+)\s+(?<value>.*)' | Group-Object -Property {
            ($_.Matches.Groups | Where-Object Name -eq submodule).Value
        } | Select-Object -Property Name, @{
            Name = 'Variables'
            Expression = {
                $variables = @{}
                $_.Group.ForEach({
                    $variables[$_.Matches.Groups.Where({ $_.Name -eq 'variable' }).Value] = $_.Matches.Groups.Where({ $_.Name -eq 'value' }).Value
                })
                $variables
            }
        }
        return $configs.ForEach({ [Submodule]::new($_, $Repository) })
    }

    # Clones a git repository using the provided arguments
    static [Repository] Clone([array] $Arguments) {
        $cloneArgs = @('clone')
        $Arguments.ForEach({ $cloneArgs += $_ })
        [void] ([Git]::Cmd($cloneArgs))
        if (([Uri] $cloneArgs[-1]).Scheme -eq 'file'){
            return [Repository]::new($cloneArgs[-1], $cloneArgs[-2])
        }
        return [Repository]::new((Get-Item -LiteralPath [Path]::GetFileNameWithoutExtension($cloneArgs[-1])).FullName, $cloneArgs[-1])
    }

    # Clones a git repository with a Depth specified (--depth)
    static [Repository] Clone([Uri] $RepositoryUrl, [string] $Destination, [int] $Depth) {
        return [Git]::Clone(@('--depth', $RepositoryUrl, $Destination))
    }

    # Clones a git repository with Recursive (--recurse-submodules), Depth (--depth), and RefSpec (--branch)
    static [Repository] Clone([Uri] $RepositoryUrl, [string] $Destination,  [boolean] $Recursive, [int] $Depth, [string] $RefSpec) {
        $cloneOptions = @(
            '--depth',
            $Depth,
            '--branch',
            $RefSpec
        )
        if ($Recursive){
            $cloneOptions += '--recurse-submodules'
        }
        $cloneOptions += $RepositoryUrl, $Destination
        return [Git]::Clone($cloneOptions)
    }

    # Clones a git repository with Recursive (--recurse-submodules), Depth (--depth), RefSpec (--branch), and SingleBranch (--single-branch)
    static [Repository] Clone([Uri] $RepositoryUrl, [string] $Destination,  [boolean] $Recursive, [int] $Depth, [string] $RefSpec, [boolean] $SingleBranch) {
        $cloneOptions = @(
            '--depth',
            $Depth,
            '--branch',
            $RefSpec
        )
        if ($SingleBranch){
            $cloneOptions += '--single-branch'
        }
        if ($Recursive){
            $cloneOptions += '--recurse-submodules'
        }
        $cloneOptions += $RepositoryUrl, $Destination
        return [Git]::Clone($cloneOptions)
    }
    #endregion Static methods
}

# Defines a git repository object
class Repository {
    [string] $Name
    [Uri] $Url
    [string] $Path
    [string] $Commit
    [RefSpec] $RefSpec
    [Submodule[]] $Submodules

    #region Constructors
    Repository() {}

    # Class constructor to create new object with [Repository]::new("C:\some\path", "https://some.url/path.git"). The Commit, Branch, and Submodules take some time to capture, so this builds a bare repository that can be loaded at a later time.
    Repository([string] $Path, [Uri] $Url) {
        try {
            $this.Path = Resolve-Path -LiteralPath $Path -ErrorAction Stop
            if (![Git]::IsRepo($this.Path)){
                throw "'$($this.Path)' is not a repository."
            }
            $this.Url = $Url
            $this.Name = [Path]::GetFileNameWithoutExtension($this.Url)
        } catch {
            throw $_
        }
    }
    #endregion Constructors

    #region Methods
    # Converts the repository object to a string (the Name parameter)
    [string] ToString() {
        return $this.Name
    }

    # Loads various properties on the object. Since certain properties like Commit, RefSpec, Submodules, etc. take longer to get (because they're running git commands), the object is created without them by default. This method allows any of them to be generated when needed.
    [void] Load([RepositoryProperty[]] $Properties) {
        try {
            switch ($Properties){
                Url         {
                    $this.Url = [Git]::GetRemoteOriginUrl($this.Path)
                }
                Name        {
                    if ([string]::IsNullOrEmpty($this.Url)){
                        $this.Load([RepositoryProperty]::Url)
                    }
                    $this.Name = [Path]::GetFileNameWithoutExtension($this.Url)
                }
                Commit      {
                    $this.Commit = [Git]::GetCommit($this.Path)
                }
                RefSpec      {
                    $this.RefSpec = [RefSpec]::GetRefSpec($this.Path)
                }
                Submodules  {
                    $this.Submodules = [Git]::GetSubmodules($this)
                }
            }
        } catch {
            throw $_
        }
    }

    # Cleans (git clean), resets (git reset), and updates (git pull) the repository. Returns boolean indicating whether or not changes were made.
    [boolean] Update([boolean] $Recursive) {
        $clean = $this.Clean($true)
        $pullArgs = @('pull')
        if ($Recursive){ $pullArgs += '--recurse-submodules' }
        if (!$clean -and !([Git]::Cmd($pullArgs, $this.Path) -match '\b[0-9a-z]{7}[.]{2}[0-9a-z]{7}\b')){ return $false }
        $this.Commit = [Git]::GetCommit($this.Path)
        return $true
    }

    # Resets the repository with git reset --hard. Returns boolean indicating whether or not changes were made.
    [boolean] Reset([boolean] $Hard) {
        $preStatus = [Git]::Cmd(@('status', '-s'), $this.Path)
        $resetArgs = @('reset')
        if ($Hard){ $resetArgs += '--hard' }
        [void] ([Git]::Cmd(@($resetArgs), $this.Path))
        $postStatus = [Git]::Cmd(@('status', '-s'), $this.Path)
        return !($preStatus -eq $postStatus)
    }

    # (Optionally) resets the repository, then cleans the repository with git clean -dxf. Returns boolean indicating whether or not changes were made.
    [boolean] Clean([boolean] $Reset) {
        $return = @()
        if ($Reset){
            $return += $this.Reset($true)
        }
        $return += ![string]::IsNullOrEmpty([Git]::Cmd(@('clean', '-dxf'), $this.Path))
        return $true -in $return
    }
    #endregion Methods
}

# Defines a submodule configuration object. This is the object-structured version of the contents of the .gitmodules config file
class SubmoduleConfig {
    [string] $Name
    [Hashtable] $Variables

    [string] ToString() {
        return $this.Name
    }
}

# Defines a git submodule object. The base class is [Repository], so it has all the properties and methods of that class, with the addition of the parent repo (superproject) and the git submodule config
class Submodule : Repository {
    [Repository] $Parent
    [SubmoduleConfig] $Config

    #region Constructors
    # Creates a new Submodule object
    Submodule([SubmoduleConfig] $Config, [Repository] $Parent) {
        $this.Parent = $Parent
        $this.Config = $Config
        $this.Name = [Path]::GetFileNameWithoutExtension($this.Config.Name)
        $this.Path = Resolve-Path -LiteralPath (Join-Path -Path $Parent.Path -ChildPath $this.Config.Variables.path)
        $this.Url = $this.Config.Variables.url
        if ($this.Config.Variables.branch){
            $this.RefSpec = [RefSpec] @{
                Name = $this.Config.Variables.branch
                Type = [RefSpecType]::Branch
            }
        }
    }
    #endregion Constructors

    [string] ToString() {
        return $this.Name
    }
}
#endregion Classes

# Define the spec of the module
$spec = @{
    options = @{
        repo            = @{ type = 'str' ; required = $true ; aliases = 'name' }
        dest            = @{ type = 'str' ; required = $true ; aliases = 'path' }
        state           = @{ type = 'str' ; default = 'present' ; choices = 'present', 'updated' }
        refspec         = @{ type = 'str' }
        single_branch   = @{ type = 'bool' ; default = $false ; choices = $true, $false }
        depth           = @{ type = 'int' ; default = 1 }
        recursive       = @{ type = 'bool' ; default = $false ; choices = $true, $false }
    }
}
$module = [AnsibleModule]::Create($args, $spec)
$module.Result.changed = $false

# Fail if negative depth
if ($module.Params.depth -lt 1){
    $module.FailJson("Depth $depth is not a positive number")
}

# Add Git to PATH variable
$env:Path = $env:Path, "C:\Program Files\Git\bin", "C:\Program Files\Git\usr\bin", "C:\Program Files (x86)\Git\bin", "C:\Program Files (x86)\Git\usr\bin" -join ';'

# Redirect git output
$env:GIT_REDIRECT_STDERR = '2>&1'
try {
    # If directory exists and it is not empty
    if (([Directory]::Exists($module.Params.dest)) -and (![string]::IsNullOrEmpty([Directory]::EnumerateFileSystemEntries($module.Params.dest)))){
        # Fail if the directory is not a git repository.
        if (![Git]::IsRepo($module.Params.dest)){
            $module.FailJson("The provided path '$($module.Params.dest)' is not empty.")
        }

        # Fail if the git repository doesn't match the URL provided in the "repo" parameter.
        if (![Git]::MatchRepo($module.Params.dest, $module.Params.repo)){
            $module.FailJson("A git repository already exists at '$($module.Params.dest)'.")
        }

        # Exit if the desired state is simply "present"
        if ($module.Params.state -eq 'present'){
            $module.Result.result = "The repository exists."
            $module.ExitJson()
        }

        $gitRepo = [Repository]::new($module.Params.dest, $module.Params.repo)
    }

    # The $gitRepo variable only exists if the repo already exists and the desired state is "updated", so this will check if it's updated and if not, update it.
    if ($gitRepo) {
        $module.Result.changed = $gitRepo.Update($module.Params.recursive)

        if ($module.Result.changed){
            $module.Result.result = "The $($gitRepo.Name) repository has been updated."
            $module.ExitJson()
        }
        $module.Result.result = "The $($gitRepo.Name) is up to date."
        $module.ExitJson()
    }

    if ([string]::IsNullOrEmpty($module.Params.refspec)){
        $gitRepo = [Git]::Clone(
            $module.Params.repo,        # Repository URL
            $module.Params.dest,        # Destination
            $module.Params.recursive,   # Recursive
            $module.Params.depth        # Depth
        )
    } else {
        $gitRepo = [Git]::Clone(
            $module.Params.repo,            # Repository URL
            $module.Params.dest,            # Destination
            $module.Params.recursive,       # Recursive
            $module.Params.depth,           # Depth
            $module.Params.refspec,         # RefSpec
            $module.Params.single_branch    # Single branch
        )
    }
    if ($?){
        $module.Result.changed = $true
    }

    # Remove git redirect variable
    Remove-Item Env:\GIT_REDIRECT_STDERR

    $module.Result.result = "Cloned the $($gitRepo.Name) repository."
    $module.ExitJson()
} catch { $module.FailJson($_.Exception) }