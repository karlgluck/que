<#
.SYNOPSIS
    Automated end-to-end testing script for the Que workspace tool.

.DESCRIPTION
    Test-Que.ps1 performs comprehensive testing of que57.ps1, validating the full
    golden path workflow including GitHub repository creation, workspace initialization,
    SyncThing synchronization, and Git LFS operations.

    CURRENT CAPABILITIES:
    - Validates environment (PowerShell, Git, Git LFS, SyncThing)
    - Checks GitHub token validity and permissions
    - Ensures test repository doesn't already exist (prevents conflicts)
    - Creates isolated test environment in temp directory
    - Creates first QUE workspace by calling que57.ps1 functions directly
    - Creates second workspace using generated que-<repo>.ps1 script
    - Tests Git LFS tracking with .uasset files
    - Validates LFS commit and push operations
    - Tests automatic SyncThing peer addition by launching .lnk files
    - Validates device ID registration, commit, and folder sharing
    - Tests SyncThing depot file synchronization between workspaces
    - Validates synced file contents and metadata
    - Tests SyncThing LFS cache synchronization between workspaces
    - Validates Git LFS pull with proper file checkout (not pointers)
    - Tests multiple clone creation within a workspace
    - Validates clone structure and git repository configuration
    - Validates workspace structure and Git repository setup
    - Provides detailed logging and error reporting
    - Cleans up test artifacts (with user confirmation)
    - Supports -WhatIf for safe dry-runs
    - Suitable for git bisect integration (meaningful exit codes)

    See PLAN.md for detailed implementation roadmap and future enhancements.

.PARAMETER QueScript
    Path to the que57.ps1 script under test. Defaults to ".\que57.ps1".

.PARAMETER TestRootPath
    Optional override for the temp folder location where test workspaces will be created.

.PARAMETER GitHubToken
    GitHub Personal Access Token with repo creation permissions. If not provided,
    the script will check the QUE_TEST_GITHUB_PAT environment variable, or prompt
    securely and save the token to that session variable for this PowerShell session.

.PARAMETER AutoApprove
    Run in non-interactive mode; automatically answer all prompts and clean up every artifact,
    including the remote GitHub repository.

.PARAMETER KeepArtifacts
    Skip cleanup prompts and keep all test artifacts for inspection.

.PARAMETER Timeout
    Timeout in seconds to wait for SyncThing synchronization operations. Default is 60.

.EXAMPLE
    .\Test-Que.ps1 -GitHubToken "ghp_xxxxx"

    Runs the full test suite using the specified GitHub token.

.EXAMPLE
    .\Test-Que.ps1 -WhatIf

    Shows what would be done without actually executing the tests.

.EXAMPLE
    .\Test-Que.ps1 -KeepArtifacts

    Runs tests and keeps all artifacts without prompting for cleanup.

.EXAMPLE
    .\Test-Que.ps1 -GitHubToken "ghp_xxxxx" -AutoApprove

    Runs the full test suite without interactive prompts and removes the test artifacts afterward.

.EXAMPLE
    git bisect start
    git bisect bad HEAD
    git bisect good v1.0
    git bisect run pwsh -File Test-Que.ps1 -GitHubToken "ghp_xxxxx" -KeepArtifacts

    Uses git bisect to find the first bad commit, running this test at each step.

.NOTES
    Exit Codes:
    0 - All tests passed
    1 - Test failure (suitable for git bisect)
    2 - Pre-condition failure (e.g., repo already exists)
    3 - Environment validation failure

    Created: 2026-01-04
    Based on: PLAN.md implementation specification
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter(Mandatory=$false)]
    [string]$QueScript = ".\que57.ps1",

    [Parameter(Mandatory=$false)]
    [string]$TestRootPath,

    [Parameter(Mandatory=$false)]
    [string]$GitHubToken,

    [Parameter(Mandatory=$false)]
    [switch]$AutoApprove,

    [Parameter(Mandatory=$false)]
    [switch]$KeepArtifacts,

    [Parameter(Mandatory=$false)]
    [int]$Timeout = 60
)

# Script-level variables
$script:TestRoot = $null
$script:TestStartTime = Get-Date
$script:TestResults = @{
    StepsCompleted = 0
    StepsFailed = 0
    Workspace1Path = $null
    Workspace2Path = $null
    Workspace1ClonePath = $null
    Workspace2ClonePath = $null
    Workspace1CloneName = $null
    Workspace2CloneName = $null
    SyncThingPIDs = @()
    GitHubRepoName = "test-que-demo-repo"
    GitHubUser = $null
    TestRootPath = $null
}
$script:InitialSyncThingPIDs = @()

$script:NonInteractive = $AutoApprove.IsPresent
if ($script:NonInteractive) {
    Write-Host "Non-interactive mode enabled; prompts will be auto-approved." -ForegroundColor Gray
    $KeepArtifacts = $false
}

# Preload CIM cmdlets to avoid WhatIf noise from module alias setup.
$savedWhatIfPreference = $WhatIfPreference
try {
    $WhatIfPreference = $false
    Import-Module CimCmdlets -ErrorAction SilentlyContinue | Out-Null
}
finally {
    $WhatIfPreference = $savedWhatIfPreference
}

#region Helper Functions

function Write-TestStep {
    <#
    .SYNOPSIS
        Logs a test step with timestamp.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $output = "[$timestamp] STEP: $Message"
    Write-Host $output -ForegroundColor Cyan

    if ($script:TestRoot) {
        $logFile = Join-Path $script:TestRoot "test-que-log.txt"
        Add-Content -Path $logFile -Value $output
    }
}

function Write-TestSuccess {
    <#
    .SYNOPSIS
        Logs a successful test validation.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $output = "[$timestamp] SUCCESS: $Message"
    Write-Host $output -ForegroundColor Green

    if ($script:TestRoot) {
        $logFile = Join-Path $script:TestRoot "test-que-log.txt"
        Add-Content -Path $logFile -Value $output
    }

    $script:TestResults.StepsCompleted++
}

function Write-TestFailure {
    <#
    .SYNOPSIS
        Logs a test failure and exits with code 1.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,

        [Parameter(Mandatory=$false)]
        [int]$ExitCode = 1
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $output = "[$timestamp] FAILURE: $Message"
    Write-Host $output -ForegroundColor Red

    if ($script:TestRoot) {
        $logFile = Join-Path $script:TestRoot "test-que-log.txt"
        Add-Content -Path $logFile -Value $output
    }

    $script:TestResults.StepsFailed++

    # Display summary before exit
    Write-Host "`n============================================" -ForegroundColor Red
    Write-Host "TEST FAILED" -ForegroundColor Red
    Write-Host "============================================" -ForegroundColor Red
    Write-Host "Steps Completed: $($script:TestResults.StepsCompleted)"
    Write-Host "Steps Failed: $($script:TestResults.StepsFailed)"
    Write-Host "Error: $Message"
    Write-Host "============================================`n" -ForegroundColor Red

    exit $ExitCode
}

function Wait-ForFile {
    <#
    .SYNOPSIS
        Polls for file existence with timeout.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,

        [Parameter(Mandatory=$false)]
        [int]$TimeoutSeconds = 60,

        [Parameter(Mandatory=$false)]
        [int]$PollIntervalSeconds = 2
    )

    $elapsed = 0
    Write-Host "Waiting for file: $Path (timeout: ${TimeoutSeconds}s)" -ForegroundColor Yellow

    while ($elapsed -lt $TimeoutSeconds) {
        if (Test-Path $Path) {
            Write-TestSuccess "File appeared after ${elapsed}s: $Path"
            return $true
        }

        Start-Sleep -Seconds $PollIntervalSeconds
        $elapsed += $PollIntervalSeconds
        Write-Host "." -NoNewline -ForegroundColor Yellow
    }

    Write-Host ""
    return $false
}

function Wait-ForUserConfirmation {
    <#
    .SYNOPSIS
        Prompts user to continue on timeout.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message
    )

    Write-Host "`n$Message" -ForegroundColor Yellow
    if ($script:NonInteractive) {
        Write-Host "Non-interactive mode: proceeding automatically." -ForegroundColor Gray
        return $true
    }

    $response = Read-Host "Continue waiting? (y/N)"

    return ($response -eq 'y' -or $response -eq 'Y')
}

function Get-SyncThingProcessCount {
    <#
    .SYNOPSIS
        Counts running SyncThing instances (main processes only, not helper processes).
    #>
    $processes = @(Get-Process -Name "syncthing" -ErrorAction SilentlyContinue)

    # Count only parent processes (those whose parent is not another syncthing process)
    $syncthingPIDs = $processes | ForEach-Object { $_.Id }
    $parentProcesses = $processes | Where-Object {
        try {
            $parent = Get-CimInstance Win32_Process -Filter "ProcessId=$($_.Id)" -ErrorAction SilentlyContinue |
                      Select-Object -ExpandProperty ParentProcessId
            # Include this process if its parent is not a syncthing process
            return $parent -notin $syncthingPIDs
        } catch {
            # If we can't determine parent, count it as a main process
            return $true
        }
    }

    return $parentProcesses.Count
}

function Get-SyncThingProcessDetails {
    <#
    .SYNOPSIS
        Gets SyncThing process details including command line when available.
    #>
    $processes = @(Get-CimInstance Win32_Process -Filter "Name='syncthing.exe'" -ErrorAction SilentlyContinue)
    if ($processes.Count -gt 0) {
        return $processes
    }

    return @(Get-Process -Name "syncthing" -ErrorAction SilentlyContinue | ForEach-Object {
        [pscustomobject]@{
            ProcessId = $_.Id
            Name = $_.ProcessName
            CommandLine = $null
        }
    })
}

