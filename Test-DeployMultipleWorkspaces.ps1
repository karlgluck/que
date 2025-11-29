#Requires -Version 5.1

<#
.SYNOPSIS
    Test script for deploying and testing multiple QUE workspaces
.DESCRIPTION
    Creates two workspace directories and orchestrates the create/join flow
    to test multi-workspace synchronization and device sharing
#>

# Enable TLS 1.2 for GitHub API
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072

Write-Host "`n=============================================================" -ForegroundColor Cyan
Write-Host "  QUE Multi-Workspace Test Deployment" -ForegroundColor Green
Write-Host "=============================================================" -ForegroundColor Cyan

# Generate unique test identifiers
$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$RandomSuffix = -join ((65..90) + (97..122) | Get-Random -Count 4 | ForEach-Object {[char]$_})
$TestRepoName = "que-test-$RandomSuffix".ToLower()

Write-Host "`nTest Configuration:" -ForegroundColor Yellow
Write-Host "  Timestamp: $Timestamp"
Write-Host "  Test Repo: $TestRepoName"

# Create test directory structure
$TestRoot = Join-Path (Get-Location) "que-multiws-test-$Timestamp"
$WorkspaceA = Join-Path $TestRoot "workspace-a"
$WorkspaceB = Join-Path $TestRoot "workspace-b"

Write-Host "`nCreating test directories..." -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $WorkspaceA | Out-Null
New-Item -ItemType Directory -Force -Path $WorkspaceB | Out-Null
Write-Host "  Workspace A: $WorkspaceA" -ForegroundColor Gray
Write-Host "  Workspace B: $WorkspaceB" -ForegroundColor Gray

# GitHub PAT reminder
Write-Host "`n=============================================================" -ForegroundColor Cyan
Write-Host "  GitHub Authentication" -ForegroundColor Green
Write-Host "=============================================================" -ForegroundColor Cyan
Write-Host "`nYou will need a GitHub Personal Access Token with 'repo' scope."
Write-Host "Visit: https://github.com/settings/tokens" -ForegroundColor Gray
Write-Host "`nYou will be prompted to enter it in each workspace." -ForegroundColor Yellow
Write-Host "Press ENTER to continue..." -ForegroundColor Gray
Read-Host

# ============================================================
# WORKSPACE A: Create new project
# ============================================================
Write-Host "`n=============================================================" -ForegroundColor Cyan
Write-Host "  WORKSPACE A: Creating New Project" -ForegroundColor Green
Write-Host "=============================================================" -ForegroundColor Cyan
Write-Host "`nRepository name to use: " -NoNewline -ForegroundColor Yellow
Write-Host "$TestRepoName" -ForegroundColor White
Write-Host "Workspace path: $WorkspaceA`n" -ForegroundColor Gray

# Open PowerShell in Workspace A
Write-Host "Opening PowerShell window for Workspace A..." -ForegroundColor Cyan
$StartProcessArgs = @{
    FilePath = 'powershell'
    ArgumentList = @('-NoExit', '-Command', "Set-Location '$WorkspaceA'")
    PassThru = $true
}
$ProcessA = Start-Process @StartProcessArgs

Write-Host "`n=============================================================" -ForegroundColor Cyan
Write-Host "  INSTRUCTIONS FOR WORKSPACE A" -ForegroundColor Yellow
Write-Host "=============================================================" -ForegroundColor Cyan
Write-Host "`n1. In the new PowerShell window, paste this command:" -ForegroundColor White
Write-Host "`n   " -NoNewline
Write-Host "Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex (`$queScript = (iwr -Headers @{Authorization = `"token `$(`$quePlainPAT = Read-Host 'Enter Personal Access Token';`$quePlainPAT)`"} -Uri (`$queUrl = `"https://raw.githubusercontent.com/karlgluck/que/main/que57.ps1`")).Content)" -ForegroundColor Cyan
Write-Host "`n2. When prompted for PAT, enter your GitHub token" -ForegroundColor White
Write-Host "3. When prompted for repository name, enter: " -NoNewline -ForegroundColor White
Write-Host "$TestRepoName" -ForegroundColor Yellow
Write-Host "4. Wait for workspace creation to complete (dependencies will install)" -ForegroundColor White
Write-Host "5. When finished, return to this window`n" -ForegroundColor White

