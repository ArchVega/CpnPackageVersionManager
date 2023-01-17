Describe "Nexus" {
    BeforeAll {
        Import-Module .\Src\PackageVersionManager -Force        
        . .\Tests\_TestHelpers.ps1
    }

    BeforeEach {
        Set-StoredNexusUrl -NexusBaseUrl $script:NexusBaseUrl
    }

    Context "Command Get-NexusPackage" {
        Context "With switch -VerifyPackageExists" {
            # This context is the only context that tests Stored vs Specified - if it works here, it should work in all other tests
            It "Returns Exist = true for all returned packages that exists in Nexus for Stored packages" {
                # Arrange
                Set-StoredPackageNames -PackageNames @("xunit", "Invalid.Package", "Newtonsoft.Json")

                # Act
                $results = Get-NexusPackage -VerifyPackageExists 
                
                # Assert
                $results[0].PackageName | Should -Be "xunit"
                $results[0].Exists | Should -BeTrue
                $results[1].PackageName | Should -Be "Invalid.Package"
                $results[1].Exists | Should -BeFalse
                $results[2].PackageName | Should -Be "Newtonsoft.Json"
                $results[2].Exists | Should -BeTrue
            }
            
            It "Returns Exist = true for all returned packages that exist in Nexus for Specified packages" {
                # Arrange and Act
                $results = Get-NexusPackage -VerifyPackageExists -PackageName @("xunit", "Invalid.Package", "Newtonsoft.Json")
                 
                # Assert
                $results[0].PackageName | Should -Be "xunit"
                $results[0].Exists | Should -BeTrue
                $results[1].PackageName | Should -Be "Invalid.Package"
                $results[1].Exists | Should -BeFalse
                $results[2].PackageName | Should -Be "Newtonsoft.Json"
                $results[2].Exists | Should -BeTrue
            }

            Context "With value for -PackageVersion" {
                It "Returns true if one package supplied with switch -VerifyPackageExist is present and regardless if -IncludePreReleaseVersions switch is present" {
                    # Arrange, Act, and Assert
                    Get-NexusPackage -VerifyPackageExists -PackageName "xunit" -PackageVersion "2.4.2" | Should -BeTrue
                    Get-NexusPackage -VerifyPackageExists -PackageName "xunit" -PackageVersion "2.4.2" -IncludePreReleaseVersions | Should -BeTrue
                } 

                It "Returns false if one package supplied with switch -VerifyPackageExist is present but version does not exist, regardless if -IncludePreReleaseVersions switch is present" {
                    # Arrange, Act, and Assert
                    Get-NexusPackage -VerifyPackageExists -PackageName "xunit" -PackageVersion "99.99.99" | Should -BeFalse
                    Get-NexusPackage -VerifyPackageExists -PackageName "xunit" -PackageVersion "99.99.99" -IncludePreReleaseVersions | Should -BeFalse
                } 
                
                It "Returns package details if switch -VerifyPackageExist is NOT present and regardless if -IncludePreReleaseVersions is present or not" {
                    $packages = Get-NexusPackage -PackageName @("Newtonsoft.Json", "Invalid.Package", "Castle.Core")
                    $packages
                }

                Context "Error handling" {
                    $expectedErrorMessage = "Cannot call Get-NexusPackage with more than one PackageName and PackageVersion. Please either provide a single PackageName with -PackageVersion or remove -PackageVersion."

                    It "Throws error if multiple package names are provided" {
                        { Get-NexusPackage -PackageName @("xunit", "Invalid.Package") -PackageVersion "2.4.2" } | Should -Throw $expectedErrorMessage
                        { Get-NexusPackage -VerifyPackageExists -PackageName @("xunit", "Invalid.Package") -PackageVersion "2.4.2" } | Should -Throw $expectedErrorMessage
                        { Get-NexusPackage -ListAllVersions -PackageName @("xunit", "Invalid.Package") -PackageVersion "2.4.2" } | Should -Throw $expectedErrorMessage
                    }
    
                    It "Throws error if StoredPackageNames is used and switch -ListAllVersions is present" {
                        { Get-NexusPackage -ListAllVersions -PackageVersion "2.4.2" } | Should -Throw $expectedErrorMessage
                    }    
                }                            
            }            
        }

        Context "WITHOUT switch -VerifyPackageExists" {
            Context "With switch -IncludePreReleaseVersions" {
                It "Returns all versions including prerelease versions if switch -ListAllVersions is present" {
                    # Arrange and Act
                    $packages = Get-NexusPackage -IncludePreReleaseVersions -ListAllVersion -PackageName @("xunit", "Invalid.Package", "Newtonsoft.Json")
    
                    # Assert
                    ($packages | Where-Object { $_.PackageName -eq "xunit" -and $_.Version -eq "2.0.0-alpha-build1644" }).Count -gt 0 | Should -BeTrue
                    ($packages | Where-Object { $_.PackageName -eq "xunit" -and $_.Version -eq "1.9.2" }).Count -gt 0 | Should -BeTrue
                }                    

                It "Returns ONLY the latest version which may be a prerelease version if switch -ListAllVersions is NOT present" {
                    # Arrange and Act
                    $packages = Get-NexusPackage -IncludePreReleaseVersions -PackageName @("xunit", "Invalid.Package", "Newtonsoft.Json", "Serilog.Sinks.Console")
    
                    # Assert
                    ($packages | Where-Object { $_.PackageName -eq "Serilog.Sinks.Console" -and $_.Version -eq "4.1.1-dev-00901" }).Count -gt 0 | Should -BeTrue
                    ($packages | Where-Object { $_.PackageName -eq "xunit" -and $_.Version -eq "2.4.2-pre.27" }).Count -gt 0 | Should -BeTrue
                    ($packages | Where-Object { $_.PackageName -eq "Newtonsoft.Json" -and $_.Version -eq "13.0.2" }).Count -gt 0 | Should -BeTrue

                    ($packages | Where-Object { $_.PackageName -eq "Serilog.Sinks.Console" -and $_.Version -eq "3.1.1" }).Count -gt 0 | Should -BeFalse
                    ($packages | Where-Object { $_.PackageName -eq "xunit" -and $_.Version -eq "2.4.2" }).Count -gt 0 | Should -BeFalse
                }                    
            } 

            Context "WITHOUT switch -IncludePreReleaseVersions" {
                It "Returns all versions EXCLUDING prerelease versions if switch -ListAllVersions is present" {
                    # Arrange and Act
                    $packages = Get-NexusPackage -ListAllVersions -PackageName @("xunit", "Invalid.Package", "Newtonsoft.Json", "Serilog.Sinks.Console")

                    # Assert
                    ($packages | Where-Object { $_.PackageName -eq "Serilog.Sinks.Console" -and $_.Version -eq "3.1.1" }).Count -gt 0 | Should -BeTrue
                    ($packages | Where-Object { $_.PackageName -eq "xunit" -and $_.Version -eq "2.4.2" }).Count -gt 0 | Should -BeTrue
                    ($packages | Where-Object { $_.PackageName -eq "Newtonsoft.Json" -and $_.Version -eq "13.0.2" }).Count -gt 0 | Should -BeTrue

                    ($packages | Where-Object { $_.PackageName -eq "Serilog.Sinks.Console" -and $_.Version -eq "4.1.1-dev-00901" }).Count -gt 0 | Should -BeFalse
                    ($packages | Where-Object { $_.PackageName -eq "xunit" -and $_.Version -eq "2.3.0-beta2-build3683" }).Count -gt 0 | Should -BeFalse
                }
                
                It "Returns ONLY the latest version which is NOT a prerelease version if switch -ListAllVersions is NOT present" {
                    # Arrange and Act
                    $packages = Get-NexusPackage -PackageName @("xunit", "Invalid.Package", "Newtonsoft.Json", "Serilog.Sinks.Console")

                    # Assert
                    $packages.Count | Should -Be 4
                    ($packages | Where-Object { $_.PackageName -eq "Serilog.Sinks.Console" -and $_.Version -eq "3.1.1" }).Count -gt 0 | Should -BeTrue
                    ($packages | Where-Object { $_.PackageName -eq "xunit" -and $_.Version -eq "2.4.2" }).Count -gt 0 | Should -BeTrue
                    ($packages | Where-Object { $_.PackageName -eq "Newtonsoft.Json" -and $_.Version -eq "13.0.2" }).Count -gt 0 | Should -BeTrue
                    ($packages | Where-Object { $_.PackageName -eq "Invalid.Package" -and [System.String]::IsNullOrWhitespace($_.Version)  }).Count -gt 0 | Should -BeTrue
                }
            }
        }
    }        
}