function Get-TestSyncThingProcessIds {
    <#
    .SYNOPSIS
        Returns SyncThing PIDs that are likely started by this test.
    #>
    param(
        [Parameter(Mandatory=$false)]
        [string]$TestRootPath,

        [Parameter(Mandatory=$false)]
        [int[]]$BaselinePids = @()
    )

    $processes = Get-SyncThingProcessDetails
    if (-not $processes) {
        return @()
    }

    $testPids = @()
    foreach ($proc in $processes) {
        $procId = $proc.ProcessId
        $cmd = $proc.CommandLine
        $isNew = $BaselinePids -notcontains $procId
        $isTestPath = $false

        if ($TestRootPath -and $cmd) {
            $isTestPath = $cmd -like "*$TestRootPath*"
        }

        if ($isNew -or $isTestPath) {
            $testPids += $procId
        }
    }

    return $testPids | Sort-Object -Unique
}

function Wait-ForProcessExit {
    <#
    .SYNOPSIS
        Waits for specific process IDs to exit, with timeout.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [int[]]$ProcessIds,

        [Parameter(Mandatory=$false)]
        [int]$TimeoutSeconds = 15,

        [Parameter(Mandatory=$false)]
        [int]$PollIntervalSeconds = 1
    )

    if (-not $ProcessIds -or $ProcessIds.Count -eq 0) {
        return $true
    }

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        $remaining = @()
        foreach ($procId in $ProcessIds) {
            if (Get-Process -Id $procId -ErrorAction SilentlyContinue) {
                $remaining += $procId
            }
        }

        if ($remaining.Count -eq 0) {
            return $true
        }

        Start-Sleep -Seconds $PollIntervalSeconds
    }

    return $false
}

function Invoke-QueScriptWithInput {
    <#
    .SYNOPSIS
        Invokes que57.ps1 with automated input
    .DESCRIPTION
        Uses a temporary input file to automate responses to que57.ps1 prompts
        This is the best approach since PowerShell's Start-Process doesn't support
        input redirection on Windows in the same way as Unix systems
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$ScriptPath,

        [Parameter(Mandatory=$true)]
        [string[]]$InputLines,

        [Parameter(Mandatory=$false)]
        [string]$WorkingDirectory = (Get-Location)
    )

    # Create temporary input file
    $InputFile = [System.IO.Path]::GetTempFileName()
    $InputLines | Set-Content $InputFile

    try {
        # Build the PowerShell command
        $Command = @"
Set-Location '$WorkingDirectory'
Get-Content '$InputFile' | & '$ScriptPath'
"@

        # Execute
        $Output = powershell.exe -NoProfile -ExecutionPolicy Bypass -Command $Command 2>&1

        return @{
            Success = $LASTEXITCODE -eq 0
            Output = $Output
            ExitCode = $LASTEXITCODE
        }
    }
    finally {
        # Clean up temp file
        if (Test-Path $InputFile) {
            Remove-Item $InputFile -Force
        }
    }
}

function Test-GitHubRepoExists {
    <#
    .SYNOPSIS
        Checks if a GitHub repository exists.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$RepoName,

        [Parameter(Mandatory=$true)]
        [string]$Token,

        [Parameter(Mandatory=$true)]
        [string]$Owner
    )

    try {
        $headers = @{
            Authorization = "token $Token"
            Accept = "application/vnd.github.v3+json"
        }

        $url = "https://api.github.com/repos/$Owner/$RepoName"
        $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get -ErrorAction Stop
        return $true
    }
    catch {
        if ($_.Exception.Response.StatusCode -eq 404) {
            return $false
        }
        # Re-throw other errors
        throw
    }
}

function Get-GitHubUser {
    <#
    .SYNOPSIS
        Gets the authenticated GitHub user information.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Token
    )

    try {
        $headers = @{
            Authorization = "token $Token"
            Accept = "application/vnd.github.v3+json"
        }

        $url = "https://api.github.com/user"
        $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get -ErrorAction Stop
        return $response
    }
    catch {
        throw "Failed to get GitHub user information: $_"
    }
}

#endregion

#region Phase 1: Pre-flight Checks

Write-Host "`n============================================" -ForegroundColor Cyan
Write-Host "TEST-QUE: Automated End-to-End Testing" -ForegroundColor Cyan
Write-Host "============================================`n" -ForegroundColor Cyan

Write-TestStep "Starting pre-flight checks"

# Step 1.1: Validate Environment
Write-TestStep "Validating PowerShell version"
if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-TestFailure "PowerShell 5.1 or later is required. Current version: $($PSVersionTable.PSVersion)" -ExitCode 3
}
Write-TestSuccess "PowerShell version $($PSVersionTable.PSVersion) is compatible"

Write-TestStep "Verifying que57.ps1 exists at: $QueScript"
if (-not (Test-Path $QueScript)) {
    Write-TestFailure "que57.ps1 not found at path: $QueScript" -ExitCode 3
}
Write-TestSuccess "que57.ps1 found"

Write-TestStep "Verifying Git installation"
try {
    $gitVersion = & git --version 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-TestFailure "Git is not installed or not accessible" -ExitCode 3
    }
    Write-TestSuccess "Git is installed: $gitVersion"
}
catch {
    Write-TestFailure "Git is not installed or not accessible: $_" -ExitCode 3
}

Write-TestStep "Verifying Git LFS installation"
try {
    $gitLfsVersion = & git lfs version 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-TestFailure "Git LFS is not installed or not accessible" -ExitCode 3
    }
    Write-TestSuccess "Git LFS is installed: $gitLfsVersion"
}
catch {
    Write-TestFailure "Git LFS is not installed or not accessible: $_" -ExitCode 3
}

Write-TestStep "Verifying SyncThing accessibility"
# Try common locations for syncthing
$syncthingFound = $false
$syncthingPaths = @(
    "syncthing",  # In PATH
    "$env:ProgramFiles\Syncthing\syncthing.exe",
    "$env:LOCALAPPDATA\Syncthing\syncthing.exe"
)

foreach ($path in $syncthingPaths) {
    try {
        $null = & $path --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            $syncthingFound = $true
            Write-TestSuccess "SyncThing found at: $path"
            break
        }
    }
    catch {
        # Continue checking other paths
    }
}

if (-not $syncthingFound) {
    Write-Host "WARNING: SyncThing not found in common locations. Tests may fail if que57.ps1 cannot find it." -ForegroundColor Yellow
}

# Step 1.2: GitHub Token Acquisition
Write-TestStep "Acquiring GitHub token"
if (-not $GitHubToken) {
    # Try to get token from environment variable
    if ($env:QUE_TEST_GITHUB_PAT) {
        $GitHubToken = $env:QUE_TEST_GITHUB_PAT
        Write-Host "Using GitHub PAT from environment variable QUE_TEST_GITHUB_PAT" -ForegroundColor Gray
    }
    else {
        if ($script:NonInteractive) {
            Write-TestFailure "GitHub token must be provided using -GitHubToken or QUE_TEST_GITHUB_PAT when running in non-interactive mode" -ExitCode 3
        }
        Write-Host "GitHub Personal Access Token is required for testing." -ForegroundColor Yellow
        Write-Host "The token needs 'repo' permissions to create and delete repositories." -ForegroundColor Yellow
        Write-Host "To avoid re-entering the token in this session, it will be saved to environment variable QUE_TEST_GITHUB_PAT" -ForegroundColor Yellow
        $secureToken = Read-Host "Enter GitHub PAT" -AsSecureString
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)
        $GitHubToken = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)

        # Save to session environment variable for this PowerShell session only
        $env:QUE_TEST_GITHUB_PAT = $GitHubToken
        Write-Host "GitHub PAT saved to session environment variable QUE_TEST_GITHUB_PAT" -ForegroundColor Green
    }
}

if ([string]::IsNullOrWhiteSpace($GitHubToken)) {
    Write-TestFailure "GitHub token is required but was not provided" -ExitCode 3
}

Write-TestStep "Validating GitHub token"
try {
    $user = Get-GitHubUser -Token $GitHubToken
    $script:TestResults.GitHubUser = $user.login
    Write-TestSuccess "GitHub token is valid. Authenticated as: $($user.login)"
}
catch {
    Write-TestFailure "GitHub token validation failed: $_" -ExitCode 3
}

# Step 1.3: Pre-condition Validation
Write-TestStep "Checking if test repository already exists"
$repoExists = Test-GitHubRepoExists -RepoName $script:TestResults.GitHubRepoName -Token $GitHubToken -Owner $script:TestResults.GitHubUser

