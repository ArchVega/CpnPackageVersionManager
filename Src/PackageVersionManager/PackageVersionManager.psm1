using module .\Classes.psm1

$script:AppFolderPath = Join-Path $env:LOCALAPPDATA -ChildPath "VegaPackageVersionManager"
$script:AppConfigPath = Join-Path $script:AppFolderPath -ChildPath "Configuration.json"

# Exported Members ---------------------------------------------------------------------------------------------------------------------------------------

function Get-NexusUrl {
    [CmdletBinding()]
    param()

    CreateUserProfileAppFolderIfItDoesNotExist
    $config = Get-Content $script:AppConfigPath -Raw | ConvertFrom-Json
    
    return $config.NexusBaseUrl
}

function Set-NexusUrl {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateScript({ 
                return [System.Uri]::IsWellFormedUriString($_, 'Absolute')
            })]
        [string] $NexusBaseUrl
    )

    CreateUserProfileAppFolderIfItDoesNotExist
    $config = Get-Content $script:AppConfigPath -Raw | ConvertFrom-Json
    $config.NexusBaseUrl = $NexusBaseUrl
    $config | ConvertTo-Json -Depth 32 | Set-Content $script:AppConfigPath
}

function Get-PackageReference {
    param(
        [Parameter(ValueFromPipeline, Mandatory)]
        [ValidateScript({ 
                Test-Path -Path $_ -PathType Container 
            })]
        [string] $SolutionDirectoryPath,
        [Parameter(Mandatory)]
        [string] $PackageName
    )

    process {
        $solutionDirectory = [SolutionDirectory]::new($SolutionDirectoryPath); 

        $csProjPackageReferences = $solutionDirectory.CsProjFiles | ForEach-Object { [CsProjPackageReference]::new($_.FileInfo, $_.PackageReferences) }

        $result = @()
        foreach($csProjPackageReference in $csProjPackageReferences) {
            foreach($packageReference in $csProjPackageReference.PackageReferences) {
                if ($packageReference.Name -eq $PackageName) {
                    $result += [pscustomobject][ordered]@{
                        CsProjFullName = $csProjPackageReference.CsProjFileInfo.FullName
                        Version = $packageReference.Version
                    }
                }
            }
        }

        return $result
    }
}

function Set-PackageReferenceVersion {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(ValueFromPipeline, Mandatory)]
        [ValidateScript({ 
                Test-Path -Path $_ -PathType Container 
            })]
        [string] $SolutionDirectoryPath,
        [Parameter(Mandatory)]
        [string] $PackageName,
        [Parameter(Mandatory, ParameterSetName = 'SpecificVersion')]
        [string] $PackageVersion,
        [Parameter(Mandatory, ParameterSetName = 'LatestVersion')]
        [switch] $LatestVersion
    )

    begin {
        $info = [SetPackageVersionFunctionInfo]::new();
    }

    process {
        $info.PackageName = $PackageName

        if ($LatestVersion.IsPresent) {
            $info.PackageTargetVersion = Get-NexusPackages -PackageName $PackageName -LatestVersion:$LatestVersion
        }
        else {
            $info.PackageTargetVersion = $PackageVersion
        }        
        
        $solutionDirectory = [SolutionDirectory]::new($SolutionDirectoryPath);
        $info.SolutionDirectories += $solutionDirectory
    }

    end {
        $info.GenerateUpdateActions()
        $info.PackageExistsInNexus = Test-NexusPackageExists $info.PackageName
        if ($info.PackageExistsInNexus) {
            $info.PackageVersionExistsInNexus = Test-NexusPackageVersionExists $info.PackageName $info.PackageTargetVersion
        }

        if (-not $info.PackageExistsInNexus) {
            throw [System.IO.FileNotFoundException]::new("Package '$($info.PackageName)' does not exist in Nexus", $info)  
        }

        if (-not $info.PackageVersionExistsInNexus) {
            throw [System.IO.FileNotFoundException]::new("Package version '$($PackageVersion)' for package '$($info.PackageName)' does not exist in Nexus", $info)
        }

        if ($PSCmdlet.ShouldProcess($SolutionDirectoryPath)) {
            foreach ($updateAction in $info.UpdateActions) {
                $xml = [xml] (Get-Content $updateAction.CsProjFileInfo.FullName -Raw)                
                $packageReferences = $xml.Project.ItemGroup.PackageReference
                foreach ($packageReference in $packageReferences) {
                    if ($packageReference.Include -eq $updateAction.PackageName) {
                        $packageReference.Version = $updateAction.TargetPackageVersion
                    }
                }
                $xml.Save($updateAction.CsProjFileInfo.FullName)            
            }    
        }
        else {
            return $info
        }
    }
}

# Private Members ---------------------------------------------------------------------------------------------------------------------------------------

function CreateUserProfileAppFolderIfItDoesNotExist() {    
    if (-not (Test-Path $script:AppFolderPath)) {
        New-Item $script:AppFolderPath -ItemType Directory | Out-Null
    }

    if (-not (Test-Path $script:AppConfigPath)) {
        $appConfig = [AppConfig]::new()
        $appConfig | ConvertTo-Json -Depth 32 | Set-Content $script:AppConfigPath
    }
}

# Exports

Export-ModuleMember -Function "Get-*", "Set-*", "Test-*"