Describe "PackageVersionManager" {
    BeforeAll {
        . .\Tests\_TestHelpers.ps1
        Import-Module .\Src\PackageVersionManager -Force
    }

    BeforeEach {
        script:SetupTestStubsDirectory
        script:DeleteAppConfigDirectory
    }

    Context "Get-CsProjPackageReference" {        
        It "By StoredPackageNames and StoredRootDirectories" {
            # Arrange
            Set-StoredPackageNames @("xunit", "Newtonsoft.Json", "Castle.Core", "Serilog.Sinks.Console", "JetBrains.Profiler.Api")
            Set-StoredSourceRootDirectories @((script:RelTestPath $script:ApplicationGroup1Dir), (script:RelTestPath $script:ApplicationGroup3Dir))

            # Act
            $results = Get-CsProjPackageReference -Simple

            # Assert
            $results.Count | Should -Be 11
            $results[0] | script:OutputShouldBe "SlnDir1,\CsProjDir1\CsProjFile1.csproj,Castle.Core,5.1.1"
            $results[1] | script:OutputShouldBe "SlnDir1,\CsProjDir1\CsProjFile1.csproj,JetBrains.Profiler.Api,1.1.5"
            $results[2] | script:OutputShouldBe "SlnDir1,\CsProjDir1\CsProjFile1.csproj,Newtonsoft.Json,10.0.2"
            $results[3] | script:OutputShouldBe "SlnDir1,\CsProjDir1\CsProjFile1.csproj,Serilog.Sinks.Console,4.1.1-dev-00901"
            $results[4] | script:OutputShouldBe "SlnDir1,\CsProjDir1\CsProjFile1.csproj,xunit,2.4.2"
            $results[5] | script:OutputShouldBe "SlnDir1,\CsProjDir3\CsProjFile3.csproj,xunit,2.0.0-alpha-build2503"
            $results[6] | script:OutputShouldBe "SlnDir1,\CsProjDir4\CsProjFile4.csproj,xunit,2.3.0"
            $results[7] | script:OutputShouldBe "SlnDir2,\CsProjDir\CsProjFile5.csproj,JetBrains.Profiler.Api,1.3.0"
            $results[8] | script:OutputShouldBe "SlnDir2,\CsProjDir\CsProjFile5.csproj,Serilog.Sinks.Console,3.1.1"
            $results[9] | script:OutputShouldBe "SlnDir3,\CsProjDir\CsProjFile6.csproj,Newtonsoft.Json,6.0.3"
            $results[10] | script:OutputShouldBe "SlnDir3,\CsProjDir\CsProjFile6.csproj,Serilog.Sinks.Console,4.1.1-dev-00896"
        }
        
        It "By multiple PackageNames and StoredRootDirectories" {
            # Arrange
            Set-StoredSourceRootDirectories @((script:RelTestPath $script:ApplicationGroup1Dir), (script:RelTestPath $script:ApplicationGroup3Dir))

            # Act
            $results = Get-CsProjPackageReference -Simple -PackageName @("xunit", "Newtonsoft.Json")

            # Assert
            $results.Count | Should -Be 5
            $results[0] | script:OutputShouldBe "SlnDir1,\CsProjDir1\CsProjFile1.csproj,Newtonsoft.Json,10.0.2"
            $results[1] | script:OutputShouldBe "SlnDir1,\CsProjDir1\CsProjFile1.csproj,xunit,2.4.2"
            $results[2] | script:OutputShouldBe "SlnDir1,\CsProjDir3\CsProjFile3.csproj,xunit,2.0.0-alpha-build2503"
            $results[3] | script:OutputShouldBe "SlnDir1,\CsProjDir4\CsProjFile4.csproj,xunit,2.3.0"
            $results[4] | script:OutputShouldBe "SlnDir3,\CsProjDir\CsProjFile6.csproj,Newtonsoft.Json,6.0.3"
        }

        It "By a single specific PackageName and StoredRootDirectories" {
            # Arrange
            Set-StoredSourceRootDirectories @((script:RelTestPath $script:ApplicationGroup1Dir), (script:RelTestPath $script:ApplicationGroup3Dir))

            # Act
            $results = Get-CsProjPackageReference -Simple -PackageName "xunit"

            # Assert
            $results.Count | Should -Be 3
            $results[0] | script:OutputShouldBe "SlnDir1,\CsProjDir1\CsProjFile1.csproj,xunit,2.4.2"
            $results[1] | script:OutputShouldBe "SlnDir1,\CsProjDir3\CsProjFile3.csproj,xunit,2.0.0-alpha-build2503"
            $results[2] | script:OutputShouldBe "SlnDir1,\CsProjDir4\CsProjFile4.csproj,xunit,2.3.0"
        }

        It "By multiple PackageNames and SpecifiedRootDirectories" {
            # Arrange
            $specifiedSourceRootDirectories = @((script:RelTestPath $script:ApplicationGroup1Dir), (script:RelTestPath $script:ApplicationGroup3Dir))

            # Act
            $results = Get-CsProjPackageReference -Simple -PackageName "xunit" -SourceRootDirectory $specifiedSourceRootDirectories

            # Assert
            $results.Count | Should -Be 3
            $results[0] | script:OutputShouldBe "SlnDir1,\CsProjDir1\CsProjFile1.csproj,xunit,2.4.2"
            $results[1] | script:OutputShouldBe "SlnDir1,\CsProjDir3\CsProjFile3.csproj,xunit,2.0.0-alpha-build2503"
            $results[2] | script:OutputShouldBe "SlnDir1,\CsProjDir4\CsProjFile4.csproj,xunit,2.3.0"
        }

        It "By StoredPackageNames and SpecifiedRootDirectories" {
            # Arrange
            Set-StoredPackageNames @("xunit", "Newtonsoft.Json", "Castle.Core", "Serilog.Sinks.Console", "JetBrains.Profiler.Api")
            
            # Act
            $results = Get-CsProjPackageReference -Simple -SourceRootDirectory (script:RelTestPath $script:ApplicationGroup1Dir)

            # Assert
            $results.Count | Should -Be 9
            $results[0] | script:OutputShouldBe "SlnDir1,\CsProjDir1\CsProjFile1.csproj,Castle.Core,5.1.1"
            $results[1] | script:OutputShouldBe "SlnDir1,\CsProjDir1\CsProjFile1.csproj,JetBrains.Profiler.Api,1.1.5"
            $results[2] | script:OutputShouldBe "SlnDir1,\CsProjDir1\CsProjFile1.csproj,Newtonsoft.Json,10.0.2"
            $results[3] | script:OutputShouldBe "SlnDir1,\CsProjDir1\CsProjFile1.csproj,Serilog.Sinks.Console,4.1.1-dev-00901"
            $results[4] | script:OutputShouldBe "SlnDir1,\CsProjDir1\CsProjFile1.csproj,xunit,2.4.2"
            $results[5] | script:OutputShouldBe "SlnDir1,\CsProjDir3\CsProjFile3.csproj,xunit,2.0.0-alpha-build2503"
            $results[6] | script:OutputShouldBe "SlnDir1,\CsProjDir4\CsProjFile4.csproj,xunit,2.3.0"
            $results[7] | script:OutputShouldBe "SlnDir2,\CsProjDir\CsProjFile5.csproj,JetBrains.Profiler.Api,1.3.0"
            $results[8] | script:OutputShouldBe "SlnDir2,\CsProjDir\CsProjFile5.csproj,Serilog.Sinks.Console,3.1.1"            
        }
    }

    Context "Edit-AcmeCsProjPackageReference" {
        It "Updating all StoredPackageNames packages to the latest NonPreRelease version found in Nexus" {
            Set-StoredNexusUrl -NexusBaseUrl $script:NexusBaseUrl

            $results = Get-CsProjPackageReference -PackageName "xunit" -SourceRootDirectory (script:RelTestPath $script:ApplicationGroup1Dir) | 
            Edit-CsProjPackageReference -LatestVersion -WhatIf

            $results
        }

        # It "Updating all StoredPackageNames packages to the latest version found in Nexus even if the version is a pre-release version" {
            
        # }

        # It "Updating specific versions of specific packages under StoredRootDirectories" {
            
        # }

        # It "Updating specific versions of specific packages under SpecifiedRootDirectories" {
            
        # }
    }

    # Context "Compare-AcmeCsProjPackageReference" {
    #     It "Comparing changes to PackageReference nodes across all CsProj files found under StoredRootDirectories" {

    #     }

    #     It "Comparing changes to PackageReference nodes across all CsProj files found under SpecifiedRootDirectories" {

    #     }
    # }

    # Context "Undo-AcmeCsProjPackageReference" {
    #     It "Undo all PackageReference node changes" {

    #     }

    #     It "Undo single specific PackageReference node changes" {
            
    #     }

    #     It "Undo multiple specific PackageReference node changes" {
            
    #     }
    # }
}