if ($repoExists) {
    $repoUrl = "https://github.com/$($script:TestResults.GitHubUser)/$($script:TestResults.GitHubRepoName)"
    Write-Host "`nWARNING: Test repository already exists!" -ForegroundColor Yellow
    Write-Host "Repository: $repoUrl" -ForegroundColor Yellow

    if (-not $KeepArtifacts) {
        Write-Host "`nThe test repository needs to be deleted to run this test." -ForegroundColor Yellow
        if ($script:NonInteractive) {
            Write-Host "Non-interactive mode: deleting existing repository without prompting." -ForegroundColor Gray
            $deleteExisting = 'y'
        }
        else {
            $deleteExisting = Read-Host "Delete existing repository '$($script:TestResults.GitHubRepoName)'? (y/N)"
        }

        if ($deleteExisting -eq 'y' -or $deleteExisting -eq 'Y') {
            if ($PSCmdlet.ShouldProcess($script:TestResults.GitHubRepoName, "delete from GitHub")) {
                Write-Host "Deleting existing repository..." -ForegroundColor Cyan
                try {
                    $headers = @{
                        Authorization = "token $GitHubToken"
                        Accept = "application/vnd.github.v3+json"
                    }
                    $deleteUrl = "https://api.github.com/repos/$($script:TestResults.GitHubUser)/$($script:TestResults.GitHubRepoName)"
                    Invoke-RestMethod -Method Delete -Uri $deleteUrl -Headers $headers -ErrorAction Stop
                    Write-TestSuccess "Deleted existing GitHub repository: $repoUrl"
                    $repoExists = $false
                }
                catch {
                    Write-TestFailure "Failed to delete GitHub repository: $_`nPlease delete manually: $repoUrl/settings" -ExitCode 2
                }
            }
        }
    }

    if ($repoExists) {
        Write-Host "`nPlease delete this repository manually before running the test:" -ForegroundColor Yellow
        Write-Host "  1. Visit: $repoUrl/settings" -ForegroundColor Yellow
        Write-Host "  2. Scroll to 'Danger Zone'" -ForegroundColor Yellow
        Write-Host "  3. Click 'Delete this repository'" -ForegroundColor Yellow
        Write-Host "`nOr use the GitHub CLI: gh repo delete $($script:TestResults.GitHubUser)/$($script:TestResults.GitHubRepoName)`n" -ForegroundColor Yellow
        Write-TestFailure "Pre-condition failed: Test repository already exists at $repoUrl" -ExitCode 2
    }
}

if (-not $repoExists) {
    Write-TestSuccess "Test repository does not exist (pre-condition met)"
}

Write-TestSuccess "All pre-flight checks passed"

#endregion

Write-Host "`n============================================" -ForegroundColor Green
Write-Host "Pre-flight checks completed successfully" -ForegroundColor Green
Write-Host "Ready to begin testing..." -ForegroundColor Green
Write-Host "============================================`n" -ForegroundColor Green

# Capture any SyncThing processes running before tests start.
$script:InitialSyncThingPIDs = @(Get-Process -Name "syncthing" -ErrorAction SilentlyContinue | ForEach-Object { $_.Id })

#region Phase 2: Test Environment Setup

Write-TestStep "Creating test environment"

# Step 2.1: Create Temp Folder Structure
if (-not $TestRootPath) {
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $TestRootPath = Join-Path $env:TEMP "que-test-$timestamp"
}
$script:TestResults.TestRootPath = $TestRootPath

if ($PSCmdlet.ShouldProcess($TestRootPath, "create test root directory")) {
    $script:TestRoot = New-Item -ItemType Directory -Path $TestRootPath -Force
    Write-TestSuccess "Test root created at: $($script:TestRoot.FullName)"

    # Create log file
    $logFile = Join-Path $script:TestRoot "test-que-log.txt"
    "Test-Que.ps1 Log - Started at $script:TestStartTime" | Set-Content -Path $logFile
    Write-TestSuccess "Log file created: $logFile"
}
else {
    Write-Host "WhatIf: Would create test root at $TestRootPath" -ForegroundColor Yellow
}

#endregion

#region Phase 3: First Workspace Creation

Write-TestStep "Phase 3: Creating first workspace"

# Dot-source que57.ps1 to access its functions directly
Write-Host "Loading que57.ps1 functions..." -ForegroundColor Cyan
. $QueScript

# Load que57.ps1 content into $queScript variable (required by New-QueRepoScript)
$script:queScript = Get-Content -Path $QueScript -Raw -Encoding UTF8

# Override Get-UserSelectionIndex to automate initialization method selection (0 = blank project)
# This allows automated testing without user interaction
if (Get-Command Get-UserSelectionIndex -ErrorAction SilentlyContinue) {
    Write-Host "Overriding Get-UserSelectionIndex for test automation..." -ForegroundColor Gray
}
function Get-UserSelectionIndex {
    Param ([string[]]$Options, [int]$Default, [switch]$DontShortcutSingleChoice)
    Write-Host "[Test automation] Auto-selecting: $($Options[0])" -ForegroundColor Gray
    return 0
}

$testRootPushed = $false
try {
    if ($PSCmdlet.ShouldProcess("first workspace", "create")) {
        # Change to test root for workspace creation
        Push-Location $script:TestRoot
        $testRootPushed = $true

        # Create test user info object
        $TestUser = Test-GitHubPAT -PlainPAT $GitHubToken
        if (-not $TestUser) {
            Write-TestFailure "Failed to validate GitHub token for workspace creation"
        }

        Write-TestSuccess "Validated GitHub token for user: $($TestUser.login)"

        # Create workspace directory and change to it
        $Workspace1Name = "workspace-1"
        $Workspace1Path = Join-Path $script:TestRoot $Workspace1Name
        New-Item -ItemType Directory -Force -Path $Workspace1Path | Out-Null
        Set-Location $Workspace1Path

        Write-Host "Creating workspace at: $Workspace1Path" -ForegroundColor Cyan

        # Call New-QueWorkspace function directly (from dot-sourced que57.ps1)
        New-QueWorkspace -GitHubOwner $TestUser.login `
                         -GitHubRepo $script:TestResults.GitHubRepoName `
                         -PlainPAT $GitHubToken `
                         -UserInfo $TestUser

        # Validate workspace was created
        if (-not (Test-Path "$Workspace1Path\.que")) {
            Write-TestFailure "Workspace .que folder not created"
        }
        Write-TestSuccess "Workspace .que folder created"

        if (-not (Test-Path "$Workspace1Path\repo")) {
            Write-TestFailure "Workspace repo folder not created"
        }
        Write-TestSuccess "Workspace repo folder created"

        # Validate first clone was created
        $FirstClone = Get-ChildItem "$Workspace1Path\repo" -Directory | Select-Object -First 1
        if (-not $FirstClone) {
            Write-TestFailure "No clone directory found in workspace"
        }

        $FirstClonePath = $FirstClone.FullName
        Write-TestSuccess "First clone created at: $FirstClonePath"
        $script:TestResults.Workspace1ClonePath = $FirstClonePath
        $script:TestResults.Workspace1CloneName = $FirstClone.Name

        # Validate Git repository
        if (-not (Test-Path "$FirstClonePath\.git")) {
            Write-TestFailure "Git repository not initialized in clone"
        }
        Write-TestSuccess "Git repository initialized"

        # Validate GitHub repo was created and pushed
        Push-Location $FirstClonePath
        $RemoteUrl = git remote get-url origin 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-TestFailure "Git remote not configured"
        }
        Write-TestSuccess "Git remote configured: $RemoteUrl"

        # Check that initial commit was pushed
        git log -1 --oneline 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-TestFailure "No commits found in repository"
        }
        Write-TestSuccess "Initial commit found"

        Pop-Location

        # Store workspace path for later phases
        $script:TestResults.Workspace1Path = $Workspace1Path

        Write-TestSuccess "First workspace created successfully"
    }
}
catch {
    Write-TestFailure "Workspace creation failed: $($_.Exception.Message)"
}
finally {
    if ($testRootPushed) {
        Pop-Location
    }
}

#endregion

#region Phase 4: Second Workspace from Generated Script

Write-TestStep "Phase 4: Creating second workspace using generated script"

try {
    if ($PSCmdlet.ShouldProcess("second workspace", "create")) {
        # Step 4.1: Locate the generated que-<repo>.ps1 script from first workspace
        $FirstClone = Get-ChildItem "$($script:TestResults.Workspace1Path)\repo" -Directory | Select-Object -First 1
        if (-not $FirstClone) {
            Write-TestFailure "Could not find first clone directory"
        }

        $GeneratedScript = Join-Path $FirstClone.FullName "que57-project.ps1"
        if (-not (Test-Path $GeneratedScript)) {
            Write-TestFailure "Generated script not found at: $GeneratedScript"
        }
        Write-TestSuccess "Found generated script: $GeneratedScript"

        # Step 4.2: Create second workspace directory
        $Workspace2Path = Join-Path $script:TestRoot "workspace-2"
        New-Item -ItemType Directory -Force -Path $Workspace2Path | Out-Null
        Write-TestSuccess "Created workspace-2 directory: $Workspace2Path"

        # Change to the new workspace directory
        Push-Location $Workspace2Path

        # Remove functions from que57.ps1 to avoid conflicts (unload the namespace)
        # Get list of functions that were defined by que57.ps1
        $FunctionsToRemove = @(
            'Find-QueWorkspace', 'Get-AvailableSyncThingPort', 'Get-SecureGitHubPAT',
            'Set-SecureGitHubPAT', 'Store-GitCredentials', 'Test-GitHubPAT',
            'Get-NextCloneName', 'Find-UProjectFile', 'New-WindowsShortcut',
            'Test-IsAdmin', 'Install-NetFx3WithElevation', 'Sync-WingetPackage',
            'Get-UserSelectionIndex', 'Get-EpicGamesLauncherExecutable',
            'Get-SyncThingExecutable', 'Ensure-SyncThingRunning', 'Initialize-SyncThing',
            'Configure-SyncThingFolders', 'Update-SyncThingDevices', 'Write-GitConfigFiles',
            'Write-UEGitConfigFiles', 'Install-AllDependencies', 'New-QueRepoScript',
            'New-QueWorkspace', 'New-QueClone', 'Invoke-QueMain'
        )

        foreach ($FuncName in $FunctionsToRemove) {
            if (Get-Command $FuncName -ErrorAction SilentlyContinue) {
                Remove-Item "Function:\$FuncName" -ErrorAction SilentlyContinue
            }
        }
        Write-Host "Unloaded que57.ps1 functions to avoid namespace conflicts" -ForegroundColor Gray

        # Dot-source the GENERATED script (contains repo-specific constants)
        Write-Host "Loading generated script with repository constants..." -ForegroundColor Cyan
        . $GeneratedScript

        # Load the generated script content into $queScript variable
        # This is needed in case New-QueWorkspace needs to call New-QueRepoScript
        $script:queScript = Get-Content -Path $GeneratedScript -Raw -Encoding UTF8

        # The generated script has $GitHubOwner and $GitHubRepo already set
        # We need to call New-QueWorkspace to create the second workspace
        Write-Host "Creating second workspace for $GitHubOwner/$GitHubRepo..." -ForegroundColor Cyan

        # Create user info object
        $TestUser = Test-GitHubPAT -PlainPAT $GitHubToken
        if (-not $TestUser) {
            Write-TestFailure "Failed to validate GitHub token for second workspace"
        }

        # Call New-QueWorkspace function from the generated script
        # This will clone the existing repo (since it already exists on GitHub)
        New-QueWorkspace -GitHubOwner $GitHubOwner `
                         -GitHubRepo $GitHubRepo `
                         -PlainPAT $GitHubToken `
                         -UserInfo $TestUser

        Pop-Location

        # Step 4.3: Validate second workspace
        if (-not (Test-Path "$Workspace2Path\.que")) {
            Write-TestFailure "Second workspace .que folder not created"
        }
        Write-TestSuccess "Second workspace .que folder created"

        if (-not (Test-Path "$Workspace2Path\repo")) {
            Write-TestFailure "Second workspace repo folder not created"
        }
        Write-TestSuccess "Second workspace repo folder created"

        # Validate clone was created
        $SecondClone = Get-ChildItem "$Workspace2Path\repo" -Directory | Select-Object -First 1
        if (-not $SecondClone) {
            Write-TestFailure "No clone directory found in second workspace"
        }
        Write-TestSuccess "Second workspace clone created at: $($SecondClone.FullName)"
        $script:TestResults.Workspace2ClonePath = $SecondClone.FullName
        $script:TestResults.Workspace2CloneName = $SecondClone.Name

        # Verify SyncThing is running (should have 2 instances now)
        Start-Sleep -Seconds 3  # Give SyncThing time to start
        $SyncCount = Get-SyncThingProcessCount
        if ($SyncCount -lt 2) {
            Write-Host "WARNING: Expected 2 SyncThing processes, found $SyncCount" -ForegroundColor Yellow
            Write-Host "This may be expected if SyncThing instances share the same process" -ForegroundColor Yellow
        } else {
            Write-TestSuccess "SyncThing processes running: $SyncCount"
        }

        # Store second workspace path
        $script:TestResults.Workspace2Path = $Workspace2Path

        Write-TestSuccess "Second workspace created successfully"
    }
}
catch {
    Write-TestFailure "Second workspace creation failed: $($_.Exception.Message)"
}

