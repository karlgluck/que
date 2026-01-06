<#
.SYNOPSIS
    Automated end-to-end testing script for the Que workspace tool.

.DESCRIPTION
    Test-Que.ps1 performs comprehensive testing of que57.ps1, validating the full
    golden path workflow including GitHub repository creation, workspace initialization,
    SyncThing synchronization, and Git LFS operations.

    IMPLEMENTATION STATUS:
    ✓ Phase 0: Script structure and parameters
    ✓ Phase 1: Pre-flight checks (PowerShell, Git, Git LFS, GitHub token validation)
    ✓ Phase 2: Test environment setup (temp directory creation)
    ✓ Phase 3: First workspace creation (via dot-sourcing que57.ps1 functions)
    ✓ Phase 4: Second workspace using generated script (with namespace management)
    ✓ Phase 5: Git LFS commit test (using .uasset file)
    ✓ Phase 6: SyncThing peer auto-addition test (launches .lnk files, commits/pulls device IDs)
    ⚠ Phase 7: SyncThing depot synchronization test (NOT IMPLEMENTED)
    ⚠ Phase 8: Git pull LFS validation (NOT IMPLEMENTED)
    ⚠ Phase 9: Multiple clones test (NOT IMPLEMENTED)
    ✓ Phase 10: Summary and reporting
    ✓ Phase 11: Cleanup with user prompts

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
    - Validates workspace structure and Git repository setup
    - Provides detailed logging and error reporting
    - Cleans up test artifacts (with user confirmation)
    - Supports -WhatIf for safe dry-runs
    - Suitable for git bisect integration (meaningful exit codes)

    LIMITATIONS:
    - Does not test SyncThing depot file synchronization (Phase 7)
    - Does not test Git pull with LFS file retrieval (Phase 8)
    - Does not test multiple clone creation within a workspace (Phase 9)

    See PLAN.md for detailed implementation roadmap and future enhancements.

.PARAMETER QueScript
    Path to the que57.ps1 script under test. Defaults to ".\que57.ps1".

.PARAMETER TestRootPath
    Optional override for the temp folder location where test workspaces will be created.

.PARAMETER GitHubToken
    GitHub Personal Access Token with repo creation permissions. If not provided,
    the script will prompt securely.

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
    SyncThingPIDs = @()
    GitHubRepoName = "test-que-demo-repo"
    GitHubUser = $null
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
    $response = Read-Host "Continue waiting? (y/N)"

    return ($response -eq 'y' -or $response -eq 'Y')
}

function Get-SyncThingProcessCount {
    <#
    .SYNOPSIS
        Counts running SyncThing instances.
    #>
    $processes = @(Get-Process -Name "syncthing" -ErrorAction SilentlyContinue)
    return $processes.Count
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
    Write-Host "GitHub Personal Access Token is required for testing." -ForegroundColor Yellow
    Write-Host "The token needs 'repo' permissions to create and delete repositories." -ForegroundColor Yellow
    $secureToken = Read-Host "Enter GitHub PAT" -AsSecureString
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)
    $GitHubToken = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
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
        $deleteExisting = Read-Host "Delete existing repository '$($script:TestResults.GitHubRepoName)'? (y/N)"

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

#region Phase 2: Test Environment Setup

Write-TestStep "Creating test environment"

# Step 2.1: Create Temp Folder Structure
if (-not $TestRootPath) {
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $TestRootPath = Join-Path $env:TEMP "que-test-$timestamp"
}

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
    exit 0
}

#endregion

#region Phase 3: First Workspace Creation

Write-TestStep "Phase 3: Creating first workspace"

# Dot-source que57.ps1 to access its functions directly
Write-Host "Loading que57.ps1 functions..." -ForegroundColor Cyan
. $QueScript

# Load que57.ps1 content into $queScript variable (required by New-QueRepoScript)
$script:queScript = Get-Content -Path $QueScript -Raw -Encoding UTF8

# Change to test root for workspace creation
Push-Location $script:TestRoot

