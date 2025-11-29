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

# Prompt for GitHub PAT
Write-Host "`n=============================================================" -ForegroundColor Cyan
Write-Host "  GitHub Authentication" -ForegroundColor Green
Write-Host "=============================================================" -ForegroundColor Cyan
Write-Host "`nYou will need a GitHub Personal Access Token with 'repo' scope."
Write-Host "Visit: https://github.com/settings/tokens`n" -ForegroundColor Gray

$SecurePAT = Read-Host "Enter your GitHub Personal Access Token" -AsSecureString
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePAT)
$PlainPAT = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)

if ([string]::IsNullOrWhiteSpace($PlainPAT)) {
    Write-Error "PAT cannot be empty"
    exit 1
}

# Get QUE bootstrap script URL
$QueScriptUrl = "https://raw.githubusercontent.com/karlgluck/que/main/que57.ps1"
Write-Host "`nUsing QUE bootstrap URL: $QueScriptUrl" -ForegroundColor Gray

# ============================================================
# WORKSPACE A: Create new project
# ============================================================
Write-Host "`n=============================================================" -ForegroundColor Cyan
Write-Host "  WORKSPACE A: Creating New Project" -ForegroundColor Green
Write-Host "=============================================================" -ForegroundColor Cyan
Write-Host "`nRepository name: $TestRepoName" -ForegroundColor Yellow
Write-Host "Workspace path: $WorkspaceA`n" -ForegroundColor Gray

Write-Host "Starting Workspace A creation..." -ForegroundColor Cyan
Write-Host "(This will create the GitHub repository and set up the workspace)`n" -ForegroundColor Gray

# Create temporary bootstrap script for Workspace A
$TempScriptA = Join-Path $WorkspaceA "setup-temp.ps1"
$BootstrapCommandA = @"
Set-ExecutionPolicy Bypass -Scope Process -Force
Set-Location '$WorkspaceA'
`$quePlainPAT = '$PlainPAT'
iex ((iwr -Headers @{Authorization = "token `$quePlainPAT"} -Uri '$QueScriptUrl').Content)
"@
Set-Content -Path $TempScriptA -Value $BootstrapCommandA -Encoding UTF8

