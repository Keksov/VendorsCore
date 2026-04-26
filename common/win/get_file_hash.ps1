param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$LiteralPath,

    [Parameter(Mandatory = $true, Position = 1)]
    [string]$Algorithm,

    [Parameter(Mandatory = $true, Position = 2)]
    [string]$ExpectedHash
)

$ErrorActionPreference = 'Stop'

$normalizedAlgorithm = $Algorithm.ToUpperInvariant()

try {
    switch ($normalizedAlgorithm) {
        'SHA1' {
            $hasher = [System.Security.Cryptography.SHA1]::Create()
        }
        'SHA256' {
            $hasher = [System.Security.Cryptography.SHA256]::Create()
        }
        default {
            exit 2
        }
    }

    try {
        $stream = [System.IO.File]::Open($LiteralPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
        try {
            $hashBytes = $hasher.ComputeHash($stream)
        } finally {
            $stream.Dispose()
        }
    } finally {
        $hasher.Dispose()
    }

    $actualHash = -join ($hashBytes | ForEach-Object { $_.ToString('X2') })
} catch {
    exit 2
}

if ($actualHash -ieq $ExpectedHash) {
    exit 0
}

exit 1