using module .\Classes.psm1

function Get-StoredNexusUrl {
    [CmdletBinding()]
    param()

    return (GetConfig).NexusBaseUrl
}

function Set-StoredNexusUrl {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({ 
                return [System.Uri]::IsWellFormedUriString($_, 'Absolute')
            })]
        [string] $NexusBaseUrl
    )

    $config = GetConfig
    $config.NexusBaseUrl = $NexusBaseUrl
    UpdateConfig $config
}

# Todo - there are no singluar functions for these, so although we should be using singular nouns, for this version, using plural
function Get-StoredSourceRootDirectories {
    [CmdletBinding()]
    param()

    return (GetConfig).SourceRootDirectories
}

function Set-StoredSourceRootDirectories {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({ 
                return -not(($_ | Where-Object { -not (Test-Path -Path $_ -PathType Container) }).Count -gt 0)
            })]
        [string[]] $SourceRootDirectories
    )

    $config = GetConfig
    $config.SourceRootDirectories = $SourceRootDirectories
    UpdateConfig $config
}

function Get-StoredPackageNames {
    [CmdletBinding()]
    param()

    return (GetConfig).PackageNames
}

function Set-StoredPackageNames {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]] $PackageNames
    )

    $config = GetConfig
    $config.PackageNames = $PackageNames
    UpdateConfig $config
}

# Private Members ---------------------------------------------------------------------------------------------------------------------------------------

function CreateUserProfileAppFolderIfItDoesNotExist() {    
    if (-not (Test-Path $global:PackageVersionManagerAppFolderPath)) {
        New-Item $global:PackageVersionManagerAppFolderPath -ItemType Directory | Out-Null
    }

    if (-not (Test-Path $global:PackageVersionManagerAppConfigPath)) {
        $appConfig = [AppConfig]::new()
        $appConfig | ConvertTo-Json -Depth 32 | Set-Content $global:PackageVersionManagerAppConfigPath
    }
}

function GetConfig() {
    CreateUserProfileAppFolderIfItDoesNotExist
    return Get-Content $global:PackageVersionManagerAppConfigPath -Raw | ConvertFrom-Json
}

function UpdateConfig($config) {
    CreateUserProfileAppFolderIfItDoesNotExist    
    $config | ConvertTo-Json -Depth 32 | Set-Content $global:PackageVersionManagerAppConfigPath
}