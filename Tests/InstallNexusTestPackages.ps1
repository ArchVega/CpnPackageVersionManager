param(
    [Parameter(Mandatory)]
    [string] $apiKey
)

try { dotnet nuget remove source nexus.local }
catch {}

$source = "http://localhost:8081/repository/nuget-hosted/index.json"
$sourceName = "nexus.local"
dotnet nuget add source $source -n $sourceName --username admin --password t

$packages = Get-ChildItem ".\Tests\TestNugetPackagesForNexus"

foreach ($package in $packages) {
    Write-Host "Pushing $($package.FullName)"
    dotnet nuget push --source $sourceName --api-key $apiKey $package.FullName 
}