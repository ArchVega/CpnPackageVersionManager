using module .\Classes.psm1

# AppConfig paths should be available everywhere. Placing them in the main module here.
$global:PackageVersionManagerAppFolderPath = Join-Path $env:LOCALAPPDATA -ChildPath "VegaPackageVersionManager"
$global:PackageVersionManagerAppConfigPath = Join-Path $global:PackageVersionManagerAppFolderPath -ChildPath "Configuration.json"

function Get-CsProjPackageReference {
    [CmdletBinding()]
    param(        
        [Parameter()]
        [string[]] $PackageName,
        [Parameter()]
        [string[]] $SourceRootDirectory,
        [Parameter()]
        [switch] $Simple
    )

    $packageNames = $PackageName
    $sourceRootDirectories = $SourceRootDirectory

    if ($PackageName.Count -eq 0) {
        $packageNames = (GetConfig).PackageNames        
    }

    if ($SourceRootDirectory.Count -eq 0) {
        $sourceRootDirectories = (GetConfig).SourceRootDirectories
    }

    $gitDirectories = GetGitDirectories -DirectoryPaths @($sourceRootDirectories)

    $result = @()
    foreach ($gitDirectory in $gitDirectories) {        
        foreach ($packageName in $packageNames) {
            $csProjPackageReferences = $gitDirectory.CsProjFiles | ForEach-Object { [CsProjPackageReference]::new($_.FileInfo, $_.PackageReferences) }
    
            foreach ($csProjPackageReference in $csProjPackageReferences) {
                foreach ($packageReference in $csProjPackageReference.PackageReferences) {
                    if ($packageReference.Name -eq $packageName) {
                        $csProjFileRelPath = $csProjPackageReference.CsProjFileInfo.FullName.Substring($gitDirectory.DirectoryInfo.FullName.Length)

                        if ($Simple.IsPresent) {
                            $result += [pscustomobject][ordered]@{
                                GitDirectoryFullName = $gitDirectory.DirectoryInfo.Name                                
                                CsProjRelativePath   = $csProjFileRelPath
                                PackageName          = $packageReference.Name.Trim()
                                Version              = $packageReference.Version.Trim()
                            }
                        }
                        else {
                            $result += [CsProjPackageReferenceItem]::new(
                                $gitDirectory.DirectoryInfo,
                                $csProjPackageReference.CsProjFileInfo,
                                $csProjFileRelPath,
                                $packageReference.Name,
                                $packageReference.Version
                            )                                 
                        }
                    }
                }
            }
        }
    }    

    if ($Simple.IsPresent) {
        return $result | Sort-Object GitDirectoryFullName, CsProjRelativePath, PackageName
    }

    return $result | Sort-Object CsProjFileInfo, PackageName
}

function Edit-CsProjPackageReference {
    [CmdletBinding(SupportsShouldProcess)]
    param(        
        [Parameter(ValueFromPipeline, Mandatory)]
        [CsProjPackageReferenceItem] $CsProjPackageReferenceItem,
        [Parameter()]
        [switch] $LatestVersion
    )

    begin {
        $fetchedPackages = @{}
    }

    process {
        $xml = [xml] (Get-Content $CsProjPackageReferenceItem.CsProjFileInfo.FullName -Raw)                
        $results = @()
        
        $packageReferences = $xml.Project.ItemGroup.PackageReference        
        foreach ($packageReference in $packageReferences) {
            $package = $fetchedPackages[$packageReference.Include]
            if ($null -eq $package) {
                $package = Get-NexusPackage -PackageName $packageReference.Include
                $fetchedPackages[$packageReference.Include] = $package
            }

            if ($packageReference.Include -eq $package.PackageName) {                
                $packageReference.Version = $package.Version
                $results += [pscustomobject][ordered]@{
                    CsProjFileInfoFullName = $CsProjPackageReferenceItem.CsProjRelativePath
                    PackageName = $package.PackageName
                    FromVersion = $CsProjPackageReferenceItem.Version
                    ToVersion = $package.Version
                }
            }
        }

        if ($PSCmdlet.ShouldProcess($CsProjPackageReferenceItem.CsProjFileInfo.FullName)) {
            $xml.Save($updateAction.CsProjFileInfo.FullName)
        }

        return $results
    }
}

# Move this to shared as it's a duplicate from StoredData
function CreateUserProfileAppFolderIfItDoesNotExist() {    
    if (-not (Test-Path $global:PackageVersionManagerAppFolderPath)) {
        New-Item $global:PackageVersionManagerAppFolderPath -ItemType Directory | Out-Null
    }

    if (-not (Test-Path $global:PackageVersionManagerAppConfigPath)) {
        $appConfig = [AppConfig]::new()
        $appConfig | ConvertTo-Json -Depth 32 | Set-Content $global:PackageVersionManagerAppConfigPath
    }
}

# Move this to shared as it's a duplicate from StoredData
function GetConfig() {
    CreateUserProfileAppFolderIfItDoesNotExist
    return Get-Content $global:PackageVersionManagerAppConfigPath -Raw | ConvertFrom-Json
}

function GetGitDirectories {
    param(
        [Parameter(Mandatory)]
        [ValidateScript({ 
                return -not(($_ | Where-Object { -not (Test-Path -Path $_ -PathType Container) }).Count -gt 0)
            })]
        [string[]] $DirectoryPaths
    )

    $gitDirectories = $DirectoryPaths | ForEach-Object { 
        $dirs = Get-ChildItem -Path $_ -Recurse -Directory -Include ".git" 
        if ($dirs.Count -gt 2) {
            throw "Multiple (nested) .git directories currently not supported"
        }
        return $dirs
    }

    return $gitDirectories | ForEach-Object { [GitDirectory]::new($_.Parent.FullName) }
}

Export-ModuleMember -Function "Get-*", "Set-*", "Test-*", "Edit-*"