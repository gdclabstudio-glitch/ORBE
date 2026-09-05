param(
    [string]$Environment = 'DEV'
)

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$requiredFiles = @(
    (Join-Path $repoRoot 'firebase.json'),
    (Join-Path $repoRoot 'lib\firebase_options.dart'),
    (Join-Path $repoRoot 'android\app\google-services.json')
)

Write-Host "[INFO] Validating Firebase environment configuration for: $Environment"

foreach ($file in $requiredFiles) {
    if (-not (Test-Path $file)) {
        Write-Warning "Missing required config file: $file"
    } else {
        Write-Host "[OK] Found: $file"
    }
}

if (-not (Test-Path (Join-Path $repoRoot '.env.example'))) {
    Write-Warning 'Missing .env.example template.'
}

Write-Host ""
Write-Host "Checklist for production readiness:"
Write-Host "- Confirm a dedicated Firebase project exists for $Environment"
Write-Host "- Confirm storage, Firestore, and Functions are isolated per environment"
Write-Host "- Confirm secrets are stored outside the repository"
Write-Host "- Confirm Google Sign-In and FCM are configured for the correct project"
Write-Host "- Confirm CI deploys use environment-specific secrets only"
Write-Host ""
Write-Host "This script validates structure only; it does not mutate production configuration."
