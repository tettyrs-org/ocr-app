<#
.SYNOPSIS
Membuat akun pengguna (Firebase Auth + tabel ocr_users) lewat script admin, dijalankan di dalam jaringan Docker.

.DESCRIPTION
PostgreSQL yang dipakai aplikasi ada di container ocr-postgres, yang tidak memublikasikan port ke host.
localhost:5432 di Windows adalah PostgreSQL 16 lain, jadi script dijalankan dari container Node
yang ikut jaringan api_ocr-network agar bisa mencapai host "postgres".

Kunci service account dipasang read-only dari luar repo dan tidak masuk ke image.

.PARAMETER Email
Email pengguna yang akan dibuat.

.PARAMETER Roles
Daftar role dipisah koma: USER, ADMIN, atau VIEWER.

.PARAMETER KeyPath
Path kunci service account admin. Default: %USERPROFILE%\.firebase-keys\ocr-admin.json

.EXAMPLE
powershell -ExecutionPolicy Bypass -File create-user.ps1 -Email user@example.com -Roles USER
#>
param(
    [Parameter(Mandatory = $true)][string]$Email,
    [Parameter(Mandatory = $true)][string]$Roles,
    [string]$KeyPath = "%USERPROFILE%\.firebase-keys\ocr-admin.json"
)

$ErrorActionPreference = "Stop"
if (-not (Test-Path $KeyPath)) { throw "Kunci service account tidak ditemukan: $KeyPath" }

$functionsDir = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$keyDir = Split-Path -Parent $KeyPath
$keyFile = Split-Path -Leaf $KeyPath

# Konversi path Windows ke format yang dipahami Docker Desktop
$mountApp = $functionsDir -replace '\\', '/'
$mountKeys = $keyDir -replace '\\', '/'

docker run --rm --network api_ocr-network `
    -v "${mountApp}:/app" `
    -v "${mountKeys}:/keys:ro" `
    -w /app `
    -e "GOOGLE_APPLICATION_CREDENTIALS=/keys/$keyFile" `
    -e "DATABASE_URL=postgres://ocr_db_dev:ocrdev123@postgres:5432/ocr_results" `
    node:20-alpine node admin/create-user.mjs --email $Email --roles $Roles
exit $LASTEXITCODE
