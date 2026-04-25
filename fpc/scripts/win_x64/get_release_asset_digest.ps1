param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$OwnerRepo,

    [Parameter(Mandatory = $true, Position = 1)]
    [string]$ReleaseRef,

    [Parameter(Mandatory = $true, Position = 2)]
    [string]$AssetName
)

$ErrorActionPreference = 'Stop'

$headers = @{
    Accept = 'application/vnd.github+json'
    'User-Agent' = 'KKMindWave-FPC-Scripts'
    'X-GitHub-Api-Version' = '2026-03-10'
}

try {
    if ($ReleaseRef -ieq 'latest') {
        $releaseApiUrl = "https://api.github.com/repos/$OwnerRepo/releases/latest"
    } else {
        $escapedReleaseRef = [System.Uri]::EscapeDataString($ReleaseRef)
        $releaseApiUrl = "https://api.github.com/repos/$OwnerRepo/releases/tags/$escapedReleaseRef"
    }

    $release = Invoke-RestMethod -UseBasicParsing -Headers $headers -Uri $releaseApiUrl
} catch {
    if ($null -ne $_.Exception.Response -and $null -ne $_.Exception.Response.StatusCode) {
        if ([int]$_.Exception.Response.StatusCode -eq 404) {
            exit 5
        }
    }

    exit 2
}

$assetMatches = @($release.assets | Where-Object { $_.name -eq $AssetName } | Select-Object -First 1)
if ($assetMatches.Count -eq 0) {
    exit 3
}

$digest = $assetMatches[0].digest
if ([string]::IsNullOrWhiteSpace($digest)) {
    exit 4
}

Write-Output $digest.Trim()