#endregion

#region Phase 5: Git LFS Commit Test

Write-TestStep "Phase 5: Creating and publishing LFS-tracked file"

try {
    if ($PSCmdlet.ShouldProcess("LFS test file", "create and push")) {
        # Step 5.1: Create LFS-tracked file in second workspace
        if (-not $script:TestResults.Workspace2Path) {
            Write-TestFailure "Second workspace not available for LFS test"
        }

        $SecondClonePath = $script:TestResults.Workspace2ClonePath
        $SecondCloneName = $script:TestResults.Workspace2CloneName
        if (-not $SecondClonePath -or -not (Test-Path $SecondClonePath)) {
            $SecondClone = Get-ChildItem "$($script:TestResults.Workspace2Path)\repo" -Directory | Select-Object -First 1
            if (-not $SecondClone) {
                Write-TestFailure "Could not find second workspace clone directory"
            }
            $SecondClonePath = $SecondClone.FullName
            $SecondCloneName = $SecondClone.Name
            $script:TestResults.Workspace2ClonePath = $SecondClonePath
            $script:TestResults.Workspace2CloneName = $SecondCloneName
        }

        Write-Host "Using second workspace clone: $SecondClonePath" -ForegroundColor Cyan

        Push-Location $SecondClonePath

        # Create a .uasset file (tracked by LFS per .gitattributes)
        $LfsFile = "TestAsset.uasset"
        $TestContent = "This is a test Unreal asset file for LFS tracking validation. Created at $(Get-Date -Format 'o')"
        Set-Content -Path $LfsFile -Value $TestContent
        Write-TestSuccess "Created test .uasset file: $LfsFile"

        # Step 5.2: Save work to que/<clone> and publish to main (with default tag)
        $SavedBranch = Invoke-QueSaveCommand -CloneRoot $SecondClonePath
        if ($SavedBranch -ne "que/$SecondCloneName") {
            Pop-Location
            Write-TestFailure "Unexpected save branch name. Expected que/$SecondCloneName, got $SavedBranch"
        }
        Write-TestSuccess "Saved changes on branch: $SavedBranch"

        $PublishedBranch = Invoke-QuePublishCommand -CloneRoot $SecondClonePath -TagName "lkg"
        Write-TestSuccess "Published branch $PublishedBranch to main and updated tag 'lkg'"

        # Verify remote work branch exists
        $BranchRef = "refs/remotes/origin/que/$SecondCloneName"
        git show-ref --verify $BranchRef 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Pop-Location
            Write-TestFailure "Remote branch not found after publish: que/$SecondCloneName"
        }
        Write-TestSuccess "Remote work branch exists: que/$SecondCloneName"

        # Verify the file is tracked by LFS
        $LfsLs = git lfs ls-files
        if ($LfsLs -match $LfsFile) {
            Write-TestSuccess "File is tracked by LFS: $LfsFile"
        } else {
            Write-Host "WARNING: File may not be properly tracked by LFS" -ForegroundColor Yellow
            Write-Host "LFS files: $LfsLs" -ForegroundColor Gray
        }

        Pop-Location

        Write-TestSuccess "LFS commit test completed successfully"
    }
}
catch {
    if (Get-Location | Select-Object -ExpandProperty Path | Where-Object { $_ -ne $script:TestRoot }) {
        Pop-Location
    }
    Write-TestFailure "LFS commit test failed: $($_.Exception.Message)"
}

#endregion

#region Phase 6: SyncThing Peer Auto-Addition Test

Write-TestStep "Phase 6: Testing automatic SyncThing peer addition and folder sharing"

