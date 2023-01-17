Describe "StoredData" {
    BeforeAll {
        Import-Module .\Src\PackageVersionManager -Force
        . .\Tests\_TestHelpers.ps1
    }

    BeforeEach {
        script:SetupTestStubsDirectory
        script:DeleteAppConfigDirectory
    }

    Context "StoredNexusUrl" {
        It "GET returns an empty string if not set" {
            Get-StoredNexusUrl | Should -Be $null
        }

        It "SET stores the base url then GET returns the url" {
            Set-StoredNexusUrl -NexusBaseUrl $script:NexusBaseUrl
            Get-StoredNexusUrl | Should -Be $script:NexusBaseUrl
        }
    }

    Context "StoredSourceRootDirectories" {
        It "GET returns an empty array if not set" {
            Get-StoredSourceRootDirectories | Should -Be $null
        }

        It "SET stores the directory paths then GET returns the directory paths" {
            Set-StoredSourceRootDirectories -SourceRootDirectories $script:SourceRootDirectories
            Get-StoredSourceRootDirectories | Should -Be $script:SourceRootDirectories   
        }
    }

    Context "AcmeStoredPackageName" {
        It "GET returns an empty array if not set" {
            Get-StoredSourceRootDirectories | Should -Be $null
        }

        It "SET stores the package names then GET returns the package names" {
            Set-StoredPackageNames -PackageNames $script:StoredPackageNames
            Get-StoredPackageNames | Should -Be $script:StoredPackageNames   
        }
    }
}