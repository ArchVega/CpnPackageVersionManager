using module .\..\Src\PackageVersionManager\Classes.psm1

Describe "VegaSemanticVersion" {
    BeforeAll {
        Import-Module .\Src\PackageVersionManager -Force        
    }
    
    Context "ToString()" {
        It "Official release version" {
            $semVerString = "19.1.3"
            $semVer = [VegaSemanticVersion]$semVerString

            $semVer.Major | Should -Be 19
            $semVer.Minor | Should -Be 1
            $semVer.Patch | Should -Be 3
            $semVer.PreRelease | Should -Be ""
            $semVer.Build | Should -Be ""
            $semVer.Label | Should -Be ""
            $semVer.IsPreRelease | Should -BeFalse
        }

        It "Official release version (Regex2)" {            
            $semVerString = "1.7.0.1540"
            $semVer = [VegaSemanticVersion]$semVerString

            $semVer.Major | Should -Be 1
            $semVer.Minor | Should -Be 7
            $semVer.Patch | Should -Be 0
            $semVer.PreRelease | Should -Be "1540"
            $semVer.Build | Should -Be ""
            $semVer.Label | Should -Be "1540"
            $semVer.IsPreRelease | Should -BeTrue
        }

        It "PreRelease and build metadata version" {
            $semVerString = "19.1.3-alpha+build0001"
            $semVer = [VegaSemanticVersion]$semVerString

            $semVer.Major | Should -Be 19
            $semVer.Minor | Should -Be 1
            $semVer.Patch | Should -Be 3
            $semVer.PreRelease | Should -Be "alpha"
            $semVer.Build | Should -Be "build0001"
            $semVer.Label | Should -Be "alphabuild0001"
            $semVer.IsPreRelease | Should -BeTrue
        }
    } 

    Context "ComparedTo()" {                    
        It "<SemVer1String> compared to <SemVer2String> equals <Result>" -ForEach @(
            @{ SemVer1String = "2.3.0"; SemVer2String = "2.2.0"; Result = 1 }
            @{ SemVer1String = "2.2.0"; SemVer2String = "2.3.0"; Result = -1 }
            @{ SemVer1String = "2.3.0"; SemVer2String = "2.3.0"; Result = 0 }

            @{ SemVer1String = "2.3.0-beta1-build3642"; SemVer2String = "2.2.0-beta2-build3300"; Result = 1 }
            @{ SemVer1String = "2.2.0-beta2-build3300"; SemVer2String = "2.3.0-beta1-build3642"; Result = -1 }
            @{ SemVer1String = "2.3.0-beta1-build3642"; SemVer2String = "2.3.0-beta1-build3642"; Result = 0 }

            @{ SemVer1String = "2.3.0-beta3-build3642"; SemVer2String = "2.3.0-beta3-build3300"; Result = 1 }
            @{ SemVer1String = "2.3.0-beta3-build3300"; SemVer2String = "2.3.0-beta3-build3642"; Result = -1 }
            @{ SemVer1String = "2.3.0-beta3-build3642"; SemVer2String = "2.3.0-beta3-build3642"; Result = 0 }
        ) {
            $semVer1 = [VegaSemanticVersion]::new($SemVer1String)
            $semVer2 = [VegaSemanticVersion]::new($SemVer2String)

            $semVer1.CompareTo($semVer2) | Should -Be $Result
        }
    }
} 