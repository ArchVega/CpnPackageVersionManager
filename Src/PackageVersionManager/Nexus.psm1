using module .\Classes.psm1

function Test-NexusPackageExists {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $PackageName
    )

    return $null -ne (Get-NexusPackages -PackageName $PackageName)
}

function Test-NexusPackageVersionExists {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $PackageName,
        [Parameter(Mandatory)]
        [string] $PackageVersion
    )

    $packages = Get-NexusPackages -PackageName $PackageName
    
    return ($packages | Where-Object { $_.Version -eq $PackageVersion }).Count -gt 0
}

function Get-NexusPackages {
    param(
        [Parameter(Mandatory)]
        [string] $PackageName,
        [switch] $LatestVersion
    )
    
    $searchParameters = "repository=nuget-hosted&format=nuget&name=$packageName&sort=version"
    $repositoriesUrl = "$(Get-NexusUrl)/service/rest/v1/search"
    $url = "$($repositoriesUrl)?$searchParameters"
    $results = @()
    $json = Invoke-RestMethod $url -Headers @{ accept = "application/json" }
    $results += $json.items
    $continuationToken = $json.continuationToken
    
    $finalResults = @()

    if ($null -eq $continuationToken) {
        $finalResults = $results | ForEach-Object { [NugetPackage]::new($_) }
    }
    else {
        while ($null -ne $continuationToken) {
            $continueUrl = $url + "&continuationToken=$continuationToken"
            $json = Invoke-RestMethod $continueUrl -Headers @{ accept = "application/json" }
            $results += $json.items
            $continuationToken = $json.continuationToken
        }
    
        $finalResults = $results | ForEach-Object { [NugetPackage]::new($_) }
    }    
    
    if ($LatestVersion.IsPresent) {
        return ($finalResults | Where-Object { $_.IsLatestVersion }).Version
    }
    
    return $finalResults
}


function  GetNexusPackageOld($searchParameters) {
    $repositoriesUrl = "$(Get-NexusUrl)/service/rest/v1/search"
    $url = "$($repositoriesUrl)?$searchParameters"
    $results = @()
    $json = Invoke-RestMethod $url -Headers @{ accept = "application/json" }
    $results += $json.items
    $continuationToken = $json.$continuationToken
    if ($null -eq $continuationToken) {
        return $results
    }
    
    while ($null -ne $continuationToken) {
        $continuationToken = $url + "&continuationToken=$continuationToken"
        $json = Invoke-RestMethod $continueUrl -Headers @{ accept = "application/json" }
        $results += $json.items
        $continuationToken = $json.continuationToken
    }

    return $results
}

function GetNexusPackagesByBranchOld([string] $packageName, [string] $branchName) {
    $isMaster = $branchName.ToLowerInvariant() -eq "master"
    $versionSearchPattern = $branchName.ToLowerInvariant().Replace("/", "-")

    if ($isMaster) {
        $searchParameters = "repository=nuget-hosted&format=nuget&name=$packageName&sort=version"
    }
    else {
        $searchParameters = "repository=nuget-hosted&format=nuget&name=$packageName&version=$versionSearchPattern&sort=version"
    }

    $result = GetNexusPackage $searchParameters

    if ($isMaster) {
        $result = $result | Where-Object { $_.assets.nuget.is_latest_version -and $_.assets.nuget.is_prerelease -eq $false }
    }
    else {
        $result = $result | Where-Object { $_.assets.nuget.is_latest_version -and $_.assets.nuget.is_prerelease -eq $true }
    }

    if ($result.Count -eq 0) {
        throw "Package '$packageName' had zero packages found in Nexus, search = '$searchParameters'"
    }

    if ($result.Count -gt 1) {
        throw "Multiple packages for '$packageName' were found. Only one package should be returned. This may be a bug in this module. search = '$searchParameters'"
    }

    return [ordered]@{
        Name         = $packageName
        Version      = $result.version
        LastModified = $result.assets[0].lastModified
    }
}