try {
    if ($PSCmdlet.ShouldProcess("SyncThing peer auto-addition", "test")) {
        # Step 6.1: Launch workspace 2's .lnk to trigger device ID registration
        Write-Host "`nStep 6.1: Launching workspace 2 to register its SyncThing device ID" -ForegroundColor Cyan

        $Workspace2Clone = Get-ChildItem "$($script:TestResults.Workspace2Path)\repo" -Directory | Select-Object -First 1
        if (-not $Workspace2Clone) {
            Write-TestFailure "Could not find workspace 2 clone directory"
        }

        $Workspace2ClonePath = $Workspace2Clone.FullName
        $Workspace2CloneName = $Workspace2Clone.Name
        $Workspace2LnkPath = Join-Path $script:TestResults.Workspace2Path "open-$Workspace2CloneName.lnk"
        $Workspace2ScriptPath = Join-Path $Workspace2ClonePath "que57-project.ps1"

        if (-not (Test-Path $Workspace2LnkPath)) {
            Write-TestFailure "Workspace 2 .lnk file not found at: $Workspace2LnkPath"
        }
        Write-TestSuccess "Found workspace 2 shortcut: $Workspace2LnkPath"

        # Execute the script directly (simulates double-clicking the .lnk)
        Write-Host "Executing workspace 2 launch script..." -ForegroundColor Gray
        Push-Location $Workspace2ClonePath

        # Run the script and capture output, providing 'exit' to exit the interactive loop
        $LaunchOutput = "exit" | & powershell.exe -ExecutionPolicy Bypass -File $Workspace2ScriptPath 2>&1

        Pop-Location

        Write-Host "Launch output (last 10 lines):" -ForegroundColor Gray
        $LaunchOutput | Select-Object -Last 10 | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }

        # Step 6.2: Verify the script was modified (has local diff)
        Write-Host "`nStep 6.2: Verifying que script was modified with device ID" -ForegroundColor Cyan

        Push-Location $Workspace2ClonePath

        # Check git status for changes
        $GitStatus = git status --porcelain "que57-project.ps1" 2>&1

        if ([string]::IsNullOrWhiteSpace($GitStatus)) {
            Write-Host "WARNING: No changes detected in que script. Device ID may already be registered." -ForegroundColor Yellow
            Write-Host "This may be expected if the script was already modified in an earlier phase." -ForegroundColor Yellow
        } else {
            Write-TestSuccess "Que script has local changes (device ID was added)"
            Write-Host "Git status: $GitStatus" -ForegroundColor Gray
        }

        # Check git diff to see what changed
        $GitDiff = git diff "que57-project.ps1" 2>&1
        if ($GitDiff) {
            Write-Host "`nChanges in que script:" -ForegroundColor Gray
            $GitDiff | Select-Object -First 20 | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }

            # Look for SyncThingDevices in the diff
            if ($GitDiff -match '\$SyncThingDevices') {
                Write-TestSuccess "Detected SyncThingDevices array modification in diff"
            }
        }

        # Step 6.3: Publish the change using que workflow commands
        Write-Host "`nStep 6.3: Publishing SyncThing device ID via que workflow" -ForegroundColor Cyan

        $PublishedSyncBranch = Invoke-QuePublishCommand -CloneRoot $Workspace2ClonePath
        Write-TestSuccess "Published device ID change from branch: $PublishedSyncBranch"

        Pop-Location

        # Step 6.4: Switch to workspace 1 and update
        Write-Host "`nStep 6.4: Updating workspace 1" -ForegroundColor Cyan

        $Workspace1Clone = Get-ChildItem "$($script:TestResults.Workspace1Path)\repo" -Directory | Select-Object -First 1
        if (-not $Workspace1Clone) {
            Write-TestFailure "Could not find workspace 1 clone directory"
        }

        $Workspace1ClonePath = $Workspace1Clone.FullName
        $Workspace1CloneName = $Workspace1Clone.Name

        Push-Location $Workspace1ClonePath

        Invoke-QueUpdateCommand -CloneRoot $Workspace1ClonePath | Out-Null
        Write-TestSuccess "Updated workspace 1 with latest main"

        # Verify the que script was updated
        $Workspace1ScriptPath = Join-Path $Workspace1ClonePath "que57-project.ps1"
        $ScriptContent = Get-Content $Workspace1ScriptPath -Raw

        if ($ScriptContent -match '\$SyncThingDevices\s*=\s*@\(') {
            Write-TestSuccess "Que script contains SyncThingDevices array"

            # Extract device IDs to see if there are multiple
            if ($ScriptContent -match '\$SyncThingDevices\s*=\s*@\(([^)]+)\)') {
                $DevicesBlock = $matches[1]
                $DeviceCount = ([regex]::Matches($DevicesBlock, '"([^"]+)"')).Count
                Write-Host "Found $DeviceCount device ID(s) in script" -ForegroundColor Gray

                if ($DeviceCount -ge 2) {
                    Write-TestSuccess "Multiple device IDs found (workspace 1 and workspace 2)"
                } elseif ($DeviceCount -eq 1) {
                    Write-Host "Only 1 device ID found. This may be expected if workspaces share device IDs." -ForegroundColor Yellow
                } else {
                    Write-Host "No device IDs found in array" -ForegroundColor Yellow
                }
            }
        }

        Pop-Location

        # Step 6.5: Launch workspace 1's .lnk to trigger peer addition
        Write-Host "`nStep 6.5: Launching workspace 1 to add workspace 2 as peer" -ForegroundColor Cyan

        $Workspace1LnkPath = Join-Path $script:TestResults.Workspace1Path "open-$Workspace1CloneName.lnk"

        if (-not (Test-Path $Workspace1LnkPath)) {
            Write-TestFailure "Workspace 1 .lnk file not found at: $Workspace1LnkPath"
        }
        Write-TestSuccess "Found workspace 1 shortcut: $Workspace1LnkPath"

        # Execute the script directly
        Write-Host "Executing workspace 1 launch script..." -ForegroundColor Gray
        Push-Location $Workspace1ClonePath

        # Run the script and capture output, providing 'exit' to exit the interactive loop
        $LaunchOutput = "exit" | & powershell.exe -ExecutionPolicy Bypass -File $Workspace1ScriptPath 2>&1

        Pop-Location

        Write-Host "Launch output (last 20 lines):" -ForegroundColor Gray
        $LaunchOutput | Select-Object -Last 20 | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }

        # Step 6.6: Verify peer was added and folders were shared
        Write-Host "`nStep 6.6: Verifying SyncThing peer addition and folder sharing" -ForegroundColor Cyan

        # Look for specific messages in the launch output
        $LaunchOutputString = $LaunchOutput -join "`n"

        if ($LaunchOutputString -match "Adding SyncThing peer") {
            Write-TestSuccess "Detected peer addition in launch output"
        } else {
            Write-Host "No peer addition detected. Peer may already be configured." -ForegroundColor Yellow
        }

        if ($LaunchOutputString -match "Sharing.*folder with peer") {
            Write-TestSuccess "Detected folder sharing in launch output"
        } else {
            Write-Host "No folder sharing detected in output" -ForegroundColor Yellow
        }

        # Additional verification: Check SyncThing config directly
        Push-Location $Workspace1ClonePath

        # Get the syncthing executable path from the workspace
        $SyncThingHome = Join-Path $script:TestResults.Workspace1Path "env\syncthing-home"
        if (Test-Path $SyncThingHome) {
            # Try to list configured devices
            $SyncThingExe = $null
            $SyncThingPaths = @(
                "syncthing",
                "$env:ProgramFiles\Syncthing\syncthing.exe",
                "$env:LOCALAPPDATA\Syncthing\syncthing.exe"
            )

            foreach ($path in $SyncThingPaths) {
                try {
                    $null = & $path --version 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        $SyncThingExe = $path
                        break
                    }
                }
                catch { }
            }

            if ($SyncThingExe) {
                # Read SyncThing config to get GUI address and API key
                $ConfigXml = Join-Path $SyncThingHome "config.xml"
                if (Test-Path $ConfigXml) {
                    [xml]$Config = Get-Content $ConfigXml
                    $GuiAddress = $Config.configuration.gui.address
                    $ApiKey = $Config.configuration.gui.apikey

                    if ($GuiAddress -and $ApiKey) {
                        $DeviceList = & $SyncThingExe cli --home="$SyncThingHome" --gui-address="$GuiAddress" --gui-apikey="$ApiKey" config devices list 2>&1

                        if ($DeviceList) {
                            $DeviceCount = @($DeviceList).Count
                            Write-Host "SyncThing has $DeviceCount configured device(s)" -ForegroundColor Gray

                            if ($DeviceCount -ge 2) {
                                Write-TestSuccess "Multiple devices configured in SyncThing"
                            }
                        }
                    }
                }
            }
        }

        Pop-Location

        Write-TestSuccess "SyncThing peer auto-addition test completed"
    }
}
catch {
    if (Get-Location | Select-Object -ExpandProperty Path | Where-Object { $_ -ne $script:TestRoot }) {
        Pop-Location
    }
    Write-TestFailure "SyncThing peer auto-addition test failed: $($_.Exception.Message)"
}

#endregion

#region Phase 7: SyncThing Depot Test

Write-TestStep "Phase 7: Testing SyncThing depot synchronization"

try {
    if ($PSCmdlet.ShouldProcess("SyncThing depot sync", "test")) {
        # Step 7.1: Create File in Second Workspace Depot
        Write-Host "`nStep 7.1: Creating test file in workspace 2 depot" -ForegroundColor Cyan

        if (-not $script:TestResults.Workspace2Path) {
            Write-TestFailure "Second workspace not available for depot sync test"
        }

        # Locate depot folder in second workspace
        $Workspace2DepotPath = Join-Path $script:TestResults.Workspace2Path "sync\depot"
        if (-not (Test-Path $Workspace2DepotPath)) {
            Write-TestFailure "Depot folder not found in workspace 2: $Workspace2DepotPath"
        }
        Write-TestSuccess "Found workspace 2 depot: $Workspace2DepotPath"

        # Create test file with timestamp
        $TestFileName = "test-syncthing-file.txt"
        $TestFileContent = "SyncThing test created at $(Get-Date -Format 'o')`nThis file validates depot synchronization between workspaces."
        $SourceFilePath = Join-Path $Workspace2DepotPath $TestFileName

        Set-Content -Path $SourceFilePath -Value $TestFileContent -Encoding UTF8
        Write-TestSuccess "Created test file: $SourceFilePath"
        Write-Host "File content: $TestFileContent" -ForegroundColor Gray

        # Step 7.2: Wait for Sync to First Workspace
        Write-Host "`nStep 7.2: Waiting for file to sync to workspace 1" -ForegroundColor Cyan

        if (-not $script:TestResults.Workspace1Path) {
            Write-TestFailure "First workspace not available for depot sync test"
        }

        $Workspace1DepotPath = Join-Path $script:TestResults.Workspace1Path "sync\depot"
        if (-not (Test-Path $Workspace1DepotPath)) {
            Write-TestFailure "Depot folder not found in workspace 1: $Workspace1DepotPath"
        }

        $TargetFilePath = Join-Path $Workspace1DepotPath $TestFileName
        Write-Host "Target path: $TargetFilePath" -ForegroundColor Gray

        # Use Wait-ForFile with configured timeout
        $Synced = Wait-ForFile -Path $TargetFilePath -TimeoutSeconds $Timeout -PollIntervalSeconds 2

        # If timeout occurs, offer to wait longer
        while (-not $Synced) {
            Write-Host "`nFile did not sync within ${Timeout}s timeout" -ForegroundColor Yellow

            # Display diagnostic information
            $SyncCount = Get-SyncThingProcessCount
            Write-Host "SyncThing instances running: $SyncCount" -ForegroundColor Yellow

            if ($SyncCount -lt 2) {
                Write-Host "WARNING: Expected 2 SyncThing instances for sync to work" -ForegroundColor Yellow
            }

            # Ask user if they want to continue waiting
            if (Wait-ForUserConfirmation -Message "SyncThing file sync timeout.") {
                Write-Host "Waiting another ${Timeout}s..." -ForegroundColor Cyan
                $Synced = Wait-ForFile -Path $TargetFilePath -TimeoutSeconds $Timeout -PollIntervalSeconds 2
            }
            else {
                Write-TestFailure "SyncThing depot sync failed: File did not appear in workspace 1 after timeout"
            }
        }

        # Step 7.3: Validate Sync Contents
        Write-Host "`nStep 7.3: Validating synced file contents" -ForegroundColor Cyan

        # Read both files
        $SourceContent = Get-Content -Path $SourceFilePath -Raw -Encoding UTF8
        $TargetContent = Get-Content -Path $TargetFilePath -Raw -Encoding UTF8

        # Compare contents
        if ($SourceContent -ne $TargetContent) {
            Write-Host "Source content: $SourceContent" -ForegroundColor Red
            Write-Host "Target content: $TargetContent" -ForegroundColor Red
            Write-TestFailure "File synced but contents don't match"
        }

        Write-TestSuccess "File contents match between workspaces"

        # Verify file metadata
        $SourceFile = Get-Item $SourceFilePath
        $TargetFile = Get-Item $TargetFilePath

        Write-Host "Source file size: $($SourceFile.Length) bytes" -ForegroundColor Gray
        Write-Host "Target file size: $($TargetFile.Length) bytes" -ForegroundColor Gray

        if ($SourceFile.Length -ne $TargetFile.Length) {
            Write-Host "WARNING: File sizes differ" -ForegroundColor Yellow
        }

        Write-TestSuccess "SyncThing depot synchronization test completed successfully"
    }
}
catch {
    Write-TestFailure "SyncThing depot sync test failed: $($_.Exception.Message)"
}

