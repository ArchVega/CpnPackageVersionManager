Describe "Nexus" {
    BeforeAll {
        Import-Module .\Src\PackageVersionManager -Force

        $script:NexusBaseUrl = "http://localhost:8081"
    }

    BeforeEach {
        Set-NexusUrl -NexusBaseUrl $script:NexusBaseUrl
    }

    It "Get known packages" {
        $packages = Get-NexusPackages -PackageName "Newtonsoft.Json"
        $packages | ForEach-Object { $_.Name | Should -Be "Newtonsoft.Json" }
        $packages[0].Version | Should -Be "13.0.2"
        $packages[1].Version | Should -Be "10.0.2"
        $packages[2].Version | Should -Be "6.0.3"

        $packages[0].IsLatestVersion | Should -BeTrue
        $packages[1].IsLatestVersion | Should -BeFalse
        $packages[2].IsLatestVersion | Should -BeFalse        
    }
    
    It "Package exists" {
        Test-NexusPackageExists -PackageName "Newtonsoft.Json" | Should -BeTrue
    }

    It "Package does not exist" {
        Test-NexusPackageExists -PackageName "This.Does.Not.Exist" | Should -BeFalse
    }
}