# Build web Flutter dengan nilai dari app\.env sebagai --dart-define
# Pemakaian: powershell -ExecutionPolicy Bypass -File app\build-web.ps1
$ErrorActionPreference = "Stop"
$envFile = Join-Path $PSScriptRoot ".env"
if (-not (Test-Path $envFile)) { throw "File .env tidak ditemukan: $envFile" }

$defines = @()
foreach ($line in Get-Content $envFile -Encoding UTF8) {
    if ($line -match '^\s*#' -or $line -notmatch '=') { continue }
    $key, $value = $line.Split('=', 2)
    $key = $key.Trim()
    $value = $value.Trim()
    $defines += "--dart-define=$key=$value"
}

Push-Location $PSScriptRoot
try {
    # --pwa-strategy=none: tanpa service worker. Versi lama tidak tertahan di cache browser setelah deploy.
    flutter build web --release --pwa-strategy=none @defines
    if ($LASTEXITCODE -ne 0) { throw "flutter build web gagal" }
    Write-Host "Build selesai dengan $($defines.Count) dart-define dari .env"
} finally {
    Pop-Location
}