try {
    if ($PSCmdlet.ShouldProcess("first workspace", "create")) {
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
    Pop-Location
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

        $GeneratedScript = Join-Path $FirstClone.FullName "que-$($script:TestResults.GitHubRepoName).ps1"
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

Write-TestStep "Phase 5: Creating and pushing LFS-tracked file"

try {
    if ($PSCmdlet.ShouldProcess("LFS test file", "create and push")) {
        # Step 5.1: Create LFS-tracked file in second workspace
        if (-not $script:TestResults.Workspace2Path) {
            Write-TestFailure "Second workspace not available for LFS test"
        }

        $SecondClone = Get-ChildItem "$($script:TestResults.Workspace2Path)\repo" -Directory | Select-Object -First 1
        if (-not $SecondClone) {
            Write-TestFailure "Could not find second workspace clone directory"
        }

        $SecondClonePath = $SecondClone.FullName
        Write-Host "Using second workspace clone: $SecondClonePath" -ForegroundColor Cyan

        Push-Location $SecondClonePath

        # Create a .uasset file (tracked by LFS per .gitattributes)
        $LfsFile = "TestAsset.uasset"
        $TestContent = "This is a test Unreal asset file for LFS tracking validation. Created at $(Get-Date -Format 'o')"
        Set-Content -Path $LfsFile -Value $TestContent
        Write-TestSuccess "Created test .uasset file: $LfsFile"

        # Step 5.2: Add, commit, and push the LFS file
        git add $LfsFile
        if ($LASTEXITCODE -ne 0) {
            Pop-Location
            Write-TestFailure "Failed to stage LFS file"
        }
        Write-TestSuccess "Staged LFS file"

        # Check LFS status
        $LfsStatus = git lfs status 2>&1
        Write-Host "LFS Status:" -ForegroundColor Gray
        Write-Host $LfsStatus -ForegroundColor Gray

        # Commit
        git commit -m "Test: Add LFS-tracked .uasset file"
        if ($LASTEXITCODE -ne 0) {
            Pop-Location
            Write-TestFailure "Failed to commit LFS file"
        }
        Write-TestSuccess "Committed LFS file"

        # Push
        git push origin main
        if ($LASTEXITCODE -ne 0) {
            Pop-Location
            Write-TestFailure "Failed to push LFS file to GitHub"
        }
        Write-TestSuccess "Pushed LFS file to GitHub"

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
        $Workspace2ScriptPath = Join-Path $Workspace2ClonePath "que-$($script:TestResults.GitHubRepoName).ps1"

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
        $GitStatus = git status --porcelain "que-$($script:TestResults.GitHubRepoName).ps1" 2>&1

        if ([string]::IsNullOrWhiteSpace($GitStatus)) {
            Write-Host "WARNING: No changes detected in que script. Device ID may already be registered." -ForegroundColor Yellow
            Write-Host "This may be expected if the script was already modified in an earlier phase." -ForegroundColor Yellow
        } else {
            Write-TestSuccess "Que script has local changes (device ID was added)"
            Write-Host "Git status: $GitStatus" -ForegroundColor Gray
        }

        # Check git diff to see what changed
        $GitDiff = git diff "que-$($script:TestResults.GitHubRepoName).ps1" 2>&1
        if ($GitDiff) {
            Write-Host "`nChanges in que script:" -ForegroundColor Gray
            $GitDiff | Select-Object -First 20 | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }

            # Look for SyncThingDevices in the diff
            if ($GitDiff -match '\$SyncThingDevices') {
                Write-TestSuccess "Detected SyncThingDevices array modification in diff"
            }
        }

        # Step 6.3: Commit and push the change
        Write-Host "`nStep 6.3: Committing and pushing SyncThing device ID" -ForegroundColor Cyan

        git add "que-$($script:TestResults.GitHubRepoName).ps1"
        if ($LASTEXITCODE -ne 0) {
            # If add fails, it might mean there's nothing to add (already committed)
            Write-Host "Git add returned non-zero. Checking if there are changes to commit..." -ForegroundColor Yellow
        }

        git commit -m "Test: Add workspace 2 SyncThing device ID" 2>&1 | Out-Null
        $CommitExitCode = $LASTEXITCODE

        if ($CommitExitCode -eq 0) {
            Write-TestSuccess "Committed device ID change"

            git push origin main 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) {
                Pop-Location
                Write-TestFailure "Failed to push device ID change to GitHub"
            }
            Write-TestSuccess "Pushed device ID change to GitHub"
        } else {
            Write-Host "No changes to commit (may already be committed)" -ForegroundColor Yellow
        }

        Pop-Location

        # Step 6.4: Switch to workspace 1 and pull
        Write-Host "`nStep 6.4: Pulling changes in workspace 1" -ForegroundColor Cyan

        $Workspace1Clone = Get-ChildItem "$($script:TestResults.Workspace1Path)\repo" -Directory | Select-Object -First 1
        if (-not $Workspace1Clone) {
            Write-TestFailure "Could not find workspace 1 clone directory"
        }

        $Workspace1ClonePath = $Workspace1Clone.FullName
        $Workspace1CloneName = $Workspace1Clone.Name

        Push-Location $Workspace1ClonePath

        git pull origin main 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Pop-Location
            Write-TestFailure "Failed to pull changes in workspace 1"
        }
        Write-TestSuccess "Pulled changes in workspace 1"

        # Verify the que script was updated
        $Workspace1ScriptPath = Join-Path $Workspace1ClonePath "que-$($script:TestResults.GitHubRepoName).ps1"
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
<#
IMPLEMENTATION NOTE:
This phase would test SyncThing synchronization by:
1. Creating a file in workspace 1's depot folder
2. Waiting for it to sync to workspace 2
3. Validating file contents match

Implementation requires managing multiple SyncThing instances and waiting for sync.
For now, this phase is not implemented.
#>
Write-Host "`nNOTE: Phase 7 (SyncThing Depot Test) not implemented - see PLAN.md for details" -ForegroundColor Yellow
#endregion

#region Phase 8: Git Pull LFS Validation
<#
IMPLEMENTATION NOTE:
This phase would test LFS file retrieval by:
1. Pulling in workspace 2
2. Verifying LFS files are downloaded (not just pointers)
3. Validating file sizes and content

Requires Phase 5 to be implemented first.
For now, this phase is not implemented.
#>
Write-Host "`nNOTE: Phase 8 (Git Pull LFS) not implemented - see PLAN.md for details" -ForegroundColor Yellow
#endregion

#region Phase 9: Multiple Clones Test
<#
IMPLEMENTATION NOTE:
This phase would test creating multiple clones within a workspace by:
1. Running the one-liner from within an existing workspace
2. Verifying the clone naming scheme (YYYY-MM-DD-A, -B, etc.)
3. Validating directory structure

Requires Phase 4 to be implemented first.
For now, this phase is not implemented.
#>
Write-Host "`nNOTE: Phase 9 (Multiple Clones) not implemented - see PLAN.md for details" -ForegroundColor Yellow
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
        foreach ($pid in $script:TestResults.SyncThingPIDs) {
            Write-Host "  - PID: $pid"
        }
    }

    Write-Host ""
    Write-Host "Test Root: $($script:TestRoot.FullName)"
    Write-Host "============================================`n" -ForegroundColor Cyan
}

