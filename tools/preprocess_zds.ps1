param(
    [string]$SourceDir = "src",
    [string]$OutputDir = "derived/zdsasm",
    [string]$VersionFile = "version.txt"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $SourceDir)) {
    throw "Source directory not found: $SourceDir"
}

if (-not (Test-Path $VersionFile)) {
    throw "Version file not found: $VersionFile"
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$versionText = (Get-Content $VersionFile -Raw).Trim()

Get-ChildItem -Path $SourceDir -Filter "*.asm" | ForEach-Object {
    $srcPath = $_.FullName
    $raw = Get-Content $srcPath -Raw

    # ZMASM does not accept $-prefixed hex literals used by the original sources.
    $converted = [regex]::Replace($raw, '\$([0-9A-Fa-f]+)', '0$1h')

    # Keep generated includes resolvable from the preprocessed output tree.
    $converted = $converted -replace '\.\./derived/asm/', ''

    # Expand incbin directives into DB directives with explicit bytes.
    $converted = [regex]::Replace(
        $converted,
        '(?m)^(\s*)incbin\s+"([^"]+)"\s*$',
        {
            param($m)
            $indent = $m.Groups[1].Value
            $incFile = $m.Groups[2].Value

            if ($incFile -eq "../version.txt") {
                return "$indent" + 'db "' + $versionText + '"'
            }

            $incPath = Join-Path (Split-Path $srcPath -Parent) $incFile
            if (-not (Test-Path $incPath)) {
                return $m.Value
            }

            $bytes = [System.IO.File]::ReadAllBytes((Resolve-Path $incPath))
            if ($bytes.Length -eq 0) {
                return "$indent" + 'db 00h'
            }

            $lines = New-Object System.Collections.Generic.List[string]
            for ($i = 0; $i -lt $bytes.Length; $i += 16) {
                $end = [Math]::Min($i + 15, $bytes.Length - 1)
                $chunk = @($bytes[$i..$end])
                $vals = $chunk | ForEach-Object { '0{0:X2}h' -f $_ }
                $lines.Add($indent + 'db ' + ($vals -join ','))
            }

            return ($lines -join [Environment]::NewLine)
        }
    )

    $dstPath = Join-Path $OutputDir $_.Name
    Set-Content -Path $dstPath -Value $converted -Encoding Ascii
}
