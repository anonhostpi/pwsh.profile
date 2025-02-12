<#
function Edit-Profile {
    param(
        [ValidateSet("All", "Current")]
        [string] $User = "Current",
        [ValidateSet("All", "Current")]
        [string] $Hosts = "Current",
	    [string] $Editor = "code"
    )
    $_user = If( $user -eq "All" ){ "AllUsers" } Else { "CurrentUser" }
    $_hosts = If( $hosts -eq "All" ){ "AllHosts" } Else { "CurrentHost" }

    $chosen = $profile."$_user$_hosts"

    if( $Editor -eq "code" ){
        $chosen = $chosen | Split-Path
    }

    $result = & $Editor $chosen

    if( $null -ne $result ){
        $result
    } else {
        $chosen
    }
}

Write-Host "Edit your pwsh profile with: " -ForegroundColor Yellow -NoNewline;
Write-Host "Edit-Profile" -BackgroundColor DarkCyan -ForegroundColor Black -NoNewline; Write-Host;
Write-Host;
#>

function global:Invoke-WildcardScriptfiles {
    [CmdletBinding()]
    param(
        [string[]] $Paths
    )

    $Paths | Resolve-Path | ForEach-Object {
        $_.ToString()
    } | Sort-Object | ForEach-Object {
        Write-Verbose "Running $_"
        & $_
    }
}

Set-Alias -Scope Global -Name "run" -Value "Invoke-WildcardScriptfiles"
Set-Alias -Scope Global -Name "resolve" -Value "Resolve-Path"

# Typing:
# Params: $Value
& "$PSScriptRoot\Utils\Test-Primitive.ps1"

# Path parsing:
# Params: $Path
& "$PSScriptRoot\Utils\Test-WindowsPath.ps1"

& { # Simple Object Methods
    # Params: $Target, $Members
    & "$PSScriptRoot\Utils\Add-NoteProperties.ps1"
    # Params: $Target, $Members
    & "$PSScriptRoot\Utils\Add-ScriptMethods.ps1"
    # Params: $Target, $Members
    & "$PSScriptRoot\Utils\Add-ScriptProperties.ps1"
}

& { # Object-Table Parsing
    # Params: $Path
    & "$PSScriptRoot\Utils\Build-PathTree.ps1"
    # Params: $InputObject, [sb] $Process, [switch] $Flat, [switch] $JsonMode
    & "$PSScriptRoot\Utils\ForEach-Leaf.ps1"
    # Params: $InputObject, $TypeException, [switch] $Shallow
    & "$PSScriptRoot\Utils\ConvertTo-OrderedHashtable.ps1"
    # Params: $InputObject, $IndentLevel, [switch] $Short
    & "$PSScriptRoot\Utils\ConvertTo-Yaml.ps1"

    & { # $Options Object Parsing
        # Exports:
        # > Resolve-Parameter:
        #   > [sb] $Invalidator, [sb] $Cleaner, [sb]? $Defaulter, $Value
        #   - $Original, $Resolving
        # > Resolve-Options:
        #   > $Invalidators, $Cleaners, $Base, $Options
        #   - $Original, $Resolving
        & "$PSScriptRoot\Utils\Arguments.ps1"
    }
}

# Object Factories
# Exports:
# > New-ValidatingFactory
#   > $Options
#     - Invalidators
#     - Cleaners
#     - Base
#     - Postscripts[]
#       - Params: $Object (converted-clean), $Source (converted-unclean), $Original (unconverted), $Trees
#     - Methods
# > New-ValidatingFactory
#   > $Options
#     - ... New-ValdatingFactory $Options ...
#     - LiveProperties
#     ! If $Options.Methods contains OnSave, it is called when the object is saved
# - New-SimpleFactory
#   > $Options
#     - NoteProperties
#     - ScriptMethods
#     - ScriptProperties
#     - Postscripts[]
#       - Params: $Object, $Descriptor, $ConstructorOptions
& "$PSScriptRoot\Utils\ObjectFactories.ps1"

# Clipboard Tools
# Params: $Contents, [switch] $Communicate
& "$PSScriptRoot\Utils\Deploy-Clipboard.ps1"

# Text Processing
# refer to script...
& "$PSScriptRoot\Utils\TextTemplate.ps1"

# User Interaction Tools
& {
    Set-Alias -Scope Global -Name "answer" -Value "Read-Host"
    # Params: [switch] $Multi, $Options[], $Defaults[], $Title, [switch] $ShowSelected
    & "$PSScriptRoot\Utils\Show-Menu.ps1"
    # Params: $Name, $Questions
    & "$PSScriptRoot\Utils\New-Form.ps1"
}

# My Sloppy OneDrive Tools
# - Get-OneDriveNames
# - Get-OneDriveEmails
# - Get-OneDriveRoots
# - Get-SharepointRoots
# > Get-OneDrive
#   > $Key (one of: drive name, email, or path/child-path)
# - Get-OneDriveEndpoint
# > Get-OneDriveDownloadURL
# > Get-OneDriveURL
# > Get-OneDriveChildItems
# > Open-SharepointDrive (useful for syncing)
& "$PSScriptRoot\Utils\SloppyOneDrive.ps1"
