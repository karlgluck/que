#Requires -Version 5.1

<#
.SYNOPSIS
    Waits for GitHub raw content to match local file
.DESCRIPTION
    Polls raw.githubusercontent.com to check if the remote que57.ps1 matches the local version.
    Useful after pushing changes to wait for GitHub's CDN to update.
.PARAMETER LocalPath
    Path to local file (defaults to que57.ps1 in script directory)
.PARAMETER RemoteUrl
    GitHub raw content URL (defaults to karlgluck/que main branch)
.PARAMETER PollInterval
    Seconds between polls (default: 3)
.PARAMETER MaxAttempts
    Maximum number of polling attempts (default: 60, which is 3 minutes at 3-second intervals)
#>

param(
    [string]$LocalPath = "$PSScriptRoot\que57.ps1",
    [string]$RemoteUrl = "https://raw.githubusercontent.com/karlgluck/que/main/que57.ps1",
    [int]$PollInterval = 3,
    [int]$MaxAttempts = 60
)

# Enable TLS 1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072

Write-Host "Waiting for GitHub to reflect local changes..." -ForegroundColor Cyan
Write-Host "Local file: $LocalPath" -ForegroundColor Gray
Write-Host "Remote URL: $RemoteUrl" -ForegroundColor Gray
Write-Host ""

# Read local file content
if (-not (Test-Path $LocalPath)) {
    Write-Error "Local file not found: $LocalPath"
    exit 1
}

$LocalContent = Get-Content $LocalPath -Raw -Encoding UTF8
$LocalHash = (Get-FileHash -Path $LocalPath -Algorithm SHA256).Hash
$LocalLines = ($LocalContent -split "`n").Count

Write-Host "Local file hash: $LocalHash" -ForegroundColor Gray
Write-Host "Local file size: $($LocalContent.Length) chars, $LocalLines lines" -ForegroundColor Gray
Write-Host ""

# Poll GitHub
$Attempt = 0
$Matched = $false

while ($Attempt -lt $MaxAttempts -and -not $Matched) {
    $Attempt++

    try {
        # Fetch remote content with no-cache header
        $Headers = @{
            'Cache-Control' = 'no-store'
        }
        $Response = Invoke-WebRequest -Uri $RemoteUrl -Headers $Headers -UseBasicParsing -ErrorAction Stop
        $RemoteContent = $Response.Content

        # Normalize line endings for comparison (GitHub uses LF, Windows may use CRLF)
        $LocalNormalized = $LocalContent -replace "`r`n", "`n"
        $RemoteNormalized = $RemoteContent -replace "`r`n", "`n"

        if ($LocalNormalized -eq $RemoteNormalized) {
            $Matched = $true
            Write-Host "Match found on attempt $Attempt!" -ForegroundColor Green
            Write-Host "GitHub content is now up to date." -ForegroundColor Green
        } else {
            # Show difference info
            $RemoteLines = ($RemoteContent -split "`n").Count
            $PercentProgress = [math]::Min(100, ($Attempt / $MaxAttempts) * 100)

            Write-Host "[$Attempt/$MaxAttempts] Remote differs: $($RemoteContent.Length) chars, $RemoteLines lines (local: $($LocalContent.Length) chars, $LocalLines lines)" -ForegroundColor Yellow

            if ($Attempt -lt $MaxAttempts) {
                Start-Sleep -Seconds $PollInterval
            }
        }
    } catch {
        Write-Host "[$Attempt/$MaxAttempts] Error fetching remote: $($_.Exception.Message)" -ForegroundColor Red

        if ($Attempt -lt $MaxAttempts) {
            Start-Sleep -Seconds $PollInterval
        }
    }
}

Write-Host ""

if ($Matched) {
    Write-Host "GitHub is synchronized with local file." -ForegroundColor Green
    exit 0
} else {
    Write-Warning "Timeout: GitHub content still differs after $MaxAttempts attempts"
    Write-Host "This might be normal if:"
    Write-Host "  - Changes haven't been pushed yet"
    Write-Host "  - GitHub Actions or other automation is modifying the file"
    Write-Host "  - GitHub's CDN needs more time to update"
    exit 1
}
