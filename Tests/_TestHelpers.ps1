$script:NexusBaseUrl = "http://localhost:8081"
$script:StoredPackageNames = @("Newtonsoft.Json", "Castle.Core", "xunit")
$script:ApplicationGroup1Dir = "ApplicationGroup1"
$script:ApplicationGroup3Dir = "ApplicationGroup3"
$script:SlnDir1 = "ApplicationGroup1\SlnDir1"
$script:SlnDir2 = "ApplicationGroup1\SlnDir2"

$script:SlnDir1CsProjFile1 = "ApplicationGroup1\SlnDir1\CsProjDir1\CsProjFile1.csproj"
$script:SlnDir1CsProjFile2 = "ApplicationGroup1\SlnDir1\CsProjDir2\CsProjFile2.csproj"
$script:SlnDir1CsProjFile3 = "ApplicationGroup1\SlnDir1\CsProjDir3\CsProjFile3.csproj"
$script:SlnDir1CsProjFile4 = "ApplicationGroup1\SlnDir1\CsProjDir4\CsProjFile4.csproj"
$script:SlnDir1NonCsProjDir = "ApplicationGroup1\SlnDir1\NonCsProjDir"

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
    return $args | ForEach-Object { Join-Path ".\Tests\.TestFileStubs\Dev\Git" -ChildPath $_ }
}

function script:FullTestPath() {
    return $args | ForEach-Object { Join-Path (Get-Location).Path -ChildPath "Tests\.TestFileStubs\Dev\Git" | Join-Path -ChildPath $_ }
}

function script:FileLastWriteTime([string] $filePath) {
    return (Get-Item (script:FullTestPath $filePath)).LastWriteTime
}

function script:OutputShouldBe {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [PSCustomObject] $Obj,
        [Parameter(Mandatory, Position = 1)]
        [string] $Expected
    )

    ($obj | ConvertTo-Csv -QuoteFields "" )[1] | Should -Be $Expected
}

$script:SourceRootDirectories = @((script:FullTestPath $script:SlnDir1), (script:FullTestPath $script:SlnDir2))