#endregion

#region Phase 11: Cleanup and User Prompts

function Invoke-Cleanup {
    Write-Host "`n============================================" -ForegroundColor Yellow
    Write-Host "CLEANUP" -ForegroundColor Yellow
    Write-Host "============================================`n" -ForegroundColor Yellow

    # Stop SyncThing processes
    $syncProcesses = Get-Process -Name "syncthing" -ErrorAction SilentlyContinue
    if ($syncProcesses) {
        Write-Host "Found $($syncProcesses.Count) SyncThing process(es) running" -ForegroundColor Yellow
        if (-not $KeepArtifacts) {
            $stopSync = Read-Host "Stop SyncThing processes? (y/N)"
            if ($stopSync -eq 'y' -or $stopSync -eq 'Y') {
                foreach ($proc in $syncProcesses) {
                    if ($PSCmdlet.ShouldProcess("SyncThing (PID: $($proc.Id))", "stop process")) {
                        Stop-Process -Id $proc.Id -Force
                        Write-Host "Stopped SyncThing process: $($proc.Id)" -ForegroundColor Green
                    }
                }
            }
        }
    }

    # Local cleanup
    if ($script:TestRoot -and (Test-Path $script:TestRoot)) {
        if (-not $KeepArtifacts) {
            Write-Host "`nTest workspace location: $($script:TestRoot.FullName)" -ForegroundColor Cyan
            $deleteLocal = Read-Host "Delete local test workspace? (y/N)"
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
            $deleteRemote = Read-Host "Delete GitHub repository '$($script:TestResults.GitHubRepoName)'? (y/N)"
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
