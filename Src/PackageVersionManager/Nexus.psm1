using module .\Classes.psm1

# Gets latest non-prerelease package by default
function Get-NexusPackage {
    [CmdletBinding(DefaultParameterSetName = 'StoredPackageNames')]
    param(
        [Parameter(ParameterSetName = 'SpecifiedPackageNames')]
        [string[]] $PackageName,
        [Parameter(ParameterSetName = 'SpecifiedPackageNames')]
        [string] $PackageVersion,
        [Parameter()]
        [switch] $VerifyPackageExists,
        [Parameter()]
        [switch] $ListAllVersions,
        [Parameter()]
        [switch] $IncludePreReleaseVersions
    )
    
    $errorMessageMultiplePackageNamesForVersion = "Cannot call Get-NexusPackage with more than one PackageName and PackageVersion. Please either provide a single PackageName with -PackageVersion or remove -PackageVersion."
    
    $packageVersionParameterProvided = -not([System.String]::IsNullOrWhiteSpace($PackageVersion))

    if ($PSCmdlet.ParameterSetName -eq "StoredPackageNames") {
        $PackageName = (GetConfig).PackageNames
    }
    elseif ($PSCmdlet.ParameterSetName -eq "SpecifiedPackageNames") {
        if ($PackageName.Count -eq 0) {
            throw "Must provide a PackageName if a PackageVersion is specified. Only one PackageName is supported when PackageVersion is supplied as well."
        }

        if ($packageVersionParameterProvided -and $PackageName.Count -gt 1) {
            throw $errorMessageMultiplePackageNamesForVersion
        }
    }

    if ($VerifyPackageExists.IsPresent) {
        if (-not $packageVersionParameterProvided) {
            return $PackageName | NexusPackageQuery -SimpleExists
        }
        
        if ($PackageName.Count -gt 1) {
            throw $errorMessageMultiplePackageNamesForVersion
        }

        $package = GetNexusPackageVersion -PackageName $PackageName[0] -PackageVersion $PackageVersion
        return ($null -ne $package)
    }
    else {
        if ($packageVersionParameterProvided) {
            $packages = $PackageName | NexusPackageQuery
        
            return ($packages | Where-Object { $_.Version -eq $PackageVersion }).Count -gt 0
        }

        $packages = $PackageName | NexusPackageQuery

        [Array]::Sort($packages)

        if (-not $IncludePreReleaseVersions.IsPresent) {
            $packages = $packages | Where-Object { -not $_.NugetPackage.IsPreRelease }
        }

        if (-not $ListAllVersions.IsPresent) {
            return ($packages | Group-Object PackageName) | ForEach-Object { $_.Group[-1] }
        }
        
        return $packages
    }
}

# Private Members ---------------------------------------------------------------------------------------------------------------------------------------

function NexusPackageQuery {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline, Mandatory)]
        [string] $PackageName,
        [switch] $SimpleExists
    )

    process {        
        $restUriPath = "search?repository=nuget-hosted&nuget.id=$PackageName"
        $componentSearchUri = ConstructNexusApiUri -RestUriPath $restUriPath
        $components = ExecuteNexusMultiPageRestApiGetMethod -Uri $componentSearchUri
    
        if ($SimpleExists.IsPresent) {            
            return [NexusPackageQueryResultItem]::new($PackageName, $null, $null, $null -ne $components)
        }
                
        if ($null -eq $components) {
            return [NexusPackageQueryResultItem]::new($PackageName, $null, $null, $false)
        }

        return $components | ForEach-Object {
            return [NexusPackageQueryResultItem]::new($PackageName, [NugetPackage]::new($_), $_.version, $true)
        }
    }
}

function GetNexusPackageVersion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $PackageName,
        [Parameter(Mandatory)]
        [string] $PackageVersion
    )

    process {        
        $restUriPath = "search?repository=nuget-hosted&version=$PackageVersion&nuget.id=$PackageName"
        $componentSearchUri = ConstructNexusApiUri -RestUriPath $restUriPath
        
        return ExecuteNexusRestApiGetMethod -Uri $componentSearchUri        
    }
}

function ConstructNexusApiUri {
    param(        
        [Parameter(Mandatory)]
        [string] $RestUriPath
    )

    return "$(Get-StoredNexusUrl)/service/rest/v1/$RestUriPath"
}

function ExecuteNexusMultiPageRestApiGetMethod {
    param(
        # After "v1/"
        [Parameter(Mandatory)]
        [string] $Uri
    )

    $data = @()
    
    do {        
        $restMethodResult = ExecuteNexusRestApiGetMethod -Uri $Uri -ContinuationToken $continuationToken -ReturnRestResponse
        $data += $restMethodResult.items
        $continuationToken = $restMethodResult.continuationToken
    } while ($null -ne $continuationToken)

    return $data
}

function ExecuteNexusRestApiGetMethod {
    param(
        [Parameter(Mandatory)]
        [string] $Uri,
        [Parameter()]
        [string] $ContinuationToken,
        [Parameter()]
        [switch] $ReturnRestResponse
    )

    $headers = @{ accept = "application/json" }

    if (-not [System.String]::IsNullOrWhiteSpace($ContinuationToken)) {
        $Uri += "&continuationToken=$ContinuationToken"
    }

    $results = Invoke-RestMethod -Uri $uri -Headers $headers 

    if ($results.items.Count -gt 0) {
        if ($ReturnRestResponse.IsPresent) {
            return $results
        }

        return $results.items
    }

    return $null
}

function GetConfig() {
    return Get-Content $global:PackageVersionManagerAppConfigPath -Raw | ConvertFrom-Json
}