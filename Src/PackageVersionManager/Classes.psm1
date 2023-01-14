class PackageReference {
    [string] $Name
    [string] $Version

    PackageReference([string] $name, [string] $version) {
        $this.Name = $Name
        $this.Version = $version
    }
}

class CsProjPackageReference {
    [System.IO.FileInfo] $CsProjFileInfo
    [PackageReference[]] $PackageReferences

    CsProjPackageReference([System.IO.FileInfo] $csProjFileInfo, [PackageReference[]] $packageReferences) {
        $this.CsProjFileInfo = $csProjFileInfo
        $this.PackageReferences = $packageReferences
    }
}

# Combine with above
class SetPackageVersionUpdateAction {
    [System.IO.FileInfo] $CsProjFileInfo
    [string] $PackageName
    [string] $CurrentPackageVersion
    [string] $TargetPackageVersion

    SetPackageVersionUpdateAction([System.IO.FileInfo] $csProjFileInfo, [string] $packageName, [string] $currentPackageVersion, [string] $targetPackageVersion) {
        $this.CsProjFileInfo = $csProjFileInfo
        $this.PackageName = $packageName
        $this.CurrentPackageVersion = $currentPackageVersion
        $this.TargetPackageVersion = $targetPackageVersion
    }
}

class SetPackageVersionFunctionInfo {
    [SolutionDirectory[]] $SolutionDirectories = @()
    [string] $PackageName
    [string] $PackageTargetVersion
    [SetPackageVersionUpdateAction[]] $UpdateActions = @();
    [bool] $PackageExistsInNexus
    [bool] $PackageVersionExistsInNexus

    [void] GenerateUpdateActions() {
        foreach($solutionDirectory in $this.SolutionDirectories) {
            foreach($csProjFile in $solutionDirectory.CsProjFiles) {
                foreach($packageReference in $csProjFile.PackageReferences) {
                    if ($packageReference.Name -eq $this.PackageName -and $packageReference.Version -ne $this.PackageTargetVersion) {
                        $this.UpdateActions += [SetPackageVersionUpdateAction]::new(
                            $csProjFile.FileInfo, 
                            $packageReference.Name, 
                            $packageReference.Version,
                            $this.PackageTargetVersion)
                    }
                }
            }
        }
    }
}

class CsProjFile {
    [System.IO.FileInfo] $FileInfo
    [PackageReference[]] $PackageReferences = @()
    hidden [xml] $xml

    CsProjFile([string] $path) {
        $this.FileInfo = [System.IO.FileInfo]::new($path)
        $this.xml = $this.getXml()
        $this.PackageReferences = $this.GetPackageReferences()
    }

    hidden [xml] getXml() {
        if ($this.FileInfo.Exists) {
            return Get-Content -Path $this.FileInfo.FullName -Raw
        }

        return $null
    }

    [PackageReference[]] GetPackageReferences() {
        return $this.xml.Project.ItemGroup.PackageReference | 
        Where-Object { $null -ne $_ } | 
        ForEach-Object { [PackageReference]::new($_.Include, $_.Version) }    
    }
}

class SolutionDirectory {
    [System.IO.DirectoryInfo] $DirectoryInfo
    [CsProjFile[]] $CsProjFiles = @()    
    
    SolutionDirectory([string] $path) {
        $this.DirectoryInfo = [System.IO.DirectoryInfo]::new($path)
        $this.CsProjFiles = Get-ChildItem -Path $this.DirectoryInfo.FullName -Recurse -Filter "*.csproj" -File | ForEach-Object { [CsProjFile]::new($_.FullName) }
    }    
}

class AppConfig {
    [string] $NexusBaseUrl
}

class NugetPackage {
    [string] $Name
    [string] $Version
    [bool] $IsLatestVersion
    [bool] $IsPreRelease

    NugetPackage($nexusResponseData) {
        $this.Name = $nexusResponseData.Name
        $this.Version = $nexusResponseData.Version
        $this.IsLatestVersion = $nexusResponseData.assets.nuget.is_latest_version
        $this.IsPreRelease = $nexusResponseData.assets.nuget.is_prerelease
    }
}