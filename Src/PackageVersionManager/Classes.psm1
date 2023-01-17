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
    [GitDirectory[]] $GitDirectories = @()
    [string] $PackageName
    [string] $PackageTargetVersion
    [SetPackageVersionUpdateAction[]] $UpdateActions = @();
    [bool] $PackageExistsInNexus
    [bool] $PackageVersionExistsInNexus

    [void] GenerateUpdateActions() {
        foreach ($gitDirectory in $this.GitDirectories) {
            foreach ($csProjFile in $gitDirectory.CsProjFiles) {
                foreach ($packageReference in $csProjFile.PackageReferences) {
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

class GitDirectory {
    [System.IO.DirectoryInfo] $DirectoryInfo
    [CsProjFile[]] $CsProjFiles = @()    
    
    GitDirectory([string] $path) {
        $this.DirectoryInfo = [System.IO.DirectoryInfo]::new($path)
        $this.CsProjFiles = Get-ChildItem -Path $this.DirectoryInfo.FullName -Recurse -Filter "*.csproj" -File | ForEach-Object { [CsProjFile]::new($_.FullName) }
    }    
}

class AppConfig {
    [string] $NexusBaseUrl
    [string[]] $SourceRootDirectories
    [string[]] $PackageNames    
}

class VegaSemanticVersion : System.IComparable {
    hidden [Regex] $RegexPattern = [Regex]::new("^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$")
    hidden [Regex] $RegexPattern2 = [Regex]::new("(\d+)\.(\d+)\.(\d+)\.(.*)")
    [int] $Major
    [int] $Minor
    [int] $Patch
    [string] $PreRelease
    [string] $Build
    [string] $Label
    [bool] $IsPreRelease
    [bool] $IsParsable
    [string] $Short

    hidden [string] $semVerString

    VegaSemanticVersion([string] $SemVerString) {
        $this.semVerString = $SemVerString

        $semVerMatches = $this.RegexPattern.Matches($SemVerString)

        if ($semVerMatches.Count -eq 0) {
            $semVerMatches = $this.RegexPattern2.Matches($SemVerString)
        }

        $this.IsParsable = $true

        try {
            $this.Major = $semVerMatches[0].Groups[1].Value
            $this.Minor = $semVerMatches[0].Groups[2].Value
            $this.Patch = $semVerMatches[0].Groups[3].Value
            $this.PreRelease = $semVerMatches[0].Groups[4].Value
            $this.Build = $semVerMatches[0].Groups[5].Value
            $this.Label = "$($this.PreRelease)$($this.Build)"
            $this.IsPreRelease = -not([string]::IsNullOrWhiteSpace($this.PreRelease))
            $this.Short = $this.GenerateSemVerShortTag()
        }
        catch {
            $this.IsParsable = $false
        }
    }

    hidden [string] GenerateSemVerShortTag() {
        return "$($this.Major).$($this.Minor).$($this.Patch)"
    }

    [string] ToString() {
        return $this.semVerString
    }    

    [int] CompareTo($object) {
        if (-not $this.IsParsable) {
            return 0
        }

        if (-not $this.IsParsable) {
            return 0
        }

        $other = [VegaSemanticVersion]$object
        if ($this.Major -gt $other.Major) {
            return 1
        }
        elseif ($this.Major -eq $other.Major) {
            if ($this.Minor -gt $other.Minor) {
                return 1
            }
            elseif ($this.Minor -eq $other.Minor) {
                if ($this.Patch -gt $other.Patch) {
                    return 1
                }
                elseif ($this.Patch -eq $other.Patch) {
                    return $this.Label.CompareTo($other.Label)
                }

                return -1
            }

            return -1
        }

        return -1
    }
}

class NugetPackage {
    [string] $Name
    [string] $Version
    [VegaSemanticVersion] $SemanticVersion
    [bool] $IsLatestVersion
    [bool] $IsPreRelease

    NugetPackage($nexusResponseData) {
        $this.Name = $nexusResponseData.Name
        $this.Version = $nexusResponseData.Version
        $this.IsLatestVersion = $nexusResponseData.assets.nuget.is_latest_version
        $this.IsPreRelease = $nexusResponseData.assets.nuget.is_prerelease
        $this.SemanticVersion = [VegaSemanticVersion]::new($this.Version)
    }
}

class NexusPackageQueryResultItem : System.IComparable {
    [string] $PackageName  
    [NugetPackage] $NugetPackage
    [string] $Version
    [bool] $Exists  

    NexusPackageQueryResultItem($packageName, $nugetPackage, $version, $exists) {
        $this.PackageName = $packageName
        $this.NugetPackage = $nugetPackage
        $this.Version = $version
        $this.Exists = $exists
    }

    [int] CompareTo([object] $obj) {
        try {
            $other = [VegaSemanticVersion]$obj.NugetPackage.SemanticVersion
        
            return $this.NugetPackage.SemanticVersion.CompareTo($other)
        }
        catch {
            return 0
        }
    }
}

class CsProjPackageReferenceItem {
    [System.IO.DirectoryInfo] $GitDirectoryInfo
    [System.IO.FileInfo] $CsProjFileInfo  
    [string] $CsProjRelativePath
    [string] $PackageName       
    [string] $Version           

    CsProjPackageReferenceItem($gitDirectoryInfo, $csProjFileInfo, $csProjRelativePath, $packageName, $version) {
        $this.GitDirectoryInfo = $gitDirectoryInfo
        $this.CsProjFileInfo = $csProjFileInfo
        $this.CsProjRelativePath = $csProjRelativePath
        $this.PackageName = $packageName
        $this.Version = $version
    }
}