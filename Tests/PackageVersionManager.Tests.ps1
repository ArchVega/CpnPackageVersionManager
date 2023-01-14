Describe "PackageVersionManager" {
    BeforeAll {
        Import-Module .\Src\PackageVersionManager -Force

        $script:NexusBaseUrl = "http://localhost:8081"

        $script:SlnDir1 = "SlnDir1"
        $script:SlnDir2 = "SlnDir2"
        $script:SlnDir3 = "SlnDir3"
        $script:SlnDir1NonCsProjDir = "SlnDir1\NonCsProjDir"

        $script:SlnDir1CsProjFile1 = "SlnDir1\CsProjDir1\CsProjFile1.csproj"
        $script:SlnDir1CsProjFile2 = "SlnDir1\CsProjDir2\CsProjFile2.csproj"
        $script:SlnDir1CsProjFile3 = "SlnDir1\CsProjDir3\CsProjFile3.csproj"
        $script:SlnDir1CsProjFile4 = "SlnDir1\CsProjDir4\CsProjFile4.csproj"

        function script:SetupTestStubsDirectory() {
            $script:SourceTestStubDirectory = [System.IO.DirectoryInfo]::new(".\Tests\TestFileStubs")
            $script:TargetTestStubDirectory = [System.IO.DirectoryInfo]::new(".\Tests\.TestFileStubs")
            if ($script:TargetTestStubDirectory.Exists) {
                $script:TargetTestStubDirectory.Delete($true)
            }
            Copy-Item $script:SourceTestStubDirectory.FullName -Destination $script:TargetTestStubDirectory -Recurse
        }        

        function script:DeleteAppConfigDirectory() {
            $appFolderPath = Join-Path $env:LOCALAPPDATA -ChildPath "VegaPackageVersionManager"
            $appFolderDirectory = [System.IO.DirectoryInfo]::new($appFolderPath)
            if ($appFolderDirectory.Exists) {
                $appFolderDirectory.Delete($true)
            }
        }

        function script:RelTestPath() {
            return $args | ForEach-Object { Join-Path ".\Tests\.TestFileStubs" -ChildPath $_ }
        }

        function script:FullTestPath() {
            return $args | ForEach-Object { Join-Path (Get-Location).Path -ChildPath "Tests\.TestFileStubs" | Join-Path -ChildPath $_ }
        }

        function script:FileLastWriteTime([string] $filePath) {
            return (Get-Item (script:FullTestPath $filePath)).LastWriteTime
        }
    }

    BeforeEach {
        script:SetupTestStubsDirectory
        script:DeleteAppConfigDirectory
    }

    Context "Get-NexusUrl" {
        It "Returns an empty string if not set" {
            $nexusUrl = Get-NexusUrl
            $nexusUrl | Should -Be $null
        }

        It "Setting the base url then getting it returns the url" {
            Set-NexusUrl -NexusBaseUrl $script:NexusBaseUrl
            $nexusUrl = Get-NexusUrl
            $nexusUrl | Should -Be $script:NexusBaseUrl
        }
    }    

    Context "Set-PackageSource" {
        BeforeEach {
            Set-NexusUrl -NexusBaseUrl $script:NexusBaseUrl
        }

        It "Single solution directory" {
            $actualDirectories = script:RelTestPath $script:SlnDir1
            $expectedDirectories = script:FullTestPath $script:SlnDir1
            $functionInfo = $actualDirectories | Set-PackageReferenceVersion -PackageName "xunit" -PackageVersion "2.4.2" -WhatIf

            $actualDirectories.GetType().Name | Should -Be "String"
            $functionInfo.SolutionDirectories.DirectoryInfo.FullName | Should -Be $expectedDirectories
        }
    
        It "Multiple solutions directory" {
            $actualDirectories = script:RelTestPath $script:SlnDir1 $script:SlnDir2
            $expectedDirectories = script:FullTestPath $script:SlnDir1 $script:SlnDir2
            $functionInfo = $actualDirectories | Set-PackageReferenceVersion -PackageName "xunit" -PackageVersion "2.4.2" -WhatIf

            $actualDirectories.GetType().Name | Should -Be "Object[]"
            $functionInfo.SolutionDirectories.DirectoryInfo.FullName | Should -Be $expectedDirectories
        }

        It "Multiple csproj files" {
            $actualDirectories = script:RelTestPath $script:SlnDir1
            $actualCsProjFiles = @(script:FullTestPath $script:SlnDir1CsProjFile1 $script:SlnDir1CsProjFile2 $script:SlnDir1CsProjFile3 $script:SlnDir1CsProjFile4)
            $functionInfo = $actualDirectories | Set-PackageReferenceVersion -PackageName "xunit" -PackageVersion "2.4.2" -WhatIf
            $functionInfo.SolutionDirectories[0].CsProjFiles.FileInfo.FullName | Should -Be $actualCsProjFiles
        }

        It "Retrieves all valid PackageReference objects" {        
            $actualDirectories = script:RelTestPath $script:SlnDir1
            $functionInfo = $actualDirectories | Set-PackageReferenceVersion -PackageName "xunit" -PackageVersion "2.4.2" -WhatIf
            $packageReferences = $functionInfo.SolutionDirectories[0].CsProjFiles[0].PackageReferences
            $packageReferences[0].Name | Should -Be "JetBrains.Profiler.Api"
            $packageReferences[0].Version | Should -Be "1.1.5"
            $packageReferences[1].Name | Should -Be "NewtonSoft.Json"
            $packageReferences[1].Version | Should -Be "10.0.2"
            $packageReferences[2].Name | Should -Be "Castle.Core"
            $packageReferences[2].Version | Should -Be "5.1.1"
            $packageReferences[3].Name | Should -Be "xunit"
            $packageReferences[3].Version | Should -Be "2.4.2"
        }
    
        It "Function info's package name and target version is set" {        
            $actualDirectories = script:RelTestPath $script:SlnDir1
            $functionInfo = $actualDirectories | Set-PackageReferenceVersion -PackageName "xunit"  -PackageVersion "2.4.2" -WhatIf
            $functionInfo.PackageName | Should -Be "xunit"
            $functionInfo.PackageTargetVersion | Should -Be "2.4.2"
        }

        It "Function info's target updates are correct" {        
            $actualDirectories = script:RelTestPath $script:SlnDir1
            $functionInfo = $actualDirectories | Set-PackageReferenceVersion -PackageName "xunit"  -PackageVersion "2.4.2" -WhatIf
            $updateActions = $functionInfo.UpdateActions

            $updateActions[0].CsProjFileInfo.FullName | Should -Be (script:FullTestPath $script:SlnDir1CsProjFile3)
            $updateActions[0].PackageName | Should -Be "xunit"
            $updateActions[0].CurrentPackageVersion | Should -Be "2.0.0-alpha-build2503"
            $updateActions[0].TargetPackageVersion | Should -Be "2.4.2"

            $updateActions[1].CsProjFileInfo.FullName | Should -Be (script:FullTestPath $script:SlnDir1CsProjFile4)
            $updateActions[1].PackageName | Should -Be "xunit"
            $updateActions[1].CurrentPackageVersion | Should -Be "2.3.0"
            $updateActions[1].TargetPackageVersion | Should -Be "2.4.2"
        }

        It "Get-PackagesVersions returns package version" {
            $packageReferences = script:RelTestPath $script:SlnDir1 | Get-PackageReference -PackageName "xunit"
            $packageReferences[0].CsProjFullName | Should -Be (script:FullTestPath $script:SlnDir1CsProjFile1)
            $packageReferences[1].CsProjFullName | Should -Be (script:FullTestPath $script:SlnDir1CsProjFile3)
            $packageReferences[2].CsProjFullName | Should -Be (script:FullTestPath $script:SlnDir1CsProjFile4)

            $packageReferences[0].Version | Should -Be "2.4.2"
            $packageReferences[1].Version | Should -Be "2.0.0-alpha-build2503"
            $packageReferences[2].Version | Should -Be "2.3.0"
        }

        It "Set-PackageReferenceVersion without -WhatIf updates csproj files as expected" {
            $csProjFile1LastUpdated = script:FileLastWriteTime $script:SlnDir1CsProjFile1
            $csProjFile2LastUpdated = script:FileLastWriteTime $script:SlnDir1CsProjFile2
            $csProjFile3LastUpdated = script:FileLastWriteTime $script:SlnDir1CsProjFile3
            $csProjFile4LastUpdated = script:FileLastWriteTime $script:SlnDir1CsProjFile4
            
            Start-Sleep -Seconds 1
            script:RelTestPath $script:SlnDir1 | Set-PackageReferenceVersion -PackageName "xunit" -PackageVersion "2.4.2"

            # Both files 3 and 4 are older versions, so they will be updated
            script:FileLastWriteTime $script:SlnDir1CsProjFile3 | Should -BeGreaterThan $csProjFile3LastUpdated
            script:FileLastWriteTime $script:SlnDir1CsProjFile4 | Should -BeGreaterThan $csProjFile4LastUpdated

            # File 1 has the current version, and file 2 has no package references, so neither will be updated
            script:FileLastWriteTime $script:SlnDir1CsProjFile1 | Should -BeExactly $csProjFile1LastUpdated
            script:FileLastWriteTime $script:SlnDir1CsProjFile2 | Should -BeExactly $csProjFile2LastUpdated

            $packageReferences = script:RelTestPath $script:SlnDir1 | Get-PackageReference -PackageName "xunit"

            $packageReferences | ForEach-Object { $_.Version | Should -Be "2.4.2" }
        }

        It "Set-PackageReferenceVersion without -WhatIf and an invalid version throws and error" {
            { script:RelTestPath $script:SlnDir1 | Set-PackageReferenceVersion -PackageName "xunit" -PackageVersion "999.999.999" } 
            | Should -Throw "Package version '999.999.999' for package 'xunit' does not exist in Nexus"
        }

        It "Set-PackageReferenceVersion -LatestVersion updates as expected" {
            $latestVersion = script:RelTestPath $script:SlnDir1 | Set-PackageReferenceVersion -PackageName "xunit" -LatestVersion -WhatIf
            $latestVersion.PackageTargetVersion | Should -Be "2.4.2"
        }
    }    
}