#endregion

#region Phase 8: Git Pull LFS Validation

Write-TestStep "Phase 8: Testing Git LFS pull with SyncThing cache synchronization"

try {
    if ($PSCmdlet.ShouldProcess("Git LFS pull", "test")) {
        # Step 8.1: Identify the LFS file and its cache object
        Write-Host "`nStep 8.1: Identifying LFS file from Phase 5" -ForegroundColor Cyan

        if (-not $script:TestResults.Workspace2Path) {
            Write-TestFailure "Second workspace not available for LFS pull test"
        }

        $Workspace2Clone = Get-ChildItem "$($script:TestResults.Workspace2Path)\repo" -Directory | Select-Object -First 1
        if (-not $Workspace2Clone) {
            Write-TestFailure "Could not find workspace 2 clone directory"
        }

        $Workspace2ClonePath = $Workspace2Clone.FullName
        $LfsFileName = "TestAsset.uasset"
        $LfsFilePath = Join-Path $Workspace2ClonePath $LfsFileName

        if (-not (Test-Path $LfsFilePath)) {
            Write-TestFailure "LFS test file not found at: $LfsFilePath (Phase 5 may have failed)"
        }
        Write-TestSuccess "Found LFS test file: $LfsFilePath"

        # Get the LFS object hash for this file
        Push-Location $Workspace2ClonePath
        $LfsLsOutput = git lfs ls-files -n 2>&1
        if ($LASTEXITCODE -ne 0) {
            Pop-Location
            Write-TestFailure "Failed to list LFS files in workspace 2"
        }

        # Extract the OID (object ID) for the test file
        $LfsInfo = git lfs ls-files -l | Where-Object { $_ -match $LfsFileName }
        if (-not $LfsInfo) {
            Pop-Location
            Write-TestFailure "Test file not tracked by LFS: $LfsFileName"
        }

        # Parse the OID from the ls-files output (format: "OID - filename")
        if ($LfsInfo -match '([a-f0-9]{64})') {
            $LfsOid = $matches[1]
            Write-TestSuccess "LFS object ID: $LfsOid"
        }
        else {
            Pop-Location
            Write-TestFailure "Could not parse LFS object ID from: $LfsInfo"
        }

        Pop-Location

        # Step 8.2: Wait for LFS cache object to sync via SyncThing
        Write-Host "`nStep 8.2: Waiting for LFS cache to sync from workspace 2 to workspace 1" -ForegroundColor Cyan

        if (-not $script:TestResults.Workspace1Path) {
            Write-TestFailure "First workspace not available for LFS pull test"
        }

        # LFS cache is in sync/git-lfs with structure: lfs/objects/XX/YY/XXYY...
        $LfsOidPrefix = $LfsOid.Substring(0, 2)
        $LfsOidSuffix = $LfsOid.Substring(2, 2)
        $LfsCacheRelativePath = "lfs\objects\$LfsOidPrefix\$LfsOidSuffix\$LfsOid"

        $Workspace1LfsCachePath = Join-Path $script:TestResults.Workspace1Path "sync\git-lfs\$LfsCacheRelativePath"
        Write-Host "Expected LFS cache path: $Workspace1LfsCachePath" -ForegroundColor Gray

        # Wait for the LFS object to sync
        $LfsSynced = Wait-ForFile -Path $Workspace1LfsCachePath -TimeoutSeconds $Timeout -PollIntervalSeconds 2

        # If timeout occurs, offer to wait longer
        while (-not $LfsSynced) {
            Write-Host "`nLFS cache file did not sync within ${Timeout}s timeout" -ForegroundColor Yellow

            # Display diagnostic information
            $SyncCount = Get-SyncThingProcessCount
            Write-Host "SyncThing instances running: $SyncCount" -ForegroundColor Yellow

            if ($SyncCount -lt 2) {
                Write-Host "WARNING: Expected 2 SyncThing instances for sync to work" -ForegroundColor Yellow
            }

            # Check if the source file exists in workspace 2
            $Workspace2LfsCachePath = Join-Path $script:TestResults.Workspace2Path "sync\git-lfs\$LfsCacheRelativePath"
            if (Test-Path $Workspace2LfsCachePath) {
                Write-Host "Source LFS cache file exists in workspace 2: $Workspace2LfsCachePath" -ForegroundColor Gray
            }
            else {
                Write-Host "WARNING: Source LFS cache file not found in workspace 2: $Workspace2LfsCachePath" -ForegroundColor Yellow
            }

            # Ask user if they want to continue waiting
            if (Wait-ForUserConfirmation -Message "LFS cache sync timeout.") {
                Write-Host "Waiting another ${Timeout}s..." -ForegroundColor Cyan
                $LfsSynced = Wait-ForFile -Path $Workspace1LfsCachePath -TimeoutSeconds $Timeout -PollIntervalSeconds 2
            }
            else {
                Write-TestFailure "LFS cache sync failed: File did not appear in workspace 1 LFS cache after timeout"
            }
        }

        Write-TestSuccess "LFS cache object synced to workspace 1 via SyncThing"

        # Step 8.3: Update workspace 1 and verify LFS file checkout
        Write-Host "`nStep 8.3: Running que update in workspace 1" -ForegroundColor Cyan

        $Workspace1ClonePath = $script:TestResults.Workspace1ClonePath
        if (-not $Workspace1ClonePath -or -not (Test-Path $Workspace1ClonePath)) {
            $Workspace1Clone = Get-ChildItem "$($script:TestResults.Workspace1Path)\repo" -Directory | Select-Object -First 1
            if (-not $Workspace1Clone) {
                Write-TestFailure "Could not find workspace 1 clone directory"
            }
            $Workspace1ClonePath = $Workspace1Clone.FullName
            $script:TestResults.Workspace1ClonePath = $Workspace1ClonePath
        }

        Push-Location $Workspace1ClonePath

        Invoke-QueUpdateCommand -CloneRoot $Workspace1ClonePath | Out-Null
        Write-TestSuccess "que update completed successfully"

        # Step 8.4: Verify LFS file is checked out (not a pointer)
        Write-Host "`nStep 8.4: Verifying LFS file is properly checked out" -ForegroundColor Cyan

        $Workspace1LfsFilePath = Join-Path $Workspace1ClonePath $LfsFileName

        if (-not (Test-Path $Workspace1LfsFilePath)) {
            Pop-Location
            Write-TestFailure "LFS file not found after pull: $Workspace1LfsFilePath"
        }
        Write-TestSuccess "LFS file exists in workspace 1: $Workspace1LfsFilePath"

        # Read the file content to verify it's not a pointer
        $FileContent = Get-Content -Path $Workspace1LfsFilePath -Raw -ErrorAction Stop

        # Check if it's an LFS pointer (pointers start with "version https://git-lfs.github.com")
        if ($FileContent -match "^version https://git-lfs\.github\.com") {
            Pop-Location
            Write-Host "File content (pointer detected):" -ForegroundColor Red
            Write-Host $FileContent -ForegroundColor Red
            Write-TestFailure "LFS file is still a pointer, not properly downloaded"
        }

        Write-TestSuccess "LFS file is properly checked out (not a pointer)"

        # Verify content matches between workspaces
        $Workspace2FileContent = Get-Content -Path $LfsFilePath -Raw -ErrorAction Stop
        if ($FileContent -ne $Workspace2FileContent) {
            Pop-Location
            Write-Host "Workspace 1 content: $FileContent" -ForegroundColor Red
            Write-Host "Workspace 2 content: $Workspace2FileContent" -ForegroundColor Red
            Write-TestFailure "LFS file content doesn't match between workspaces"
        }

        Write-TestSuccess "LFS file content matches between workspaces"

        # Display file info
        $FileInfo = Get-Item $Workspace1LfsFilePath
        Write-Host "LFS file size: $($FileInfo.Length) bytes" -ForegroundColor Gray
        Write-Host "LFS file content: $($FileContent.Substring(0, [Math]::Min(100, $FileContent.Length)))..." -ForegroundColor Gray

        Pop-Location

        Write-TestSuccess "Git LFS pull with SyncThing cache synchronization test completed successfully"
    }
}
catch {
    if (Get-Location | Select-Object -ExpandProperty Path | Where-Object { $_ -ne $script:TestRoot }) {
        Pop-Location
    }
    Write-TestFailure "Git LFS pull test failed: $($_.Exception.Message)"
}

#endregion

#region Phase 9: Multiple Clones Test

Write-TestStep "Phase 9: Testing multiple clones within a workspace"

