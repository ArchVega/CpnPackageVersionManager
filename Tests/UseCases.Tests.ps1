Describe "Use Cases" {
    BeforeAll {
        . .\Tests\_TestHelpers.ps1

        # Company name is Acme, import the module into a PowerShell session and use the company name as a function prefix.
        Import-Module .\Src\PackageVersionManager -Prefix "Acme" -Force
    }

    # Test setup - create copies of test files and delete config files.
    BeforeEach {
        script:SetupTestStubsDirectory
        script:DeleteAppConfigDirectory
    }

    # First-time configuration by the user of the PackageVersionManager module.
    BeforeEach {
        # Stores the base url as StoredNexusUrl to Acme's Nexus server.
        Set-AcmeStoredNexusUrl -NexusBaseUrl $script:NexusBaseUrl
        # Get the base url.
        Get-AcmeStoredNexusUrl
        # Stores directories containing source code as SourceRootDirectories where our C# Solution files are located so other functions know where to look for csproj files. Overwrites all paths with each call.
        Set-AcmeStoredSourceRootDirectories -Paths @("C:\Git\Applications", "C:\Git\Libraries")
        # Get the SourceRootDirectories.
        Get-AcmeStoredSourceRootDirectories
        # Store package names as 'StoredPackageNames' if we want to run commands to update multiple packages without having to specify them each time. Overwrites all paths with each call.
        Set-AcmeStoredPackageName -PackageNames @("Newtonsoft.Json", "Castle.Core")
        # Verify StoredPackageNames.
        Test-AcmeStoredPackageName
        # Get StoredPackageNames.
        Get-AcmeStoredPackageName
    }

    It "Verifing nuget packages and their versions in Nexus" {
        # Query Nexus to verify that each StoredPackageName exists in Nexus.
        Get-AcmeNexusPackage -Verify
        # Gets info on a particular package or packages found in Nexus.
        Get-AcmeNexusPackage -PackageName "xunit"
        Get-AcmeNexusPackage -PackageName @("xunit", "Newtonsoft.Json")
        # Gets all versions for all packages, useful if a build is broken with current packages and a test build with a previous version is needed.
        Get-AcmeNexusPackage -AllVersions
    }

    It "Querying package references and their versions across CsProj files" {
        # See the CsProf files that reference the xunit package and their versions used in each CsProj file across all SourceRootDirectories.
        Get-AcmeCsProjPackageReference -PackageName "xunit"
        # See the CsProf files that reference these packages and their versions under a particular directory.
        Get-AcmeCsProjPackageReference -PackageName @("xunit", "Newtonsoft.Json") -RootDirectories @("C:\Git\Applications")        
        # Same as above but using StoredPackageNames instead
        Get-AcmeCsProjPackageReference
        Get-AcmeCsProjPackageReference -RootDirectories @("C:\Git\Applications")
    }

    It "Updating package reference versions across CsProj files" {
        # Update all PackageReferences matching StoredPackageNames, find and update all PackageReference nodes in all CsProj files across all SourcesRootDirectories.
        Get-AcmeCsProjPackageReference | Edit-AcmeCsProjPackageReferenceVersion -LatestVersion
        # Update all PackageReferences matching StoredPackageNames to the latest versions again, but this time include PreRelease versions if any are found.
        Get-AcmeCsProjPackageReference -PackageName "xunit" -IncludePreReleaseVersions | Edit-AcmeCsProjPackageReferenceVersion -LatestVersion
        # Update specific packages to specific versions and under a specific root directory
        Get-AcmeCsProjPackageReference  | Edit-AcmeCsProjPackageReferenceVersion -Packages @("xunit,2.4.2", "Newtonsoft.Json,10.0.2") -SourceRootDirectories @("C:\Git\Applications")
                
        ## DEFERRED ---------------------------------------------------------------------------------------------------------------------------------------------------
        ## Requires testing against Git or Mocks for Git-related functions. Not Possible at this time. Will have to use information above to manually compare and undo.
        ## ------------------------------------------------------------------------------------------------------------------------------------------------------------
        # In any case above, verify what CsProj files whose PackageReference nodes have changed according to Git
        Compare-AcmeCsProjPackageReference
        Compare-AcmeCsProjPackageReference -SourceRootDirectories @("C:\Git\Applications")
        # Undoing CsProj changes for PackageReference nodes. Uses Git to compare and only CsProj files' PackageReference node changes are reverted.
        Undo-AcmeCsProjPackageReferenceVersion -AllPackages
        Undo-AcmeCsProjPackageReferenceVersion -PackageName @("xunit", "Newtonsoft.Json")        
    }
}