Read-Host "Press ENTER when Workspace A setup is complete and you're ready to continue"

# ============================================================
# WORKSPACE B: Join existing project
# ============================================================
Write-Host "`n=============================================================" -ForegroundColor Cyan
Write-Host "  WORKSPACE B: Joining Existing Project" -ForegroundColor Green
Write-Host "=============================================================" -ForegroundColor Cyan
Write-Host "`nWorkspace path: $WorkspaceB`n" -ForegroundColor Gray

# Open PowerShell in Workspace B
Write-Host "Opening PowerShell window for Workspace B..." -ForegroundColor Cyan
$StartProcessArgs = @{
    FilePath = 'powershell'
    ArgumentList = @('-NoExit', '-Command', "Set-Location '$WorkspaceB'")
    PassThru = $true
}
$ProcessB = Start-Process @StartProcessArgs

Write-Host "`n=============================================================" -ForegroundColor Cyan
Write-Host "  INSTRUCTIONS FOR WORKSPACE B" -ForegroundColor Yellow
Write-Host "=============================================================" -ForegroundColor Cyan
Write-Host "`n1. In the new PowerShell window, go to the GitHub repo:" -ForegroundColor White
Write-Host "   https://github.com/YOUR-USERNAME/$TestRepoName" -ForegroundColor Gray
Write-Host "`n2. Copy the bootstrap command from the README.md" -ForegroundColor White
Write-Host "   (It will look like the one-liner from Workspace A)" -ForegroundColor Gray
Write-Host "`n3. Paste and run it in the Workspace B PowerShell window" -ForegroundColor White
Write-Host "`n4. When prompted for PAT, enter your GitHub token" -ForegroundColor White
Write-Host "`n5. Wait for workspace setup to complete" -ForegroundColor White
Write-Host "`n6. When finished, both workspaces should be ready`n" -ForegroundColor White

# ============================================================
# Summary and Next Steps
# ============================================================
Write-Host "`n=============================================================" -ForegroundColor Cyan
Write-Host "  Test Deployment Summary" -ForegroundColor Green
Write-Host "=============================================================" -ForegroundColor Cyan
Write-Host "`nTest Repository Name: $TestRepoName" -ForegroundColor Yellow
Write-Host "`nWorkspace Locations:" -ForegroundColor Yellow
Write-Host "  A: $WorkspaceA" -ForegroundColor White
Write-Host "  B: $WorkspaceB" -ForegroundColor White

Write-Host "`nNext Steps:" -ForegroundColor Yellow
Write-Host "`n1. Complete setup in both PowerShell windows" -ForegroundColor White
Write-Host "`n2. Launch Management Terminals:" -ForegroundColor White
Write-Host "   - Workspace A: Run the .lnk shortcut in $WorkspaceA" -ForegroundColor Gray
Write-Host "   - Workspace B: Run the .lnk shortcut in $WorkspaceB" -ForegroundColor Gray

Write-Host "`n3. Test Device Synchronization:" -ForegroundColor White
Write-Host "   a. Run the management script in Workspace A" -ForegroundColor Gray
Write-Host "   b. Check the DEBUG output for device IDs" -ForegroundColor Gray
Write-Host "   c. Run the management script in Workspace B" -ForegroundColor Gray
Write-Host "   d. Verify Workspace B sees Workspace A's device ID in DEBUG output" -ForegroundColor Gray
Write-Host "   e. Verify count shows 2 devices after adding" -ForegroundColor Gray
Write-Host "   f. Use 'push' command to commit changes" -ForegroundColor Gray
Write-Host "   g. Use 'pull' command in other workspace to sync" -ForegroundColor Gray

Write-Host "`n4. Cleanup When Done:" -ForegroundColor White
Write-Host "   - Delete test directory: $TestRoot" -ForegroundColor Gray
Write-Host "   - Delete GitHub repo at: https://github.com/YOUR-USERNAME/$TestRepoName" -ForegroundColor Gray

Write-Host "`n=============================================================" -ForegroundColor Cyan
Write-Host "Test environment ready! Follow the steps above." -ForegroundColor Green
Write-Host "=============================================================`n" -ForegroundColor Cyan