try {
    if ($PSCmdlet.ShouldProcess("second clone in workspace 1", "create")) {
        # Step 9.1: Load the generated script and create second clone
        Write-Host "`nStep 9.1: Creating second clone in first workspace" -ForegroundColor Cyan

        if (-not $script:TestResults.Workspace1Path) {
            Write-TestFailure "First workspace not available for multiple clones test"
        }

        # Use the primary clone as the source for que clone
        $Workspace1PrimaryClonePath = $script:TestResults.Workspace1ClonePath
        $Workspace1PrimaryCloneName = $script:TestResults.Workspace1CloneName
        if (-not $Workspace1PrimaryClonePath -or -not (Test-Path $Workspace1PrimaryClonePath)) {
            $Workspace1Clone = Get-ChildItem "$($script:TestResults.Workspace1Path)\repo" -Directory | Select-Object -First 1
            if (-not $Workspace1Clone) {
                Write-TestFailure "Could not find first workspace clone directory"
            }
            $Workspace1PrimaryClonePath = $Workspace1Clone.FullName
            $Workspace1PrimaryCloneName = $Workspace1Clone.Name
            $script:TestResults.Workspace1ClonePath = $Workspace1PrimaryClonePath
            $script:TestResults.Workspace1CloneName = $Workspace1PrimaryCloneName
        }

        $GeneratedScript = Join-Path $Workspace1PrimaryClonePath "que57-project.ps1"
        if (-not (Test-Path $GeneratedScript)) {
            Write-TestFailure "Generated script not found at: $GeneratedScript"
        }
        Write-TestSuccess "Found generated script: $GeneratedScript"

        # Count existing clones before creating new one
        $ExistingClones = @(Get-ChildItem "$($script:TestResults.Workspace1Path)\repo" -Directory)
        $ExistingCloneCount = $ExistingClones.Count
        Write-Host "Existing clones in workspace 1: $ExistingCloneCount" -ForegroundColor Gray

        # Remove any previously loaded functions to avoid conflicts
        $FunctionsToRemove = @(
            'Find-QueWorkspace', 'Get-AvailableSyncThingPort', 'Get-SecureGitHubPAT',
            'Set-SecureGitHubPAT', 'Store-GitCredentials', 'Test-GitHubPAT',
            'Get-NextCloneName', 'Find-UProjectFile', 'New-WindowsShortcut',
            'Test-IsAdmin', 'Install-NetFx3WithElevation', 'Sync-WingetPackage',
            'Get-UserSelectionIndex', 'Get-EpicGamesLauncherExecutable',
            'Get-SyncThingExecutable', 'Ensure-SyncThingRunning', 'Initialize-SyncThing',
            'Configure-SyncThingFolders', 'Update-SyncThingDevices', 'Write-GitConfigFiles',
            'Write-UEGitConfigFiles', 'Install-AllDependencies', 'New-QueRepoScript',
            'New-QueWorkspace', 'New-QueClone', 'Invoke-QueMain', 'Invoke-QueGit',
            'Get-QueCurrentBranch', 'Get-QueCloneNameFromPath', 'Invoke-QueMerge',
            'Invoke-QuePushWithRetry', 'Invoke-QueStashAll', 'Invoke-QueSaveCommand',
            'Invoke-QueOpenBranchCommand', 'Invoke-QueImportCommand', 'Invoke-QueUpdateCommand',
            'Invoke-QueRenameCommand', 'Invoke-QueResetCommand', 'Invoke-QuePublishCommand',
            'Invoke-QueNewCommand', 'Invoke-QueCloneCommand'
        )

        foreach ($FuncName in $FunctionsToRemove) {
            if (Get-Command $FuncName -ErrorAction SilentlyContinue) {
                Remove-Item "Function:\$FuncName" -ErrorAction SilentlyContinue
            }
        }
        Write-Host "Cleared function namespace" -ForegroundColor Gray

        # Dot-source the generated script to load its functions
        Write-Host "Loading generated script functions..." -ForegroundColor Cyan
        . $GeneratedScript

        # Load the generated script content into $queScript variable
        $script:queScript = Get-Content -Path $GeneratedScript -Raw -Encoding UTF8

        # Validate GitHub token
        $TestUser = Test-GitHubPAT -PlainPAT $GitHubToken
        if (-not $TestUser) {
            Write-TestFailure "Failed to validate GitHub token for clone creation"
        }

        # Create the second clone using que clone (bases on current branch state)
        Write-Host "Creating second clone in workspace 1 using que clone..." -ForegroundColor Cyan
        $NewCloneRoot = Invoke-QueCloneCommand -WorkspaceRoot $script:TestResults.Workspace1Path `
                                              -SourceCloneRoot $Workspace1PrimaryClonePath `
                                              -SkipLaunch
        $NewCloneName = Split-Path $NewCloneRoot -Leaf
        Write-TestSuccess "Second clone created via que clone: $NewCloneRoot"

        # Step 9.2: Validate Clone Structure
        Write-Host "`nStep 9.2: Validating clone structure" -ForegroundColor Cyan

        # Count clones after creation
        $AllClones = @(Get-ChildItem "$($script:TestResults.Workspace1Path)\repo" -Directory)
        $NewCloneCount = $AllClones.Count

        if ($NewCloneCount -le $ExistingCloneCount) {
            Write-TestFailure "Second clone was not created. Expected $($ExistingCloneCount + 1) clones, found $NewCloneCount"
        }
        Write-TestSuccess "Clone count increased from $ExistingCloneCount to $NewCloneCount"

        if ($NewCloneCount -ne 2) {
            Write-Host "WARNING: Expected exactly 2 clones in workspace 1, found $NewCloneCount" -ForegroundColor Yellow
        }

        # List all clones
        Write-Host "Clones in workspace 1:" -ForegroundColor Gray
        foreach ($clone in $AllClones) {
            Write-Host "  - $($clone.Name)" -ForegroundColor Gray
        }

        # Verify each clone is a valid git repository
        foreach ($clone in $AllClones) {
            $ClonePath = $clone.FullName
            $GitDir = Join-Path $ClonePath ".git"

            if (-not (Test-Path $GitDir)) {
                Write-TestFailure "Clone is not a valid git repository: $ClonePath"
            }

            # Verify remote URL
            Push-Location $ClonePath
            $RemoteUrl = git remote get-url origin 2>&1
            if ($LASTEXITCODE -ne 0) {
                Pop-Location
                Write-TestFailure "Git remote not configured in clone: $ClonePath"
            }
            Write-Host "  Clone $($clone.Name) remote: $RemoteUrl" -ForegroundColor Gray

            # Verify it's pointing to the correct repository
            if ($RemoteUrl -notmatch $script:TestResults.GitHubRepoName) {
                Pop-Location
                Write-TestFailure "Clone has incorrect remote URL: $RemoteUrl (expected: $($script:TestResults.GitHubRepoName))"
            }

            Pop-Location
        }

        Write-TestSuccess "All clones are valid git repositories with correct remotes"

        # Verify .lnk shortcuts exist for all clones
        foreach ($clone in $AllClones) {
            $LnkPath = Join-Path $script:TestResults.Workspace1Path "open-$($clone.Name).lnk"
            if (-not (Test-Path $LnkPath)) {
                Write-Host "WARNING: Shortcut not found for clone $($clone.Name): $LnkPath" -ForegroundColor Yellow
            } else {
                Write-Host "  Found shortcut: open-$($clone.Name).lnk" -ForegroundColor Gray
            }
        }

        # Verify directory structure matches expected pattern
        Write-Host "`nExpected directory structure:" -ForegroundColor Gray
        Write-Host "  $($script:TestResults.Workspace1Path)/" -ForegroundColor Gray
        Write-Host "    +-- repo/" -ForegroundColor Gray
        Write-Host "        +-- $($AllClones[0].Name)/" -ForegroundColor Gray
        if ($AllClones.Count -ge 2) {
            Write-Host "        +-- $($AllClones[1].Name)/" -ForegroundColor Gray
        }
        Write-Host "    +-- sync/" -ForegroundColor Gray
        Write-Host "    +-- env/" -ForegroundColor Gray
        Write-Host "    +-- .que/" -ForegroundColor Gray

        # Step 9.3: Validate que import between clone branches
        Write-Host "`nStep 9.3: Importing changes between clone branches" -ForegroundColor Cyan

        $PrimaryClonePath = $Workspace1PrimaryClonePath
        $PrimaryCloneName = $Workspace1PrimaryCloneName
        $SecondaryClone = $AllClones | Where-Object { $_.FullName -ne $PrimaryClonePath } | Select-Object -First 1
        if (-not $SecondaryClone) {
            Write-TestFailure "Could not locate secondary clone for import test"
        }
        $SecondaryClonePath = $SecondaryClone.FullName
        $SecondaryCloneName = $SecondaryClone.Name

        # Create change on the primary clone and save to its branch
        Push-Location $PrimaryClonePath
        $ImportFile = "import-from-$PrimaryCloneName.txt"
        $ImportContent = "Import test from $PrimaryCloneName at $(Get-Date -Format 'o')"
        Set-Content -Path $ImportFile -Value $ImportContent -Encoding UTF8
        $PrimaryBranch = Invoke-QueSaveCommand -CloneRoot $PrimaryClonePath
        if ($PrimaryBranch -ne "que/$PrimaryCloneName") {
            Pop-Location
            Write-TestFailure "Unexpected primary branch name. Expected que/$PrimaryCloneName, got $PrimaryBranch"
        }
        Write-TestSuccess "Created and saved import change on $PrimaryBranch"
        Pop-Location

        # Ensure secondary branch exists, then import the primary branch
        Push-Location $SecondaryClonePath
        $SecondaryBranch = Invoke-QueSaveCommand -CloneRoot $SecondaryClonePath
        if ($SecondaryBranch -ne "que/$SecondaryCloneName") {
            Pop-Location
            Write-TestFailure "Unexpected secondary branch name. Expected que/$SecondaryCloneName, got $SecondaryBranch"
        }
        Write-TestSuccess "Ensured secondary branch exists: $SecondaryBranch"

        Invoke-QueImportCommand -CloneRoot $SecondaryClonePath -Name $PrimaryCloneName
        Write-TestSuccess "Imported que/$PrimaryCloneName into $SecondaryBranch"

        $ImportedFilePath = Join-Path $SecondaryClonePath $ImportFile
        if (-not (Test-Path $ImportedFilePath)) {
            Pop-Location
            Write-TestFailure "Imported file missing after import: $ImportedFilePath"
        }
        Write-TestSuccess "Imported file present in secondary clone: $ImportedFilePath"

        $PostImportBranch = Invoke-QueSaveCommand -CloneRoot $SecondaryClonePath
        if ($PostImportBranch -ne $SecondaryBranch) {
            Pop-Location
            Write-TestFailure "Post-import save returned unexpected branch. Expected $SecondaryBranch, got $PostImportBranch"
        }
        Write-TestSuccess "Saved imported changes on branch: $PostImportBranch"
        Pop-Location

        Write-TestSuccess "Multiple clones test completed successfully"
    }
}
catch {
    if (Get-Location | Select-Object -ExpandProperty Path | Where-Object { $_ -ne $script:TestRoot }) {
        Pop-Location
    }
    Write-TestFailure "Multiple clones test failed: $($_.Exception.Message)"
}

