param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$OwnerRepo,

    [Parameter(Mandatory = $true, Position = 1)]
    [string]$ReleaseRef,

    [Parameter(Mandatory = $true, Position = 2)]
    [string]$AssetName
)

$CommonScript = Join-Path $PSScriptRoot '..\..\..\common\win\get_release_asset_digest.ps1'
& $CommonScript $OwnerRepo $ReleaseRef $AssetName
exit $LASTEXITCODE