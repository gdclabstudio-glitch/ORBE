param(
    [string]$ProjectId,
    [string]$StorageBucket,
    [string]$Destination = "backups",
    [switch]$Execute,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupRoot = Join-Path $repoRoot $Destination
$backupPath = Join-Path $backupRoot "firebase-backup-$timestamp"

if (-not $Execute) {
    Write-Host "[DRY-RUN] Firebase backup script prepared."
    Write-Host "ProjectId: $ProjectId"
    Write-Host "StorageBucket: $StorageBucket"
    Write-Host "Destination: $backupPath"
    Write-Host ""
    Write-Host "To execute a real export, run this script with -Execute and a valid Firebase project context."
    Write-Host "Example:"
    Write-Host "  .\scripts\firebase_backup_export.ps1 -ProjectId <project-id> -StorageBucket <bucket-name> -Execute"
    Write-Host ""
    Write-Host "Important:"
    Write-Host "- This script does not delete or overwrite production data."
    Write-Host "- It is designed to export data safely into a local timestamped folder."
    Write-Host "- Firebase Console/GCP configuration may still be required for production-grade DR."
    exit 0
}

if (-not $ProjectId) {
    throw 'ProjectId is required when using -Execute.'
}

if (-not (Get-Command firebase -ErrorAction SilentlyContinue)) {
    Write-Warning 'ACTION MANUAL NECESSÁRIA: Firebase CLI not installed or not available in PATH.'
    Write-Warning 'Install firebase-tools and authenticate with firebase login before running export operations.'
    exit 1
}

if (-not (Test-Path $backupRoot)) {
    New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
}

Write-Host "[INFO] Starting Firebase backup export for project: $ProjectId"
Write-Host "[INFO] Destination folder: $backupPath"

# Export Firestore snapshot to a safe local directory.
# This is a backup action only; it does not create or delete production data.
try {
    firebase firestore:export "$backupPath/firestore" --project "$ProjectId"
} catch {
    Write-Warning 'ACTION MANUAL NECESSÁRIA: Firestore export failed. Confirm the project is valid, Firebase CLI is authenticated and this environment has permission.'
    throw
}

if ($StorageBucket) {
    if (-not (Get-Command gsutil -ErrorAction SilentlyContinue) -and -not (Get-Command gcloud -ErrorAction SilentlyContinue)) {
        Write-Warning 'ACTION MANUAL NECESSÁRIA: Storage export tooling (gsutil/gcloud) is not installed.'
        Write-Warning "Storage bucket backup for '$StorageBucket' must be configured manually in Google Cloud Console or via gcloud/gsutil."
    } else {
        $storageExportPath = Join-Path $backupPath 'storage'
        if (-not (Test-Path $storageExportPath)) {
            New-Item -ItemType Directory -Path $storageExportPath -Force | Out-Null
        }

        if (Get-Command gsutil -ErrorAction SilentlyContinue) {
            gsutil -m rsync -r "gs://$StorageBucket" "$storageExportPath"
        } elseif (Get-Command gcloud -ErrorAction SilentlyContinue) {
            gcloud storage rsync "gs://$StorageBucket" "$storageExportPath" --recursive
        }
    }
}

Write-Host "[INFO] Firestore and Storage backup artifacts were staged under $backupPath"
Write-Host "[INFO] Validate the export integrity before any restore or disaster drill." 
Write-Host "[INFO] Do not delete or modify the backup set before the restore checklist is completed."