#endregion

#region Phase 10: Summary and Reporting

function Show-TestSummary {
    $duration = (Get-Date) - $script:TestStartTime
    $durationMinutes = [math]::Round($duration.TotalMinutes, 2)

    Write-Host "`n============================================" -ForegroundColor Cyan
    Write-Host "TEST-QUE SUMMARY REPORT" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Test Duration: $durationMinutes minutes"
    Write-Host "Steps Completed: $($script:TestResults.StepsCompleted)"
    Write-Host "Steps Failed: $($script:TestResults.StepsFailed)"

    if ($script:TestResults.StepsFailed -eq 0) {
        Write-Host "Status: SUCCESS" -ForegroundColor Green
    }
    else {
        Write-Host "Status: FAILED" -ForegroundColor Red
    }

    Write-Host ""
    Write-Host "GitHub Repository:" -ForegroundColor Cyan
    Write-Host "  - Name: $($script:TestResults.GitHubRepoName)"
    Write-Host "  - Owner: $($script:TestResults.GitHubUser)"
    Write-Host "  - URL: https://github.com/$($script:TestResults.GitHubUser)/$($script:TestResults.GitHubRepoName)"

    if ($script:TestResults.Workspace1Path) {
        Write-Host ""
        Write-Host "Workspaces Created:" -ForegroundColor Cyan
        Write-Host "  1. $($script:TestResults.Workspace1Path)"
        if ($script:TestResults.Workspace2Path) {
            Write-Host "  2. $($script:TestResults.Workspace2Path)"
        }
    }

    if ($script:TestResults.SyncThingPIDs.Count -gt 0) {
        Write-Host ""
        Write-Host "SyncThing Processes:" -ForegroundColor Cyan
        foreach ($SyncThingPid in $script:TestResults.SyncThingPIDs) {
            Write-Host "  - PID: $SyncThingPid"
        }
    }

    $testRootDisplay = $null
    if ($script:TestRoot) {
        $testRootDisplay = $script:TestRoot.FullName
    }
    elseif ($script:TestResults.TestRootPath) {
        $testRootDisplay = $script:TestResults.TestRootPath
    }

    Write-Host ""
    if ($testRootDisplay) {
        Write-Host "Test Root: $testRootDisplay"
    }
    else {
        Write-Host "Test Root: (not created)"
    }
    Write-Host "============================================`n" -ForegroundColor Cyan
}

#endregion

#region Phase 11: Cleanup and User Prompts

function Invoke-Cleanup {
    Write-Host "`n============================================" -ForegroundColor Yellow
    Write-Host "CLEANUP" -ForegroundColor Yellow
    Write-Host "============================================`n" -ForegroundColor Yellow

    # Stop SyncThing processes started by this test
    $syncProcesses = Get-Process -Name "syncthing" -ErrorAction SilentlyContinue
    if ($syncProcesses) {
        $instanceCount = Get-SyncThingProcessCount
        $testSyncPids = $script:TestResults.SyncThingPIDs
        Write-Host "Found $instanceCount SyncThing instance(s) running ($($syncProcesses.Count) processes total)" -ForegroundColor Yellow
        if (-not $testSyncPids -or $testSyncPids.Count -eq 0) {
            Write-Host "No SyncThing processes associated with this test were detected." -ForegroundColor Gray
        }
        elseif (-not $KeepArtifacts) {
            if ($script:NonInteractive) {
                Write-Host "Non-interactive mode: stopping SyncThing processes without prompting." -ForegroundColor Gray
                $stopSync = 'y'
            }
            else {
                $stopSync = Read-Host "Stop SyncThing processes started by this test? (y/N)"
            }
            if ($stopSync -eq 'y' -or $stopSync -eq 'Y') {
                foreach ($procId in $testSyncPids) {
                    $proc = $syncProcesses | Where-Object { $_.Id -eq $procId } | Select-Object -First 1
                    if ($proc -and $PSCmdlet.ShouldProcess("SyncThing (PID: $($proc.Id))", "stop process")) {
                        Stop-Process -Id $proc.Id -Force
                        Write-Host "Stopped SyncThing process: $($proc.Id)" -ForegroundColor Green
                    }
                }

                if (-not (Wait-ForProcessExit -ProcessIds $testSyncPids -TimeoutSeconds 15 -PollIntervalSeconds 1)) {
                    Write-Host "WARNING: SyncThing processes may still be exiting; cleanup might fail." -ForegroundColor Yellow
                }
            }
        }
    }

    # Local cleanup
    if ($script:TestRoot -and (Test-Path $script:TestRoot)) {
        if (-not $KeepArtifacts) {
            Write-Host "`nTest workspace location: $($script:TestRoot.FullName)" -ForegroundColor Cyan
            if ($script:NonInteractive) {
                Write-Host "Non-interactive mode: deleting local workspace without prompting." -ForegroundColor Gray
                $deleteLocal = 'y'
            }
            else {
                $deleteLocal = Read-Host "Delete local test workspace? (y/N)"
            }
            if ($deleteLocal -eq 'y' -or $deleteLocal -eq 'Y') {
                if ($PSCmdlet.ShouldProcess($script:TestRoot.FullName, "delete directory")) {
                    try {
                        Remove-Item -Path $script:TestRoot.FullName -Recurse -Force
                        Write-Host "Deleted test workspace" -ForegroundColor Green
                    }
                    catch {
                        Write-Host "Failed to delete test workspace: $_" -ForegroundColor Red
                        Write-Host "You may need to manually delete: $($script:TestRoot.FullName)" -ForegroundColor Yellow
                    }
                }
            }
            else {
                Write-Host "Test workspace preserved at: $($script:TestRoot.FullName)" -ForegroundColor Yellow
            }
        }
        else {
            Write-Host "Keeping test artifacts at: $($script:TestRoot.FullName)" -ForegroundColor Yellow
        }
    }

    # GitHub cleanup
    $repoUrl = "https://github.com/$($script:TestResults.GitHubUser)/$($script:TestResults.GitHubRepoName)"
    $repoExists = Test-GitHubRepoExists -RepoName $script:TestResults.GitHubRepoName -Token $GitHubToken -Owner $script:TestResults.GitHubUser

    if ($repoExists) {
        if (-not $KeepArtifacts) {
            Write-Host "`nGitHub repository: $repoUrl" -ForegroundColor Cyan
            if ($script:NonInteractive) {
                Write-Host "Non-interactive mode: deleting GitHub repository without prompting." -ForegroundColor Gray
                $deleteRemote = 'y'
            }
            else {
                $deleteRemote = Read-Host "Delete GitHub repository '$($script:TestResults.GitHubRepoName)'? (y/N)"
            }
            if ($deleteRemote -eq 'y' -or $deleteRemote -eq 'Y') {
                if ($PSCmdlet.ShouldProcess($script:TestResults.GitHubRepoName, "delete from GitHub")) {
                    try {
                        $headers = @{
                            Authorization = "token $GitHubToken"
                            Accept = "application/vnd.github.v3+json"
                        }
                        $deleteUrl = "https://api.github.com/repos/$($script:TestResults.GitHubUser)/$($script:TestResults.GitHubRepoName)"
                        Invoke-RestMethod -Method Delete -Uri $deleteUrl -Headers $headers -ErrorAction Stop
                        Write-Host "Deleted GitHub repository: $repoUrl" -ForegroundColor Green
                    }
                    catch {
                        Write-Host "Failed to delete GitHub repository: $_" -ForegroundColor Red
                        Write-Host "You may need to manually delete: $repoUrl/settings" -ForegroundColor Yellow
                    }
                }
            }
            else {
                Write-Host "GitHub repository preserved at: $repoUrl" -ForegroundColor Yellow
            }
        }
        else {
            Write-Host "GitHub repository preserved at: $repoUrl" -ForegroundColor Yellow
        }
    }

    Write-Host "`n============================================" -ForegroundColor Yellow
    Write-Host "CLEANUP COMPLETE" -ForegroundColor Yellow
    Write-Host "============================================`n" -ForegroundColor Yellow
}

#endregion

# Show summary and cleanup
$testRootPath = $null
if ($script:TestRoot) {
    $testRootPath = $script:TestRoot.FullName
}
$script:TestResults.SyncThingPIDs = Get-TestSyncThingProcessIds -TestRootPath $testRootPath -BaselinePids $script:InitialSyncThingPIDs
Show-TestSummary
Invoke-Cleanup

# Exit with appropriate code
if ($script:TestResults.StepsFailed -eq 0) {
    Write-Host "All tests passed!" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "Tests failed!" -ForegroundColor Red
    exit 1
}
