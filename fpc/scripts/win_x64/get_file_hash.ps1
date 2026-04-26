param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$LiteralPath,

    [Parameter(Mandatory = $true, Position = 1)]
    [string]$Algorithm,

    [Parameter(Mandatory = $true, Position = 2)]
    [string]$ExpectedHash
)

$CommonScript = Join-Path $PSScriptRoot '..\..\..\common\win\get_file_hash.ps1'
& $CommonScript $LiteralPath $Algorithm $ExpectedHash
exit $LASTEXITCODE