# Execute in new PowerShell window for Workspace A
Write-Host "Launching Workspace A setup in new window..." -ForegroundColor Yellow
$StartProcessArgs = @{
    FilePath = 'powershell'
    ArgumentList = @('-NoExit', '-ExecutionPolicy', 'Bypass', '-File', "`"$TempScriptA`"")
    PassThru = $true
}
$ProcessA = Start-Process @StartProcessArgs

Write-Host "`n=============================================================" -ForegroundColor Cyan
Write-Host "  INSTRUCTIONS FOR WORKSPACE A" -ForegroundColor Yellow
Write-Host "=============================================================" -ForegroundColor Cyan
Write-Host "1. In the new PowerShell window, enter the repo name: $TestRepoName" -ForegroundColor White
Write-Host "2. Wait for the workspace creation to complete" -ForegroundColor White
Write-Host "3. Dependencies will be installed (this may take several minutes)" -ForegroundColor White
Write-Host "4. When complete, return to this window`n" -ForegroundColor White

Read-Host "Press ENTER when Workspace A setup is complete and you're ready to continue"

# ============================================================
# WORKSPACE B: Join existing project
# ============================================================
Write-Host "`n=============================================================" -ForegroundColor Cyan
Write-Host "  WORKSPACE B: Joining Existing Project" -ForegroundColor Green
Write-Host "=============================================================" -ForegroundColor Cyan
Write-Host "`nWorkspace path: $WorkspaceB`n" -ForegroundColor Gray

# Get GitHub username for the project URL
Write-Host "Fetching GitHub username..." -ForegroundColor Cyan
try {
    $AuthHeaders = @{
        Authorization = "token $PlainPAT"
        'Cache-Control' = 'no-store'
    }
    $UserResponse = Invoke-WebRequest -Uri 'https://api.github.com/user' -Headers $AuthHeaders -UseBasicParsing -ErrorAction Stop
    $UserInfo = $UserResponse.Content | ConvertFrom-Json
    $GitHubOwner = $UserInfo.login
    Write-Host "GitHub Owner: $GitHubOwner" -ForegroundColor Green
} catch {
    Write-Error "Failed to get GitHub user info: $($_.Exception.Message)"
    exit 1
}

$ProjectScriptUrl = "https://raw.githubusercontent.com/$GitHubOwner/$TestRepoName/main/que-$TestRepoName.ps1"
Write-Host "Project script URL: $ProjectScriptUrl`n" -ForegroundColor Gray

# Create temporary bootstrap script for Workspace B
$TempScriptB = Join-Path $WorkspaceB "setup-temp.ps1"
$BootstrapCommandB = @"
Set-ExecutionPolicy Bypass -Scope Process -Force
Set-Location '$WorkspaceB'
`$quePlainPAT = '$PlainPAT'
iex ((iwr -Headers @{Authorization = "token `$quePlainPAT"} -Uri '$ProjectScriptUrl').Content)
"@
Set-Content -Path $TempScriptB -Value $BootstrapCommandB -Encoding UTF8

# Execute in new PowerShell window for Workspace B
Write-Host "Launching Workspace B setup in new window..." -ForegroundColor Yellow
$StartProcessArgs = @{
    FilePath = 'powershell'
    ArgumentList = @('-NoExit', '-ExecutionPolicy', 'Bypass', '-File', "`"$TempScriptB`"")
    PassThru = $true
}
$ProcessB = Start-Process @StartProcessArgs

Write-Host "`n=============================================================" -ForegroundColor Cyan
Write-Host "  INSTRUCTIONS FOR WORKSPACE B" -ForegroundColor Yellow
Write-Host "=============================================================" -ForegroundColor Cyan
Write-Host "1. The new window will automatically join the project" -ForegroundColor White
Write-Host "2. Wait for the workspace setup to complete" -ForegroundColor White
Write-Host "3. When finished, both workspaces should be ready`n" -ForegroundColor White

# ============================================================
# Summary and Next Steps
# ============================================================
Write-Host "`n=============================================================" -ForegroundColor Cyan
Write-Host "  Test Deployment Summary" -ForegroundColor Green
Write-Host "=============================================================" -ForegroundColor Cyan
Write-Host "`nTest Repository: $GitHubOwner/$TestRepoName" -ForegroundColor Yellow
Write-Host "`nWorkspace Locations:" -ForegroundColor Yellow
Write-Host "  A: $WorkspaceA" -ForegroundColor White
Write-Host "  B: $WorkspaceB" -ForegroundColor White

Write-Host "`nLaunch Management Terminals:" -ForegroundColor Yellow
$CloneNamePattern = (Get-Date -Format "yyyy-MM-dd") + "-*"
Write-Host "  Workspace A: Run the .lnk shortcut in $WorkspaceA" -ForegroundColor White
Write-Host "  Workspace B: Run the .lnk shortcut in $WorkspaceB" -ForegroundColor White

Write-Host "`nTesting Device Synchronization:" -ForegroundColor Yellow
Write-Host "  1. Run the management script in Workspace A" -ForegroundColor White
Write-Host "  2. Check the DEBUG output for device IDs" -ForegroundColor White
Write-Host "  3. Run the management script in Workspace B" -ForegroundColor White
Write-Host "  4. Verify Workspace B sees Workspace A's device ID" -ForegroundColor White
Write-Host "  5. Use 'push' command to commit changes" -ForegroundColor White
Write-Host "  6. Use 'pull' command in other workspace to sync" -ForegroundColor White

Write-Host "`nCleanup:" -ForegroundColor Yellow
Write-Host "  - Delete test directory: $TestRoot" -ForegroundColor White
Write-Host "  - Delete GitHub repo at: https://github.com/$GitHubOwner/$TestRepoName" -ForegroundColor White

Write-Host "`n=============================================================" -ForegroundColor Cyan
Write-Host "Test environment ready! Check the PowerShell windows." -ForegroundColor Green
Write-Host "=============================================================`n" -ForegroundColor Cyan
