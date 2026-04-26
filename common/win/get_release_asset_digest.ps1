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
    'User-Agent' = 'KKMindWave-Win-Helpers'
    'X-GitHub-Api-Version' = '2026-03-10'
}

$retryAttempts = 3
if ($env:HTTP_RETRY_ATTEMPTS -match '^[0-9]+$' -and [int]$env:HTTP_RETRY_ATTEMPTS -gt 0) {
    $retryAttempts = [int]$env:HTTP_RETRY_ATTEMPTS
}

$retryDelaySeconds = 2
if ($env:HTTP_RETRY_DELAY_SECONDS -match '^[0-9]+$' -and [int]$env:HTTP_RETRY_DELAY_SECONDS -ge 0) {
    $retryDelaySeconds = [int]$env:HTTP_RETRY_DELAY_SECONDS
}

function Invoke-ReleaseApiWithRetry {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,

        [Parameter(Mandatory = $true)]
        [hashtable]$Headers,

        [Parameter(Mandatory = $true)]
        [int]$MaxAttempts,

        [Parameter(Mandatory = $true)]
        [int]$DelaySeconds
    )

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        try {
            return Invoke-RestMethod -UseBasicParsing -Headers $Headers -Uri $Uri
        } catch {
            $statusCode = $null
            if ($null -ne $_.Exception.Response -and $null -ne $_.Exception.Response.StatusCode) {
                $statusCode = [int]$_.Exception.Response.StatusCode
            }

            if ($statusCode -eq 404 -or $attempt -ge $MaxAttempts) {
                throw
            }

            [Console]::Error.WriteLine(('[get-release-asset-digest] Warning: metadata attempt {0}/{1} failed: {2}' -f $attempt, $MaxAttempts, $_.Exception.Message))
            Start-Sleep -Seconds $DelaySeconds
        }
    }
}

try {
    if ($ReleaseRef -ieq 'latest') {
        $releaseApiUrl = "https://api.github.com/repos/$OwnerRepo/releases/latest"
    } else {
        $escapedReleaseRef = [System.Uri]::EscapeDataString($ReleaseRef)
        $releaseApiUrl = "https://api.github.com/repos/$OwnerRepo/releases/tags/$escapedReleaseRef"
    }

    $release = Invoke-ReleaseApiWithRetry -Uri $releaseApiUrl -Headers $headers -MaxAttempts $retryAttempts -DelaySeconds $retryDelaySeconds
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