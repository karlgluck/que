#Requires -Version 5.1

# Enable TLS 1.2 support for GitHub API
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072

# ============================================================================
# QUE 5.7 - Quick Unreal Engine Project Manager
# ============================================================================
# Repository: https://github.com/karlgluck/que
# Target: Unreal Engine 5.7
# ============================================================================

# ----------------------------------------------------------------------------
# CONSTANTS - Edit these when customizing for your project
# ----------------------------------------------------------------------------
###QUE_CONSTANTS_BEGIN###
$UnrealEngineVersion = "5.7"
# (Other constants will be dynamically substituted during que-repo-name.ps1 generation)
###QUE_CONSTANTS_END###

# ----------------------------------------------------------------------------
# EMBEDDED FILES
# ----------------------------------------------------------------------------
###QUE_EMBEDDED_FILES_BEGIN###
# Repository .gitattributes
$EmbeddedGitAttributes = @'
# Git LFS tracking
*.uasset filter=lfs diff=lfs merge=lfs -text
*.umap filter=lfs diff=lfs merge=lfs -text
*.upk filter=lfs diff=lfs merge=lfs -text
*.udk filter=lfs diff=lfs merge=lfs -text

# Binary files
*.dll filter=lfs diff=lfs merge=lfs -text
*.exe filter=lfs diff=lfs merge=lfs -text
*.pdb filter=lfs diff=lfs merge=lfs -text
*.so filter=lfs diff=lfs merge=lfs -text
*.dylib filter=lfs diff=lfs merge=lfs -text

# Media files
*.png filter=lfs diff=lfs merge=lfs -text
*.jpg filter=lfs diff=lfs merge=lfs -text
*.jpeg filter=lfs diff=lfs merge=lfs -text
*.tga filter=lfs diff=lfs merge=lfs -text
*.bmp filter=lfs diff=lfs merge=lfs -text
*.wav filter=lfs diff=lfs merge=lfs -text
*.mp3 filter=lfs diff=lfs merge=lfs -text
*.ogg filter=lfs diff=lfs merge=lfs -text
*.mp4 filter=lfs diff=lfs merge=lfs -text
*.avi filter=lfs diff=lfs merge=lfs -text
*.mov filter=lfs diff=lfs merge=lfs -text

# 3D models
*.fbx filter=lfs diff=lfs merge=lfs -text
*.obj filter=lfs diff=lfs merge=lfs -text
*.blend filter=lfs diff=lfs merge=lfs -text
*.3ds filter=lfs diff=lfs merge=lfs -text
'@

# Repository .gitignore
$EmbeddedGitIgnore = @'
# QUE environment (contains encrypted PAT)
env/

# Visual Studio
.vs/
*.suo
*.user
*.userosscache
*.sln.docstates
*.userprefs
*.sln.ide/

# VS Code
.vscode/
*.code-workspace

# Windows
Thumbs.db
ehthumbs.db
Desktop.ini
$RECYCLE.BIN/

# macOS
.DS_Store
.AppleDouble
.LSOverride

# Build results
[Dd]ebug/
[Rr]elease/
x64/
x86/
[Bb]in/
[Oo]bj/
'@

# UE Project .gitattributes
$EmbeddedUEGitAttributes = @'
# Unreal Engine asset files
*.uasset filter=lfs diff=lfs merge=lfs -text
*.umap filter=lfs diff=lfs merge=lfs -text
*.upk filter=lfs diff=lfs merge=lfs -text
*.udk filter=lfs diff=lfs merge=lfs -text
*.ubulk filter=lfs diff=lfs merge=lfs -text
*.uexp filter=lfs diff=lfs merge=lfs -text
*.ufont filter=lfs diff=lfs merge=lfs -text
*.uassetc filter=lfs diff=lfs merge=lfs -text
*.umaterialc filter=lfs diff=lfs merge=lfs -text
'@

# UE Project .gitignore
$EmbeddedUEGitIgnore = @'
# Unreal Engine generated files
Binaries/
Build/
DerivedDataCache/
Intermediate/
Saved/
Script/
.vs/

# Unreal Editor specific
*.VC.db
*.opensdf
*.opendb
*.sdf
*.sln
*.suo
*.xcodeproj
*.xcworkspace

# Compiled source
*.com
*.class
*.dll
*.exe
*.o
*.so

# Plugins
Plugins/*/Binaries/
Plugins/*/Intermediate/

# Cache files
*.VC.VC.opendb
*.VC.db

# Starter Content (uncomment if you don't want it tracked)
# Content/StarterContent/
'@

# README.md template for generated repos
$EmbeddedReadme = @'
# {{REPO}} - Unreal Engine 5.7 Project

This project is managed using QUE (Quick Unreal Engine).

## Joining This Project

To set up your development environment and join this project:

1. Create an empty directory for your workspace
2. Get your GitHub Personal Access Token (see below)
3. Run this command in PowerShell:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ($queScript = (iwr -UseBasicParsing -Headers @{Authorization = "token $($quePlainPAT = Read-Host 'Enter Personal Access Token';$quePlainPAT)"} -Uri ($queUrl = "https://raw.githubusercontent.com/{{OWNER}}/{{REPO}}/main/que-{{REPO}}.ps1")).Content)
```

3. Follow the prompts to:
   - Enter your GitHub Personal Access Token
   - Install dependencies (Git, GitLFS, SyncThing, Visual Studio Build Tools)
   - Install Unreal Engine 5.7 via Epic Games Launcher
   - Clone the repository

4. Launch the environment using the generated shortcut

## Prerequisites

- Windows 10/11
- PowerShell 5.1 or later
- GitHub Personal Access Token with `repo` and `read:org` permissions

## Getting a GitHub PAT

1. Go to https://github.com/settings/tokens
2. Click "Generate new token (classic)"
3. Select scopes: `repo` (all), `read:org`
4. Generate and copy the token

## Management Commands

Once your workspace is set up, launch the management terminal using `que-{{REPO}}.ps1`:

- **open** - Generate project files, build, and launch UE editor
- **build** - Build the editor target
- **clean** - Delete intermediate files for full rebuild
- **package** - Create standalone builds
- **info** - Display workspace information

## Project Structure

```
workspace-root/
+-- .que/                    # Workspace metadata
+-- sync/                    # SyncThing-managed folders
|   +-- git-lfs/lfs/         # Shared LFS storage
|   +-- depot/               # Shared asset depot
+-- env/                     # Environment data (PAT, SyncThing)
+-- repo/                    # Repository clones
    +-- YYYY-MM-DD-A/        # Clone directory
        +-- que-{{REPO}}.ps1 # Project management script
```

## About QUE

QUE is a single-file PowerShell solution for managing Unreal Engine projects with Git, GitLFS, and SyncThing integration. Learn more at https://github.com/karlgluck/que
'@
###QUE_EMBEDDED_FILES_END###

# ----------------------------------------------------------------------------
# SYNCTHING DEVICES (only in que-repo-name.ps1)
# ----------------------------------------------------------------------------
###QUE_SYNCTHING_BEGIN###
# $SyncThingDevices = @()  # Embedded in que-repo-name.ps1 only (array of device IDs)
###QUE_SYNCTHING_END###

# ----------------------------------------------------------------------------
# HELPER FUNCTIONS
# ----------------------------------------------------------------------------

# Core Utility Functions

function Find-QueWorkspace {
    <#
    .SYNOPSIS
        Searches current and parent directories for .que folder
    .DESCRIPTION
        Returns workspace root path or $null if not found
        Validates by checking for required files (gh-repo-name, gh-repo-owner)
    #>
    $CurrentPath = Get-Location
    $Path = $CurrentPath

    while ($Path) {
        $QuePath = Join-Path $Path ".que"
        if (Test-Path $QuePath) {
            # Validate workspace by checking for required files
            $OwnerFile = Join-Path $QuePath "gh-repo-owner"
            $RepoFile = Join-Path $QuePath "gh-repo-name"

            if ((Test-Path $OwnerFile) -and (Test-Path $RepoFile)) {
                return $Path
            }
        }

        # Move to parent directory
        $Parent = Split-Path $Path -Parent
        if ($Parent -eq $Path) {
            break  # Reached root
        }
        $Path = $Parent
    }

    return $null
}

function Get-AvailableSyncThingPort {
    <#
    .SYNOPSIS
        Finds an available port for SyncThing GUI
    .DESCRIPTION
        Initially selects a random port in range 8384-8484 to reduce collision likelihood
        Checks if port is available, tries next ports if in use
        Returns first available port
    #>
    $MinPort = 8384
    $MaxPort = 8484
    $StartPort = Get-Random -Minimum $MinPort -Maximum $MaxPort

    for ($i = 0; $i -lt ($MaxPort - $MinPort); $i++) {
        $Port = (($StartPort + $i - $MinPort) % ($MaxPort - $MinPort)) + $MinPort
        $InUse = [bool](Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue)
        if (-not $InUse) {
            return $Port
        }
    }
    throw "No available ports in range $MinPort-$MaxPort"
}

function Get-SecureGitHubPAT {
    <#
    .SYNOPSIS
        Reads and decrypts GitHub Personal Access Token
    .DESCRIPTION
        Reads PAT from env/github/pat.dat
        Decrypts SecureString
        Returns plain text PAT or $null if missing/invalid
    #>
    param(
        [string]$WorkspaceRoot
    )

    $PatFile = Join-Path $WorkspaceRoot "env\github\pat.dat"

    if (-not (Test-Path $PatFile)) {
        return $null
    }

    try {
        $SecureString = Get-Content $PatFile | ConvertTo-SecureString
        # Because we are targeting the version that comes pre-installed on Windows 10/11,
        # this verbose approach is preferred to the feature that
        # requires PowerShell 7: "ConvertFrom-SecureString $SecureString -AsPlainText"
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
        $PlainPAT = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
        return $PlainPAT
    } catch {
        Write-Warning "Failed to decrypt PAT: $($_.Exception.Message)"
        return $null
    }
}

function Set-SecureGitHubPAT {
    <#
    .SYNOPSIS
        Encrypts and stores GitHub Personal Access Token
    .DESCRIPTION
        Encrypts PAT as SecureString
        Writes to env/github/pat.dat
        Creates directory if needed
    #>
    param(
        [string]$PlainPAT,
        [string]$WorkspaceRoot
    )

    $EnvDir = Join-Path $WorkspaceRoot "env\github"
    if (-not (Test-Path $EnvDir)) {
        New-Item -ItemType Directory -Force -Path $EnvDir | Out-Null
    }

    $PatFile = Join-Path $WorkspaceRoot "env\github\pat.dat"
    $SecureString = ConvertTo-SecureString $PlainPAT -AsPlainText -Force
    $SecureString | ConvertFrom-SecureString | Set-Content $PatFile
}

function Store-GitCredentials {
    <#
    .SYNOPSIS
        Stores Git credentials in Windows Credential Manager
    .DESCRIPTION
        Sets GCM_INTERACTIVE to prevent prompts
        Pipes credential block to git credential-manager store
        Called before git clone/push operations
    #>
    param(
        [string]$Login,
        [string]$PlainPAT
    )

    # Prevent interactive prompts
    $env:GCM_INTERACTIVE = "never"

    # Store credential in Git Credential Manager
    @"
protocol=https
host=github.com
username=$Login
password=$PlainPAT
"@  | git credential-manager store
}

function Test-GitHubPAT {
    <#
    .SYNOPSIS
        Tests GitHub Personal Access Token validity
    .DESCRIPTION
        Tests PAT by calling GitHub API /user
        Returns user info object or $null if invalid
        Response includes: login, name, id, email
    .NOTES
        IMPORTANT: The email field from API should NOT be used for git config
        Git email must be generated from id and login fields instead
    #>
    param([string]$PlainPAT)

    try {
        $AuthHeaders = @{
            Authorization = "token $PlainPAT"
            'Cache-Control' = 'no-store'
        }
        $Response = Invoke-WebRequest -Uri 'https://api.github.com/user' -Headers $AuthHeaders -UseBasicParsing -ErrorAction Stop
        if ($Response.StatusCode -eq 200) {
            return ($Response.Content | ConvertFrom-Json)
        }
    } catch {
        return $null
    }
    return $null
}

function Get-NextCloneName {
    <#
    .SYNOPSIS
        Generates next clone directory name
    .DESCRIPTION
        Reads existing clone directories
        Generates next name: YYYY-MM-DD-A, -B, ..., -Z, -Z1, -Z2, ...
        Handles edge cases (1000+ clones in one day)
    #>
    param([string]$WorkspaceRoot)

    $Today = Get-Date -Format "yyyy-MM-dd"
    $RepoDir = Join-Path $WorkspaceRoot "repo"

    if (-not (Test-Path $RepoDir)) {
        return "$Today-A"
    }

    $ExistingClones = Get-ChildItem $RepoDir -Directory |
        Where-Object { $_.Name -match "^$Today-(.+)$" } |
        ForEach-Object { $matches[1] } |
        Sort-Object

    if (-not $ExistingClones) {
        return "$Today-A"
    }

    $LastSuffix = $ExistingClones[-1]

    # Handle A-Z
    if ($LastSuffix -match '^[A-Y]$') {
        return "$Today-$([char]([int][char]$LastSuffix + 1))"
    }

    # Handle Z -> Z1
    if ($LastSuffix -eq 'Z') {
        return "$Today-Z1"
    }

    # Handle Z1, Z2, ... Z999, Z1000, ...
    if ($LastSuffix -match '^Z(\d+)$') {
        $Number = [int]$matches[1] + 1
        return "$Today-Z$Number"
    }

    throw "Unable to generate next clone name from: $LastSuffix"
}

function Find-UProjectFile {
    <#
    .SYNOPSIS
        Finds .uproject file in clone directory
    .DESCRIPTION
        Breadth-first search from clone root
        Finds first .uproject file
        Returns full path or $null
        Excludes Samples/ and Templates/ directories
    .NOTES
        If multiple .uproject files are found, warns user
    #>
    param([string]$CloneRoot)

    # Breadth-first search
    $Queue = @(Get-ChildItem -Path $CloneRoot -Directory -ErrorAction SilentlyContinue)
    $UProjects = @()

    # First check root directory
    $RootProjects = Get-ChildItem -Path $CloneRoot -Filter "*.uproject" -ErrorAction SilentlyContinue
    if ($RootProjects) {
        $UProjects += $RootProjects
    }

    # Then search subdirectories
    while ($Queue.Count -gt 0) {
        $Current = $Queue[0]
        $Queue = $Queue[1..($Queue.Count - 1)]

        # Skip excluded directories
        if ($Current.Name -in @('Samples', 'Templates', 'Binaries', 'Intermediate', 'Saved')) {
            continue
        }

        # Look for .uproject files
        $Projects = Get-ChildItem -Path $Current.FullName -Filter "*.uproject" -ErrorAction SilentlyContinue
        if ($Projects) {
            $UProjects += $Projects
        }

        # Add subdirectories to queue
        $SubDirs = Get-ChildItem -Path $Current.FullName -Directory -ErrorAction SilentlyContinue
        $Queue += $SubDirs
    }

    if ($UProjects.Count -eq 0) {
        return $null
    }

    if ($UProjects.Count -gt 1) {
        $UProjectPath = $UProjects[0].FullName
        $OtherProjects = $UProjects[1..($UProjects.Count - 1)] | ForEach-Object { $_.FullName }
        Write-Warning "Multiple .uproject files found. Using first one: $UProjectPath"
        Write-Warning "Other .uproject files found: $($OtherProjects -join ', ')"
        return $UProjectPath
    }

    return $UProjects[0].FullName
}

function New-WindowsShortcut {
    <#
    .SYNOPSIS
        Creates a Windows .lnk shortcut file
    .DESCRIPTION
        Creates shortcut that launches PowerShell script
    #>
    param(
        [string]$ShortcutPath,
        [string]$TargetScript
    )

    $WshShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($ShortcutPath)
    $Shortcut.TargetPath = "powershell.exe"
    $Shortcut.Arguments = "-ExecutionPolicy Bypass -File `"$TargetScript`""
    $Shortcut.WorkingDirectory = Split-Path $TargetScript -Parent
    $Shortcut.Save()
}

function Test-IsAdmin {
    <#
    .SYNOPSIS
        Checks if current process is running as administrator
    #>
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Install-NetFx3WithElevation {
    <#
    .SYNOPSIS
        Checks and enables .NET Framework 3.5 with automatic elevation
    .DESCRIPTION
        Checks if NetFx3 is enabled. If not, attempts to enable it.
        Automatically elevates if not running as admin.
    #>

    # Check if already enabled (this doesn't require elevation)
    try {
        $netfx3 = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v3.5" -ErrorAction SilentlyContinue

        if ($netfx3.Version) {
            Write-Host ".NET Framework 3.5 (NetFx3) is already enabled." -ForegroundColor Green
            return $true
        }
    } catch {
        # If we can't even check, we definitely need elevation
    }

    Write-Host "Enabling .NET Framework 3.5 (NetFx3)..." -ForegroundColor Yellow

    # Check if running as admin
    if (-not (Test-IsAdmin)) {
        Write-Host "NetFx3 installation requires administrator privileges. Launching elevated process..." -ForegroundColor Yellow

        # Create a script to run elevated
        $ElevatedScript = {
            try {
                Enable-WindowsOptionalFeature -Online -FeatureName 'NetFx3' -All -NoRestart -ErrorAction Stop | Out-Null
                Write-Host ".NET Framework 3.5 enabled successfully" -ForegroundColor Green
                Sleep 5
                exit 0
            } catch {
                Write-Error "Failed to enable NetFx3: $($_.Exception.Message)"
                Read-Host "Press Enter to close this window"
                exit 1
            }
        }

        # Convert scriptblock to base64 to pass to elevated process
        $EncodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($ElevatedScript.ToString()))

        # Start elevated PowerShell process
        $Process = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile", "-EncodedCommand", $EncodedCommand -Verb RunAs -Wait -PassThru

        if ($Process.ExitCode -eq 0) {
            Write-Host ".NET Framework 3.5 enabled successfully" -ForegroundColor Green
            return $true
        } else {
            Write-Warning "Failed to enable NetFx3. You may need to enable it manually."
            return $false
        }
    } else {
        # Already admin, just run it
        try {
            Enable-WindowsOptionalFeature -Online -FeatureName 'NetFx3' -All -NoRestart -ErrorAction Stop | Out-Null
            Write-Host ".NET Framework 3.5 enabled successfully" -ForegroundColor Green
            return $true
        } catch {
            Write-Warning "Failed to enable NetFx3: $($_.Exception.Message)"
            return $false
        }
    }
}

function Sync-WingetPackage {
    <#
    .SYNOPSIS
        Installs or updates a package using winget
    .DESCRIPTION
        Ensures a package is installed via winget
        Implements retry logic (3 attempts)
        Silent installation with fallback to interactive
        Updates PATH after installation
    #>
    param(
        [string]$PackageName,
        [string]$PackageParameters = ''
    )

    Write-Host "Ensuring $PackageName is installed..." -ForegroundColor Cyan

    # Check if already installed
    $ListOutput = & winget list --id $PackageName --exact 2>&1
    if ($LASTEXITCODE -eq 0 -and $ListOutput -match $PackageName) {
        Write-Host "$PackageName is already installed" -ForegroundColor Green
        return
    }

    # Install package
    $MaxAttempts = 3
    for ($Attempt = 1; $Attempt -le $MaxAttempts; $Attempt++) {
        Write-Host "Installing $PackageName (attempt $Attempt of $MaxAttempts)..." -ForegroundColor Yellow

        $InstallArgs = @('install', '--id', $PackageName, '--exact', '--accept-source-agreements', '--accept-package-agreements')

        # Silent mode for first 2 attempts, interactive on 3rd
        if ($Attempt -lt $MaxAttempts) {
            $InstallArgs += '--silent'
        }

        # Add custom parameters if provided
        if ($PackageParameters) {
            $InstallArgs += '--override'
            $InstallArgs += $PackageParameters
        }

        & winget @InstallArgs

        if ($LASTEXITCODE -eq 0) {
            Write-Host "$PackageName installed successfully" -ForegroundColor Green

            # Refresh PATH
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

            return
        }

        # Check for reboot codes
        if ($LASTEXITCODE -in @(350, 1604, 1614, 1641, 3010)) {
            Write-Warning "Installation requires a reboot. Please restart your computer and run this script again."
            return
        }

        if ($Attempt -lt $MaxAttempts) {
            Write-Warning "Installation attempt $Attempt failed. Retrying..."
            Start-Sleep -Seconds 2
        }
    }

    Write-Error "Failed to install $PackageName after $MaxAttempts attempts"
}

function Get-UserSelectionIndex {
    <#
    .SYNOPSIS
        Prompts the user to choose from a list of options
    .DESCRIPTION
        Displays numbered options and prompts for selection
        Returns the index of the selected option (0-based)
        Returns -1 if no valid selection is made
        Supports default selection and auto-selection of single option
    #>
    Param (
        [string[]]$Options,
        [int]$Default,
        [switch]$DontShortcutSingleChoice
    )

    if ($Options.Count -eq 0) {
        return -1
    }

    if ($Options.Count -eq 1 -and (-not $DontShortcutSingleChoice)) {
        return 0
    }

    # Display options to the user
    for ($i = 0; $i -lt $Options.Count; $i++) {
        if ($i -eq $Default) { $Star = "*" } else { $Star = "" }
        Write-Host ("{0,5}: {1}" -f @(("{0}{1}" -f @($Star, ($i + 1))), $Options[$i]))
    }

    # Prompt for input
    $Selection = Read-Host "Select an option [$($Default+1)]"

    # Handle selection
    if ($Selection -eq "") {
        return $Default
    } elseif ($Selection -match '^\d+$' -and $Selection -le $Options.Count -and $Selection -gt 0) {
        return ($Selection - 1)
    } else {
        # Try to match full string
        $MatchedIndex = -1
        for ($i = 0; $i -lt $Options.Count; $i++) {
            if ($Options[$i] -eq $Selection) {
                $MatchedIndex = $i
                break
            }
        }
        return $MatchedIndex
    }
}

function Get-EpicGamesLauncherExecutable {

    # Check standard installation paths first
    $StandardPaths = @(
        'C:\Program Files (x86)\Epic Games\Launcher\Portal\Binaries\Win64\EpicGamesLauncher.exe',
        'C:\Program Files (x86)\Epic Games\Launcher\Portal\Binaries\Win32\EpicGamesLauncher.exe',
        'C:\Program Files\Epic Games\Launcher\Portal\Binaries\Win64\EpicGamesLauncher.exe'
    )
    foreach ($Path in $StandardPaths) {
        if (Test-Path $Path) {
            return $Path
        }
    }

    # Check winget package location
    $WingetPackages = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages"
    if (Test-Path $WingetPackages) {
        $EpicDirs = Get-ChildItem -Path $WingetPackages -Filter "EpicGames.EpicGamesLauncher*" -Directory -ErrorAction SilentlyContinue
        foreach ($Dir in $EpicDirs) {
            $ExePath = Get-ChildItem -Path $Dir.FullName -Filter "EpicGamesLauncher.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($ExePath) {
                return $ExePath.FullName
            }
        }
    }

    # Check user's local Programs folder
    $LocalPrograms = "$env:LOCALAPPDATA\Programs\Epic Games"
    if (Test-Path $LocalPrograms) {
        $ExePath = Get-ChildItem -Path $LocalPrograms -Filter "EpicGamesLauncher.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($ExePath) {
            return $ExePath.FullName
        }
    }

    return $null
}

# ----------------------------------------------------------------------------
# SyncThing Helper Functions
# ----------------------------------------------------------------------------

function Get-SyncThingExecutable {
    <#
    .SYNOPSIS
        Locates the Syncthing executable
    .DESCRIPTION
        Tries multiple methods to find syncthing.exe:
        1. Check PATH using where.exe
        2. Check common winget install locations
        3. Check standard program files locations
    #>

    # Try using where.exe first
    $WherePath = & where.exe syncthing 2>$null | Select-Object -First 1
    if ($WherePath -and (Test-Path $WherePath)) {
        return $WherePath
    }

    # Check winget package location
    $WingetPackages = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages"
    if (Test-Path $WingetPackages) {
        $SyncthingDirs = Get-ChildItem -Path $WingetPackages -Filter "Syncthing.Syncthing*" -Directory -ErrorAction SilentlyContinue
        foreach ($Dir in $SyncthingDirs) {
            $ExePath = Get-ChildItem -Path $Dir.FullName -Filter "syncthing.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($ExePath) {
                return $ExePath.FullName
            }
        }
    }

    # Check Program Files
    $ProgramFilesPaths = @(
        "$env:ProgramFiles\Syncthing\syncthing.exe",
        "${env:ProgramFiles(x86)}\Syncthing\syncthing.exe"
    )
    foreach ($Path in $ProgramFilesPaths) {
        if (Test-Path $Path) {
            return $Path
        }
    }

    return $null
}

function Ensure-SyncThingRunning {
    <#
    .SYNOPSIS
        Ensures SyncThing is running, starts it if needed
    .DESCRIPTION
        Uses syncthing cli to check if running. Starts if needed.
        Reads config from SyncThingHome if it exists.
        Returns device ID and GUI address info.
    #>
    param([string]$WorkspaceRoot)

    # Locate syncthing executable
    $SyncThingExe = Get-SyncThingExecutable
    if (-not $SyncThingExe) {
        Write-Error "Syncthing executable not found. Please ensure Syncthing is installed."
        return $null
    }
    Write-Host "Found Syncthing at: $SyncThingExe" -ForegroundColor Gray

    # Get SyncThing home and ensure it exists
    $SyncThingHome = Join-Path $WorkspaceRoot "env\syncthing-home"
    if (-not (Test-Path $SyncThingHome)) {
        New-Item -ItemType Directory -Force -Path $SyncThingHome | Out-Null
    }

    # Get or generate API key and GUI address
    $ConfigPath = Join-Path $SyncThingHome "config.xml"
    $ApiKeyFile = Join-Path $WorkspaceRoot "env\syncthing\api.key"
    $ApiKey = $null
    $GuiAddress = $null
    $IsFirstTime = $false

    # Check if we have a stored API key
    if (Test-Path $ApiKeyFile) {
        # Read existing API key from secure storage
        try {
            $SecureString = Get-Content $ApiKeyFile | ConvertTo-SecureString
            $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
            $ApiKey = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
            [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
            Write-Host "Using existing SyncThing API key" -ForegroundColor Gray
        } catch {
            Write-Warning "Failed to decrypt API key: $($_.Exception.Message)"
            $ApiKey = $null
        }
    }

    # If no valid API key, this is first-time initialization
    if (-not $ApiKey) {
        $IsFirstTime = $true

        # Delete existing config.xml to force clean initialization
        if (Test-Path $ConfigPath) {
            Write-Host "Removing existing SyncThing config for fresh initialization..." -ForegroundColor Yellow
            Remove-Item $ConfigPath -Force
        }

        # Generate new API key
        $ApiKey = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 32 | ForEach-Object {[char]$_})

        # Store API key securely
        $SyncThingEnvDir = Join-Path $WorkspaceRoot "env\syncthing"
        if (-not (Test-Path $SyncThingEnvDir)) {
            New-Item -ItemType Directory -Force -Path $SyncThingEnvDir | Out-Null
        }
        $SecureString = ConvertTo-SecureString $ApiKey -AsPlainText -Force
        $SecureString | ConvertFrom-SecureString | Set-Content $ApiKeyFile
        Write-Host "Generated and stored new SyncThing API key" -ForegroundColor Green
    }

    # Try to read GUI address from existing config, or generate new one
    if ((Test-Path $ConfigPath) -and -not $IsFirstTime) {
        try {
            [xml]$Config = Get-Content $ConfigPath
            $GuiAddress = $Config.configuration.gui.address
            Write-Host "Using existing SyncThing GUI address: $GuiAddress" -ForegroundColor Gray
        } catch {
            Write-Warning "Failed to parse config.xml for GUI address"
        }
    }

    if (-not $GuiAddress) {
        $Port = Get-AvailableSyncThingPort
        $GuiAddress = "127.0.0.1:$Port"
        Write-Host "Generated new SyncThing GUI address: $GuiAddress" -ForegroundColor Gray
    }

    # Check if SyncThing is running using CLI
    $RawAddress = & $SyncThingExe cli --home="$SyncThingHome" --gui-address="$GuiAddress" --gui-apikey="$ApiKey" config gui raw-address get 2>$null

    if ($LASTEXITCODE -ne 0) {
        # Not running - start it
        Write-Host "Starting SyncThing at $GuiAddress..." -ForegroundColor Cyan

        $StartArgs = @(
            "serve"
            "--home=$SyncThingHome"
            "--gui-address=$GuiAddress"
            "--gui-apikey=$ApiKey"
            "--unpaused"
            "--no-upgrade"
        )

        Write-Host "$StartArgs"

        # Start SyncThing
        # Browser will be opened automatically
        $StartProcessArgs = @{
            FilePath = $SyncThingExe
            ArgumentList = $StartArgs
            WindowStyle = 'Hidden'
        }
        Start-Process @StartProcessArgs
        Start-Sleep -Seconds 5

    } else {
        Write-Host "SyncThing already running at $RawAddress" -ForegroundColor Green

        # Open browser to existing instance
        & $SyncThingExe browser --home="$SyncThingHome"
    }

    # Get device ID using CLI
    $DeviceIdList = & $SyncThingExe cli --home="$SyncThingHome" --gui-address="$GuiAddress" --gui-apikey="$ApiKey" config devices list 2>$null
    $DeviceId = $DeviceIdList | Select-Object -First 1

    if (-not $DeviceId) {
        Write-Warning "Could not retrieve device ID"
    }

    $SyncThingInfo = @{
        DeviceId = $DeviceId
        GuiAddress = $GuiAddress
        ApiKey = $ApiKey
    }

    if ($IsFirstTime) {
        Configure-SyncThingFolders -WorkspaceRoot $WorkspaceRoot -SyncThingInfo $SyncThingInfo
    }

    return $SyncThingInfo
}

function Initialize-SyncThing {
    <#
    .SYNOPSIS
        Initializes SyncThing for the workspace
    .DESCRIPTION
        Creates SyncThing home directory, starts SyncThing, configures folders
    #>
    param([string]$WorkspaceRoot)

    # Start SyncThing
    $SyncThingInfo = Ensure-SyncThingRunning -WorkspaceRoot $WorkspaceRoot
    if (-not $SyncThingInfo) {
        throw "Failed to start SyncThing"
    }

    return $SyncThingInfo
}

function Configure-SyncThingFolders {
    <#
    .SYNOPSIS
        Configures SyncThing folders for git-lfs and depot
    .DESCRIPTION
        Adds sync/git-lfs folder with --ignore-delete flag
        Adds sync/depot folder (bidirectional)
    #>
    param(
        [string]$WorkspaceRoot,
        [hashtable]$SyncThingInfo
    )

    # Locate syncthing executable
    $SyncThingExe = Get-SyncThingExecutable
    if (-not $SyncThingExe) {
        Write-Error "Syncthing executable not found"
        return
    }

    $GitHubRepo = Get-Content "$WorkspaceRoot\.que\gh-repo-name"
    $SyncThingHome = Join-Path $WorkspaceRoot "env\syncthing-home"
    $GuiAddress = $SyncThingInfo.GuiAddress
    $ApiKey = $SyncThingInfo.ApiKey

    # Add git-lfs folder with --ignore-delete flag
    # note: we intentionally wrap the "lfs" folder within a shared git-lfs so that the hidden meta-data
    # folder used by syncthing gets created at `git-lfs\.stfolder` so it becomes a sibling instead of a child of `lfs`
    # (sharing the lfs folder directly makes git unhappy, since git wants to believe it is managing the lfs folder)
    $LfsPath = Join-Path $WorkspaceRoot "sync\git-lfs"
    $LfsFolderId = "$GitHubRepo-lfs"
    $LfsLabel = "$GitHubRepo Git LFS"

    Write-Host "Configuring SyncThing folder: $LfsLabel" -ForegroundColor Cyan
    $CliArgs = @(
        "cli"
        "--home=$SyncThingHome"
        "--gui-address=$GuiAddress"
        "--gui-apikey=$ApiKey"
        "config"
        "folders"
        "add"
        "--id=$LfsFolderId"
        "--label=$LfsLabel"
        "--path=$LfsPath"
        "--ignore-delete"
    )
    & $SyncThingExe @CliArgs

    # Add depot folder (bidirectional)
    $DepotPath = Join-Path $WorkspaceRoot "sync\depot"
    $DepotFolderId = "$GitHubRepo-depot"
    $DepotLabel = "$GitHubRepo Depot"

    Write-Host "Configuring SyncThing folder: $DepotLabel" -ForegroundColor Cyan
    $CliArgs = @(
        "cli"
        "--home=$SyncThingHome"
        "--gui-address=$GuiAddress"
        "--gui-apikey=$ApiKey"
        "config"
        "folders"
        "add"
        "--id=$DepotFolderId"
        "--label=$DepotLabel"
        "--path=$DepotPath"
    )
    & $SyncThingExe @CliArgs

    Write-Host "SyncThing folders configured successfully" -ForegroundColor Green
}

function Update-SyncThingDevices {
    <#
    .SYNOPSIS
        Adds known devices to SyncThing configuration and shares folders
    .DESCRIPTION
        Queries existing devices and only adds new ones from $SyncThingDevices array
        Uses syncthing cli to check existing devices before adding
        Automatically shares depot and git-lfs folders with new peers
    #>
    param(
        [string]$WorkspaceRoot,
        [array]$DeviceIds,
        [hashtable]$SyncThingInfo
    )

    if ($DeviceIds.Count -eq 0) {
        Write-Host "No additional devices to configure" -ForegroundColor Yellow
        return
    }

    # Locate syncthing executable
    $SyncThingExe = Get-SyncThingExecutable
    if (-not $SyncThingExe) {
        Write-Error "Syncthing executable not found"
        return
    }

    $GitHubRepo = Get-Content "$WorkspaceRoot\.que\gh-repo-name"
    $SyncThingHome = Join-Path $WorkspaceRoot "env\syncthing-home"
    $GuiAddress = $SyncThingInfo.GuiAddress
    $ApiKey = $SyncThingInfo.ApiKey

    # Construct folder IDs
    $LfsFolderId = "$GitHubRepo-lfs"
    $DepotFolderId = "$GitHubRepo-depot"

    # Get list of all known device IDs already configured
    $AllKnownDeviceIds = & $SyncThingExe cli --home="$SyncThingHome" --gui-address="$GuiAddress" --gui-apikey="$ApiKey" config devices list 2>$null

    # Add any new devices that aren't already configured
    foreach ($DeviceId in $DeviceIds) {
        if ($DeviceId -and $AllKnownDeviceIds -notcontains $DeviceId) {
            Write-Host "Adding SyncThing peer: $DeviceId" -ForegroundColor Green

            # Add the device
            $CliArgs = @(
                "cli"
                "--home=$SyncThingHome"
                "--gui-address=$GuiAddress"
                "--gui-apikey=$ApiKey"
                "config"
                "devices"
                "add"
                "--device-id=$DeviceId"
                "--auto-accept-folders"
            )
            & $SyncThingExe @CliArgs

            # Share git-lfs folder with the new peer
            Write-Host "  Sharing git-lfs folder with peer" -ForegroundColor Cyan
            $CliArgs = @(
                "cli"
                "--home=$SyncThingHome"
                "--gui-address=$GuiAddress"
                "--gui-apikey=$ApiKey"
                "config"
                "folders"
                $LfsFolderId
                "devices"
                "add"
                "--device-id=$DeviceId"
            )
            & $SyncThingExe @CliArgs 2>$null

            # Share depot folder with the new peer
            Write-Host "  Sharing depot folder with peer" -ForegroundColor Cyan
            $CliArgs = @(
                "cli"
                "--home=$SyncThingHome"
                "--gui-address=$GuiAddress"
                "--gui-apikey=$ApiKey"
                "config"
                "folders"
                $DepotFolderId
                "devices"
                "add"
                "--device-id=$DeviceId"
            )
            & $SyncThingExe @CliArgs 2>$null
        } else {
            Write-Host "Device $DeviceId already configured, skipping" -ForegroundColor Gray
        }
    }

    Write-Host "SyncThing devices configured successfully" -ForegroundColor Green
}

# Git Helper Functions

function Write-GitConfigFiles {
    <#
    .SYNOPSIS
        Writes repository-level Git configuration files
    .DESCRIPTION
        Writes .gitattributes and .gitignore to repo root
        Does NOT write UE-specific files (caller handles this based on scenario)
    #>
    param([string]$CloneRoot)

    Set-Content -Path "$CloneRoot\.gitattributes" -Value $EmbeddedGitAttributes
    Set-Content -Path "$CloneRoot\.gitignore" -Value $EmbeddedGitIgnore
}

function Write-UEGitConfigFiles {
    <#
    .SYNOPSIS
        Writes UE-specific Git configuration files
    .DESCRIPTION
        Finds .uproject file via breadth-first search
        If found, checks if UE .gitattributes and .gitignore already exist
        If not, writes UE-specific files alongside .uproject
        Called when cloning existing repo (after clone completes)
        Called at start of Mode 3 (if user just created UE project manually)
    #>
    param([string]$CloneRoot)

    $UProjectPath = Find-UProjectFile -CloneRoot $CloneRoot
    if (-not $UProjectPath) {
        return
    }

    $UProjectDir = Split-Path $UProjectPath -Parent
    $UEGitAttributesPath = Join-Path $UProjectDir ".gitattributes"
    $UEGitIgnorePath = Join-Path $UProjectDir ".gitignore"

    if (-not (Test-Path $UEGitAttributesPath)) {
        Set-Content -Path $UEGitAttributesPath -Value $EmbeddedUEGitAttributes
        Write-Host "Created UE .gitattributes at: $UEGitAttributesPath" -ForegroundColor Green
    }

    if (-not (Test-Path $UEGitIgnorePath)) {
        Set-Content -Path $UEGitIgnorePath -Value $EmbeddedUEGitIgnore
        Write-Host "Created UE .gitignore at: $UEGitIgnorePath" -ForegroundColor Green
    }
}


function Install-AllDependencies {
    <#
    .SYNOPSIS
        Installs all dependencies required for Unreal Engine 5.7 development
    .DESCRIPTION
        Installs Git, Git LFS, SyncThing, Visual Studio Build Tools, and checks for UE 5.7
    #>

    Write-Host "`nInstalling prerequisites for Unreal Engine 5.7..." -ForegroundColor Cyan

    # Install Git first (required for other tools)
    Sync-WingetPackage -PackageName 'Git.Git'
    Sync-WingetPackage -PackageName 'Git.GCM'

    # Install Epic Games Launcher (for UE installation)
    Sync-WingetPackage -PackageName 'EpicGames.EpicGamesLauncher'

    # Install .NET prerequisites
    Sync-WingetPackage -PackageName 'Microsoft.DotNet.Framework.DeveloperPack_4'

    # Handle NetFx3 Windows Feature (requires elevation)
    Install-NetFx3WithElevation | Out-Null

    # Set up LFS before installing GitHub.GitLFS
    & (where.exe git) lfs install | Out-Null

    # Install Git LFS and SyncThing
    Sync-WingetPackage -PackageName 'GitHub.GitLFS'
    Sync-WingetPackage -PackageName 'Syncthing.Syncthing'

    # Install Visual Studio Build Tools with components (param splatting)
    $VSBuildToolsParams = @{
        PackageName = 'Microsoft.VisualStudio.2022.BuildTools'
        PackageParameters = @(
            '--quiet'
            '--wait'
            '--norestart'
            '--nocache'
            '--add Microsoft.VisualStudio.Workload.MSBuildTools'
            '--add Microsoft.VisualStudio.Workload.VCTools;includeRecommended'
            '--add Microsoft.VisualStudio.Workload.ManagedDesktopBuildTools'
            '--add Microsoft.VisualStudio.Component.Windows11SDK.22621'
            '--add Microsoft.VisualStudio.Component.VC.140'
            '--add Microsoft.NetCore.Component.SDK'
            '--add Microsoft.Net.Component.4.6.2.TargetingPack'
            '--add Microsoft.Net.ComponentGroup.4.6.2-4.7.1.DeveloperTools'
            '--add Microsoft.VisualStudio.Component.VC.14.38.17.8.x86.x64'
            '--add Microsoft.VisualStudio.Component.Unreal.Workspace'
            '--add Microsoft.VisualStudio.Component.VC.14.38.17.8.ATL'
            '--remove Microsoft.VisualStudio.Component.Windows11SDK.26100'
        ) -join ' '
    }
    Sync-WingetPackage @VSBuildToolsParams

    Write-Host "`nDependencies installed successfully" -ForegroundColor Green

    # Check Unreal Engine (but don't block setup)
    Write-Host "`nChecking Unreal Engine 5.7 installation..." -ForegroundColor Cyan

    $UEInstallPath = $null
    $UERegistryPath = "HKLM:\Software\EpicGames\Unreal Engine\5.7"
    if (Test-Path $UERegistryPath) {
        $UEInstallPath = (Get-ItemProperty -Path $UERegistryPath -Name "InstalledDirectory" -ErrorAction SilentlyContinue).InstalledDirectory
    }

    if ($UEInstallPath -and (Test-Path $UEInstallPath)) {
        Write-Host "Unreal Engine 5.7 is installed at: $UEInstallPath" -ForegroundColor Green
    } else {
        Write-Host "Unreal Engine 5.7 is not installed." -ForegroundColor Yellow
        Write-Host "Please install it using the Epic Games Launcher" -ForegroundColor Yellow

        # Try to launch Epic Games Launcher
        $LauncherPath = Get-EpicGamesLauncherExecutable
        if ($LauncherPath) {
            Write-Host "Launching Epic Games Launcher from: $LauncherPath" -ForegroundColor Gray
            Start-Process $LauncherPath -ArgumentList "-openueversion=5.7"
        } else {
            Write-Warning "Could not locate Epic Games Launcher executable"
            Write-Host "Please open Epic Games Launcher manually and install Unreal Engine 5.7" -ForegroundColor Yellow
        }

        Write-Host "Continuing setup (UE will be required before opening the project)..." -ForegroundColor Yellow
    }
}

function New-QueRepoScript {
    <#
    .SYNOPSIS
        Generates project-specific que-repo-name.ps1 script
    .DESCRIPTION
        Reads source que57.ps1 and performs marker-based substitution to create
        a customized script for managing a specific repository
    #>
    param(
        [string]$CloneRoot,
        [string]$Owner,
        [string]$Repo,
        [string]$SyncThingDeviceId = ""
    )

    $ThreeHashes = '###'
    $OutputPath = "$CloneRoot\que-$Repo.ps1"

    # Start with the source script
    $ScriptContent = $queScript

    # 1. Update constants section
    $ConstantsBlock = @"
$($ThreeHashes)QUE_CONSTANTS_BEGIN$($ThreeHashes)
`$UnrealEngineVersion = "5.7"
`$GitHubOwner = "$Owner"
`$GitHubRepo = "$Repo"
$($ThreeHashes)QUE_CONSTANTS_END$($ThreeHashes)
"@

    $ScriptContent = $ScriptContent -replace ('{0}QUE_CONSTANTS_BEGIN{0}[\s\S]*?{0}QUE_CONSTANTS_END{0}' -f @('###')), $ConstantsBlock

    # 2. Add SyncThing devices section (initially just this device if provided)
    if ($SyncThingDeviceId) {
        $SyncThingBlock = @"
$($ThreeHashes)QUE_SYNCTHING_BEGIN$($ThreeHashes)
`$SyncThingDevices = @(
    "$SyncThingDeviceId"
)
$($ThreeHashes)QUE_SYNCTHING_END$($ThreeHashes)
"@
    } else {
        $SyncThingBlock = @"
$($ThreeHashes)QUE_SYNCTHING_BEGIN$($ThreeHashes)
`$SyncThingDevices = @()
$($ThreeHashes)QUE_SYNCTHING_END$($ThreeHashes)
"@
    }

    $ScriptContent = $ScriptContent -replace ('{0}QUE_SYNCTHING_BEGIN{0}[\s\S]*?{0}QUE_SYNCTHING_END{0}' -f @($ThreeHashes)), $SyncThingBlock

    # 3. Remove workspace creation code and embedded files
    $ScriptContent = $ScriptContent -replace ('{0}QUE_CREATION_MODE_BEGIN{0}[\s\S]*?{0}QUE_CREATION_MODE_END{0}' -f @($ThreeHashes)), ''
    $ScriptContent = $ScriptContent -replace ('{0}QUE_EMBEDDED_FILES_BEGIN{0}[\s\S]*?{0}QUE_EMBEDDED_FILES_END{0}' -f @($ThreeHashes)), ''

    # 4. Uncomment management mode code
    $ScriptContent = $ScriptContent -replace ('<#{0}QUE_MANAGEMENT_MODE_BEGIN{0}' -f @($ThreeHashes)), ''
    $ScriptContent = $ScriptContent -replace ('#>{0}QUE_MANAGEMENT_MODE_END{0}' -f @($ThreeHashes)), ''

    # Write the generated script
    Set-Content -Path $OutputPath -Value $ScriptContent

    Write-Host "Generated: $OutputPath" -ForegroundColor Green
}

# Workspace Creation Functions

function New-QueWorkspace {
    <#
    .SYNOPSIS
        Creates a new QUE workspace
    .DESCRIPTION
        Creates workspace structure, validates GitHub PAT, creates first clone
        Supports multiple initialization modes: blank, from GitHub, from local repo
    #>
    param(
        [string]$GitHubOwner,
        [string]$GitHubRepo,
        [string]$PlainPAT,
        [object]$UserInfo
    )

    $WorkspaceRoot = (Get-Location).Path

    Write-Host "`nCreating QUE workspace for $GitHubOwner/$GitHubRepo..." -ForegroundColor Cyan

    # Step 1: Create workspace structure
    Write-Host "`nCreating workspace structure..."
    New-Item -ItemType Directory -Force -Path ".que" | Out-Null
    New-Item -ItemType Directory -Force -Path ".que/repo" | Out-Null
    New-Item -ItemType Directory -Force -Path "sync/git-lfs/lfs" | Out-Null
    New-Item -ItemType Directory -Force -Path "sync/depot" | Out-Null
    New-Item -ItemType Directory -Force -Path "env/github" | Out-Null
    New-Item -ItemType Directory -Force -Path "env/syncthing-home" | Out-Null
    New-Item -ItemType Directory -Force -Path "repo" | Out-Null

    # Step 2: Write workspace metadata
    Set-Content -Path ".que/gh-repo-owner" -Value $GitHubOwner
    Set-Content -Path ".que/gh-repo-name" -Value $GitHubRepo

    # Step 3: Save encrypted PAT
    Set-SecureGitHubPAT -PlainPAT $PlainPAT -WorkspaceRoot $WorkspaceRoot

    # Step 4: Check if GitHub repo exists
    $RepoExists = $false
    try {
        $AuthHeaders = @{Authorization=@('token ', $PlainPAT) -join ''; 'Cache-Control'='no-store'}
        $RepoUrl = "https://api.github.com/repos/$GitHubOwner/$GitHubRepo"
        $Response = Invoke-WebRequest -UseBasicParsing -Uri $RepoUrl -Headers $AuthHeaders -Method Get -ErrorAction Stop
        $RepoExists = $true
        Write-Host "`nRepository $GitHubOwner/$GitHubRepo already exists on GitHub" -ForegroundColor Green
    } catch {
        if ($_.Exception.Response.StatusCode -eq 404) {
            $RepoExists = $false
            Write-Host "`nRepository $GitHubOwner/$GitHubRepo does not exist on GitHub and will be created"
        } else {
            Write-Error "Failed to check if repository exists: $($_.Exception.Message)"
            return
        }
    }

    # Step 5: Determine initialization mode
    $ShouldClone = $false
    $InitMode = 0  # 0 = blank, 1 = from other GitHub repo, 2 = from local, 3 = as part of existing GitHub repo

    if ($RepoExists) {
        $ShouldClone = $true
        $InitMode = 3  # from GitHub repo that already exists
    } else {
        Write-Host "`nSelect initialization method:" -ForegroundColor Yellow
        $Options = @(
            "Create a blank project",
            "Create from existing GitHub project URL",
            "Create from existing local repository"
        )
        $InitMode = Get-UserSelectionIndex -Options $Options -Default 0

        if ($InitMode -lt 0) {
            Write-Error "Invalid selection. Aborting."
            return
        }

        switch ($InitMode) {
            0 {
                # Blank project
            }
            1 {
                # From existing GitHub project
                $SourceUrl = Read-Host "`nEnter GitHub project URL (e.g., https://github.com/owner/repo)"
                if ([string]::IsNullOrWhiteSpace($SourceUrl)) {
                    Write-Error "URL cannot be empty"
                    return
                }

                # Clone from source URL, then push to new repo
                $CloneFromSource = $SourceUrl
            }
            2 {
                # From local directory
                $LocalRepoPath = Read-Host "`nEnter path to local directory"
                if ([string]::IsNullOrWhiteSpace($LocalRepoPath) -or -not (Test-Path $LocalRepoPath)) {
                    Write-Error "Invalid path"
                    return
                }
                $CopyFromLocal = $LocalRepoPath
            }
        }
    
        # Create new repo on GitHub first
        Write-Host "`nCreating GitHub repository $GitHubOwner/$GitHubRepo..." -ForegroundColor Cyan
        try {
            $CreateRepoBody = @{
                name = $GitHubRepo
                private = $true
                auto_init = $false
            } | ConvertTo-Json

            $CreateUrl = if ($GitHubOwner -eq $UserInfo.login) {
                "https://api.github.com/user/repos"
            } else {
                "https://api.github.com/orgs/$GitHubOwner/repos"
            }

            Invoke-WebRequest -UseBasicParsing -Uri $CreateUrl -Headers $AuthHeaders -Method Post -Body $CreateRepoBody -ContentType "application/json" | Out-Null
            Write-Host "Repository created successfully" -ForegroundColor Green
        } catch {
            Write-Error "Failed to create repository: $($_.Exception.Message)"
            Write-Error "Verify your PAT has 'repo' permissions and you can create repos in $GitHubOwner"
            return
        }
    }

    # Step 6: Install dependencies
    Install-AllDependencies

    # Step 7: Initialize SyncThing
    Write-Host "`nInitializing SyncThing..." -ForegroundColor Cyan
    $SyncThingInfo = Initialize-SyncThing -WorkspaceRoot $WorkspaceRoot

    # Step 8: Create first clone
    Write-Host "`nCreating first clone..." -ForegroundColor Cyan
    $CloneRoot = New-QueClone -WorkspaceRoot $WorkspaceRoot -IsFirstClone $true -ShouldClone $ShouldClone -UserInfo $UserInfo -PlainPAT $PlainPAT -SyncThingInfo $SyncThingInfo

    # Step 9: Handle special initialization modes
    if ($InitMode -eq 0) {
        Write-Host "`nBlank project workspace created" -ForegroundColor Green
        Write-Host "Next steps:" -ForegroundColor Cyan
        Write-Host "  1. Create your Unreal Engine project in: $CloneRoot" -ForegroundColor White
        Write-Host "  2. Add and commit your files with git" -ForegroundColor White
        Write-Host "  3. Push to GitHub when ready" -ForegroundColor White
    } elseif ($InitMode -eq 1 -and $CloneFromSource) {

        # Get content from another repo
        Push-Location $CloneRoot
        git remote add source $CloneFromSource 2>&1 | ForEach-Object { "$_" } | Out-Host
        git fetch source 2>&1 | ForEach-Object { "$_" } | Out-Host
        git merge source/main --allow-unrelated-histories -m "Import from $CloneFromSource" 2>&1 | ForEach-Object { "$_" } | Out-Host
        git push origin main 2>&1 | ForEach-Object { "$_" } | Out-Host
        git remote remove source 2>&1 | ForEach-Object { "$_" } | Out-Host
        Pop-Location

        Write-Host "Imported from source repository into $CloneRoot" -ForegroundColor Green
    } elseif ($InitMode -eq 2 -and $CopyFromLocal) {

        # Copy files from a directory (excluding .git)
        $SourceFiles = Get-ChildItem $CopyFromLocal -Exclude ".git" -Force
        foreach ($File in $SourceFiles) {
            Copy-Item $File.FullName -Destination $CloneRoot -Recurse -Force
        }

        # Commit and push
        Push-Location $CloneRoot
        git add -A 2>&1 | ForEach-Object { "$_" } | Out-Host
        git commit -m "Import from local repository" 2>&1 | ForEach-Object { "$_" } | Out-Host
        git push origin main 2>&1 | ForEach-Object { "$_" } | Out-Host
        Pop-Location

        Write-Host "Imported from local repository into $CloneRoot" -ForegroundColor Green
    } elseif ($InitMode -eq 3) {
        Push-Location $CloneRoot
        git pull 2>&1 | ForEach-Object { "$_" } | Out-Host
        Pop-Location

        Write-Host "Pulled latest from repository into $CloneRoot" -ForegroundColor Green
    }

    # Step 10: Mark workspace as complete
    Set-Content -Path ".que/workspace-version" -Value "1"

    Write-Host "`nWorkspace created successfully!" -ForegroundColor Green
}

function New-QueClone {
    <#
    .SYNOPSIS
        Creates a new clone in an existing workspace
    .DESCRIPTION
        Creates clone directory, initializes or clones repository, sets up shortcuts
    #>
    param(
        [string]$WorkspaceRoot,
        [bool]$IsFirstClone = $false,
        [bool]$ShouldClone = $false,
        [object]$UserInfo = $null,
        [string]$PlainPAT = $null,
        [hashtable]$SyncThingInfo = $null
    )

    # Read workspace metadata
    $GitHubOwner = Get-Content "$WorkspaceRoot\.que\gh-repo-owner"
    $GitHubRepo = Get-Content "$WorkspaceRoot\.que\gh-repo-name"

    # Get PAT and user info if not provided
    if (-not $PlainPAT) {
        $PlainPAT = Get-SecureGitHubPAT -WorkspaceRoot $WorkspaceRoot
        $UserInfo = Test-GitHubPAT -PlainPAT $PlainPAT
        if (-not $UserInfo) {
            Write-Error "Failed to authenticate with stored PAT."
            return
        }
    }

    # Ensure SyncThing is running (important for subsequent clones)
    if (-not $SyncThingInfo) {
        Write-Host "Ensuring SyncThing is running..." -ForegroundColor Cyan
        $SyncThingInfo = Ensure-SyncThingRunning -WorkspaceRoot $WorkspaceRoot
    }

    # Generate clone name
    $CloneName = Get-NextCloneName -WorkspaceRoot $WorkspaceRoot
    $CloneRoot = Join-Path $WorkspaceRoot "repo\$CloneName"

    Write-Host "Creating clone: $CloneName" -ForegroundColor Cyan

    # Create clone directory and metadata
    New-Item -ItemType Directory -Force -Path $CloneRoot | Out-Null
    $CloneMetaPath = "$WorkspaceRoot\.que\repo\$CloneName"
    New-Item -ItemType Directory -Force -Path $CloneMetaPath | Out-Null

    # Store credentials
    Store-GitCredentials -Login $UserInfo.login -PlainPAT $PlainPAT

    if ($ShouldClone) {
        # Clone existing repository
        Write-Host "Cloning $GitHubOwner/$GitHubRepo..." -ForegroundColor Cyan

        # Skip LFS smudge to avoid downloading all LFS files during clone
        # Files will be synced to the lfs directory via SyncThing first, then updated
        $PreviousGitLfsSkipSmudge = $env:GIT_LFS_SKIP_SMUDGE
        $env:GIT_LFS_SKIP_SMUDGE = '1'

        Push-Location $CloneRoot
        git clone "https://$($UserInfo.login)@github.com/$GitHubOwner/$GitHubRepo.git" . 2>&1 | ForEach-Object { "$_" } | Out-Host
        if ($LASTEXITCODE -ne 0) {
            Pop-Location
            throw "git clone failed with exit code $LASTEXITCODE"
        }

        # Reset environment variable
        if ($null -ne $PreviousGitLfsSkipSmudge) {
            $env:GIT_LFS_SKIP_SMUDGE = $PreviousGitLfsSkipSmudge
        } else {
            Remove-Item env:GIT_LFS_SKIP_SMUDGE -ErrorAction SilentlyContinue
        }

        Pop-Location

        Write-Host "Clone complete. LFS pointer files created (objects will sync via SyncThing)" -ForegroundColor Yellow

        # Configure local git settings for cloned repo
        Push-Location $CloneRoot
        git config --local user.name $UserInfo.name
        git config --local user.email ("{0}-{1}@users.noreply.github.com" -f @($UserInfo.id, $UserInfo.login))
        git config --local credential.username $UserInfo.login
        git config --local lfs.locksverify false
        git config --local push.autoSetupRemote true
        Pop-Location

        # Write UE-specific git files if .uproject exists
        Write-UEGitConfigFiles -CloneRoot $CloneRoot
    } else {
        # Initialize new repository
        Write-Host "Initializing new repository..." -ForegroundColor Cyan
        Push-Location $CloneRoot

        git init -b main 2>&1 | ForEach-Object { "$_" } | Out-Host
        if ($LASTEXITCODE -ne 0) {
            Pop-Location
            throw "git init failed"
        }

        # Configure git (LOCAL only)
        git config --local user.name $UserInfo.name
        git config --local user.email ("{0}-{1}@users.noreply.github.com" -f @($UserInfo.id, $UserInfo.login))
        git config --local credential.username $UserInfo.login
        git config --local lfs.locksverify false
        git config --local push.autoSetupRemote true

        # Add remote
        git remote add origin "https://$($UserInfo.login)@github.com/$GitHubOwner/$GitHubRepo.git" 2>&1 | ForEach-Object { "$_" } | Out-Host

        Pop-Location

        # Write initial files
        Write-GitConfigFiles -CloneRoot $CloneRoot

        # Create README
        $ReadmeContent = $EmbeddedReadme -replace '{{OWNER}}', $GitHubOwner -replace '{{REPO}}', $GitHubRepo
        Set-Content -Path "$CloneRoot\README.md" -Value $ReadmeContent

        # Generate que-repo-name.ps1
        Write-Host "Generating que-$GitHubRepo.ps1..." -ForegroundColor Cyan
        $DeviceId = if ($SyncThingInfo) { $SyncThingInfo.DeviceId } else { "" }
        New-QueRepoScript -CloneRoot $CloneRoot -Owner $GitHubOwner -Repo $GitHubRepo -SyncThingDeviceId $DeviceId

        # Initial commit
        Push-Location $CloneRoot
        git add . 2>&1 | ForEach-Object { "$_" } | Out-Host
        if ($LASTEXITCODE -ne 0) {
            Pop-Location
            throw "git add failed"
        }

        git commit -m "Initial commit: QUE workspace setup" 2>&1 | ForEach-Object { "$_" } | Out-Host
        if ($LASTEXITCODE -ne 0) {
            Pop-Location
            throw "git commit failed"
        }

        git push -u origin main 2>&1 | ForEach-Object { "$_" } | Out-Host
        if ($LASTEXITCODE -ne 0) {
            Pop-Location
            throw "git push failed"
        }

        Pop-Location

        Write-Host "`nRepository initialized and pushed to GitHub!" -ForegroundColor Green
        Write-Host "After creating the .uproject file, the UE git config files will be auto-generated." -ForegroundColor Yellow
    }

    # Configure Git LFS
    Push-Location $CloneRoot
    git lfs install --local 2>&1 | ForEach-Object { "$_" } | Out-Host
    $LfsStoragePath = Join-Path $WorkspaceRoot "sync\git-lfs\lfs"
    git config --local lfs.storage $LfsStoragePath
    Pop-Location

    # Create shortcut
    $ShortcutPath = "$WorkspaceRoot\open-$CloneName.lnk"
    $TargetScript = "$CloneRoot\que-$GitHubRepo.ps1"
    New-WindowsShortcut -ShortcutPath $ShortcutPath -TargetScript $TargetScript
    Write-Host "Created shortcut: $ShortcutPath" -ForegroundColor Green

    # Mark clone as complete
    Set-Content -Path "$CloneMetaPath\repo-version" -Value "1"

    return $CloneRoot
}

# ----------------------------------------------------------------------------
# MANAGEMENT COMMANDS (commented out in que57.ps1, active in que-repo-name.ps1)
# ----------------------------------------------------------------------------
<####QUE_MANAGEMENT_MODE_BEGIN###

# ----------------------------------------------------------------------------
# Unreal Engine Helper Functions
# ----------------------------------------------------------------------------


function Get-UnrealProjectEngineVersion {
    param([string]$UProjectPath)

    if (Test-Path $UProjectPath -PathType Container) {
        $UProjectPath = Find-UProjectFile -CloneRoot $UProjectPath
        if (-not $UProjectPath) {
            throw "No .uproject file found in directory"
        }
    }

    $UProjectContent = Get-Content $UProjectPath -Raw | ConvertFrom-Json
    return $UProjectContent.EngineAssociation
}

function Get-UnrealEngineDirectory {
    param([string]$UProjectPath)

    $EngineVersion = Get-UnrealProjectEngineVersion -UProjectPath $UProjectPath
    $RegistryPath = "HKLM:\Software\EpicGames\Unreal Engine\$EngineVersion"

    if (-not (Test-Path $RegistryPath)) {
        throw "Unreal Engine $EngineVersion is not installed. Install it via Epic Games Launcher."
    }

    $InstallDir = (Get-ItemProperty -Path $RegistryPath -Name "InstalledDirectory" -ErrorAction Stop).InstalledDirectory
    if (-not (Test-Path $InstallDir)) {
        throw "Unreal Engine installation directory not found: $InstallDir"
    }

    return $InstallDir
}

function Get-UnrealBuildTool {
    param([string]$UProjectPath)

    $EngineDir = Get-UnrealEngineDirectory -UProjectPath $UProjectPath
    $UBTPath = Join-Path $EngineDir "Engine\Binaries\DotNET\UnrealBuildTool\UnrealBuildTool.exe"

    if (-not (Test-Path $UBTPath)) {
        throw "UnrealBuildTool not found at: $UBTPath"
    }

    return $UBTPath
}

function Invoke-UnrealGenerate {
    param([string]$UProjectPath)

    $UBTPath = Get-UnrealBuildTool -UProjectPath $UProjectPath
    $ProjectDir = Split-Path $UProjectPath -Parent

    Write-Host "Generating project files..." -ForegroundColor Cyan
    & $UBTPath -Mode=GenerateProjectFiles -Project="$UProjectPath" -Silent

    if ($LASTEXITCODE -ne 0) {
        throw "Project file generation failed with exit code $LASTEXITCODE"
    }

    Write-Host "Project files generated successfully" -ForegroundColor Green
}

function Invoke-UnrealBuild {
    param([string]$UProjectPath)

    $EngineDir = Get-UnrealEngineDirectory -UProjectPath $UProjectPath
    $BuildBatchFile = Join-Path $EngineDir "Engine\Build\BatchFiles\Build.bat"
    $ProjectName = [System.IO.Path]::GetFileNameWithoutExtension($UProjectPath)

    if (-not (Test-Path $BuildBatchFile)) {
        throw "Build.bat not found at: $BuildBatchFile"
    }

    Write-Host "Building $ProjectName Editor (Development Win64)..." -ForegroundColor Cyan
    & $BuildBatchFile "${ProjectName}Editor" Win64 Development "-Project=`"$UProjectPath`"" -Progress -NoEngineChanges -NoHotReloadFromIDE

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Build failed with exit code $LASTEXITCODE"
        return $false
    }

    Write-Host "Build completed successfully" -ForegroundColor Green
    return $true
}

function Invoke-UnrealEditor {
    param([string]$UProjectPath)

    $EngineDir = Get-UnrealEngineDirectory -UProjectPath $UProjectPath
    $EditorPath = Join-Path $EngineDir "Engine\Binaries\Win64\UnrealEditor.exe"

    if (-not (Test-Path $EditorPath)) {
        throw "UnrealEditor.exe not found at: $EditorPath"
    }

    Write-Host "Launching Unreal Editor..." -ForegroundColor Cyan
    Start-Process -FilePath $EditorPath -ArgumentList "`"$UProjectPath`"" -WorkingDirectory (Split-Path $UProjectPath -Parent)

    Write-Host "Editor launched" -ForegroundColor Green
}

function Invoke-UnrealClean {
    param([string]$UProjectPath)

    $ProjectDir = Split-Path $UProjectPath -Parent
    $ProjectName = [System.IO.Path]::GetFileNameWithoutExtension($UProjectPath)

    try {
        $EngineDir = Get-UnrealEngineDirectory -UProjectPath $UProjectPath
        $CleanBatchFile = Join-Path $EngineDir "Engine\Build\BatchFiles\Clean.bat"

        if (Test-Path $CleanBatchFile) {
            Write-Host "Running Clean.bat..." -ForegroundColor Cyan
            & $CleanBatchFile $ProjectName Win64 Development
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Clean completed successfully" -ForegroundColor Green
                return
            }
            Write-Warning "Clean.bat failed, falling back to manual cleanup"
        }
    } catch {
        Write-Warning "Could not run Clean.bat: $($_.Exception.Message)"
    }

    # Manual cleanup
    Write-Host "Performing manual cleanup..." -ForegroundColor Cyan

    $FoldersToDelete = @("Binaries", "Intermediate", "Saved", "DerivedDataCache")
    foreach ($Folder in $FoldersToDelete) {
        $FolderPath = Join-Path $ProjectDir $Folder
        if (Test-Path $FolderPath) {
            Write-Host "Deleting $Folder..." -ForegroundColor Yellow
            Remove-Item $FolderPath -Recurse -Force
        }
    }

    # Delete generated .sln files
    $SlnFiles = Get-ChildItem -Path (Split-Path $ProjectDir -Parent) -Filter "*.sln" -ErrorAction SilentlyContinue
    foreach ($SlnFile in $SlnFiles) {
        Write-Host "Deleting $($SlnFile.Name)..." -ForegroundColor Yellow
        Remove-Item $SlnFile.FullName -Force
    }

    Write-Host "Clean completed. Next build will be a full rebuild." -ForegroundColor Green
}

function Invoke-UnrealPackage {
    param([string]$UProjectPath)

    $EngineDir = Get-UnrealEngineDirectory -UProjectPath $UProjectPath
    $RunUATPath = Join-Path $EngineDir "Engine\Build\BatchFiles\RunUAT.bat"
    $ProjectDir = Split-Path $UProjectPath -Parent
    $ProjectName = [System.IO.Path]::GetFileNameWithoutExtension($UProjectPath)

    if (-not (Test-Path $RunUATPath)) {
        throw "RunUAT.bat not found at: $RunUATPath"
    }

    # Prompt for build configuration
    Write-Host "`nSelect build configuration:" -ForegroundColor Yellow
    Write-Host "1. Development" -ForegroundColor White
    Write-Host "2. Shipping" -ForegroundColor White
    Write-Host "3. DebugGame" -ForegroundColor White

    $Selection = Read-Host "Enter selection (1-3)"
    $BuildConfig = switch ($Selection) {
        "1" { "Development" }
        "2" { "Shipping" }
        "3" { "DebugGame" }
        default {
            Write-Warning "Invalid selection, using Development"
            "Development"
        }
    }

    Write-Host "Using configuration: $BuildConfig" -ForegroundColor Green

    # Package client
    Write-Host "`nPackaging client build ($BuildConfig)..." -ForegroundColor Cyan
    & $RunUATPath BuildCookRun `
        -project="$UProjectPath" `
        -nop4 `
        -platform=Win64 `
        -clientconfig=$BuildConfig `
        -cook `
        -allmaps `
        -build `
        -stage `
        -pak `
        -archive `
        -archivedirectory="$ProjectDir\Saved\Packages\$BuildConfig\Client"

    if ($LASTEXITCODE -ne 0) {
        throw "Client package failed with exit code $LASTEXITCODE"
    }

    # Package server
    Write-Host "`nPackaging server build ($BuildConfig)..." -ForegroundColor Cyan
    & $RunUATPath BuildCookRun `
        -project="$UProjectPath" `
        -nop4 `
        -platform=Win64 `
        -serverconfig=$BuildConfig `
        -server `
        -noclient `
        -cook `
        -allmaps `
        -build `
        -stage `
        -pak `
        -archive `
        -archivedirectory="$ProjectDir\Saved\Packages\$BuildConfig\Server"

    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Server package failed (project may not have server target)"
    }

    return @{
        Configuration = $BuildConfig
        Client = "$ProjectDir\Saved\Packages\$BuildConfig\Client"
        Server = "$ProjectDir\Saved\Packages\$BuildConfig\Server"
    }
}

function Open-UnrealProject {
    Write-Host "`nOpening Unreal Engine project..." -ForegroundColor Cyan

    # Find .uproject file
    $UProjectPath = Find-UProjectFile -CloneRoot $CloneRoot
    if (-not $UProjectPath) {
        Write-Error "No .uproject file found. Please create your Unreal project first."
        return
    }

    # Generate project files
    Write-Host "Generating project files..."
    try {
        Invoke-UnrealGenerate -UProjectPath $UProjectPath
    } catch {
        Write-Error "Project file generation failed: $($_.Exception.Message)"
        return
    }

    # Build editor
    Write-Host "Building editor..."
    try {
        $BuildSuccess = Invoke-UnrealBuild -UProjectPath $UProjectPath
        if (-not $BuildSuccess) {
            Write-Error "Build failed. Check output above for errors."
            return
        }
    } catch {
        Write-Error "Build failed: $($_.Exception.Message)"
        return
    }

    # Launch editor
    Write-Host "Launching Unreal Editor..."
    try {
        Invoke-UnrealEditor -UProjectPath $UProjectPath
        Write-Host "Editor launched successfully!" -ForegroundColor Green
    } catch {
        Write-Error "Failed to launch editor: $($_.Exception.Message)"
    }
}

function Build-UnrealProject {
    Write-Host "`nBuilding Unreal Engine project..." -ForegroundColor Cyan

    $UProjectPath = Find-UProjectFile -CloneRoot $CloneRoot
    if (-not $UProjectPath) {
        Write-Error "No .uproject file found."
        return
    }

    # Generate project files
    Write-Host "Generating project files..."
    try {
        Invoke-UnrealGenerate -UProjectPath $UProjectPath
    } catch {
        Write-Error "Project file generation failed: $($_.Exception.Message)"
        return
    }

    # Build editor
    Write-Host "Building editor..."
    try {
        $BuildSuccess = Invoke-UnrealBuild -UProjectPath $UProjectPath
        if ($BuildSuccess) {
            Write-Host "Build completed successfully!" -ForegroundColor Green
        } else {
            Write-Error "Build failed."
        }
    } catch {
        Write-Error "Build failed: $($_.Exception.Message)"
    }
}

function Clean-UnrealProject {
    Write-Host "`nCleaning Unreal Engine project..." -ForegroundColor Cyan

    $UProjectPath = Find-UProjectFile -CloneRoot $CloneRoot
    if (-not $UProjectPath) {
        Write-Error "No .uproject file found."
        return
    }

    try {
        Invoke-UnrealClean -UProjectPath $UProjectPath
    } catch {
        Write-Error "Clean failed: $($_.Exception.Message)"
    }
}


function Package-UnrealProject {
    Write-Host "`nPackaging Unreal Engine project..." -ForegroundColor Cyan

    $UProjectPath = Find-UProjectFile -CloneRoot $CloneRoot
    if (-not $UProjectPath) {
        Write-Error "No .uproject file found."
        return
    }

    try {
        $PackageResult = Invoke-UnrealPackage -UProjectPath $UProjectPath

        if ($PackageResult) {
            Write-Host "`nPackaging complete ($($PackageResult.Configuration))!" -ForegroundColor Green
            if ($PackageResult.Client) {
                Write-Host "Client package: $($PackageResult.Client)"
            }
            if ($PackageResult.Server) {
                Write-Host "Server package: $($PackageResult.Server)"
            }
        }
    } catch {
        Write-Error "Packaging failed: $($_.Exception.Message)"
    }
}

function Show-WorkspaceInfo {
    Write-Host "`n===============================================================" -ForegroundColor Cyan
    Write-Host "  QUE Workspace Information" -ForegroundColor Green
    Write-Host "===============================================================" -ForegroundColor Cyan

    # Workspace info
    Write-Host "`nWorkspace:" -ForegroundColor Yellow
    Write-Host "  Root: $WorkspaceRoot"
    Write-Host "  Version: $(Get-Content "$WorkspaceRoot\.que\workspace-version" -ErrorAction SilentlyContinue)"

    # Clone info
    Write-Host "`nClone:" -ForegroundColor Yellow
    Write-Host "  Name: $CloneName"
    Write-Host "  Root: $CloneRoot"
    $RepoVersion = Get-Content "$WorkspaceRoot\.que\repo\$CloneName\repo-version" -ErrorAction SilentlyContinue
    Write-Host "  Version: $(if ($RepoVersion) { $RepoVersion } else { 'Not set' })"

    # GitHub info
    Write-Host "`nGitHub:" -ForegroundColor Yellow
    Write-Host "  Repository: $GitHubOwner/$GitHubRepo"

    Push-Location $CloneRoot
    $GitUser = git config user.name
    if ($LASTEXITCODE -eq 0) {
        $GitEmail = git config user.email
        $GitBranch = git rev-parse --abbrev-ref HEAD 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  User: $GitUser <$GitEmail>"
            Write-Host "  Branch: $GitBranch"
        } else {
            Write-Host "  User: $GitUser <$GitEmail>"
            Write-Host "  Branch: (unable to determine)"
        }
    }
    Pop-Location

    # Unreal project info
    $UProjectPath = Find-UProjectFile -CloneRoot $CloneRoot
    if ($UProjectPath) {
        Write-Host "`nUnreal Engine:" -ForegroundColor Yellow
        Write-Host "  Project: $UProjectPath"
        Write-Host "  Version: $UnrealEngineVersion"
    } else {
        Write-Host "`nUnreal Engine:" -ForegroundColor Yellow
        Write-Host "  No .uproject file found"
    }

    # SyncThing info
    Write-Host "`nSyncThing:" -ForegroundColor Yellow
    $SyncThingRunning = Get-Process syncthing -ErrorAction SilentlyContinue
    if ($SyncThingRunning) {
        Write-Host "  Status: Running"
        Write-Host "  Devices: $($script:SyncThingDevices.Count)"
        foreach ($DeviceId in $script:SyncThingDevices) {
            Write-Host "    - $DeviceId"
        }
    } else {
        Write-Host "  Status: Not running"
    }

    Write-Host "`n===============================================================`n" -ForegroundColor Cyan
}
#>###QUE_MANAGEMENT_MODE_END###

# ----------------------------------------------------------------------------
# MAIN EXECUTION FUNCTION
# ----------------------------------------------------------------------------
function Invoke-QueMain {
    # EXECUTION MODE DETECTION
    $IsDotSourced = $MyInvocation.InvocationName -eq '.'
    $IsRunFromUrl = (Test-Path variable:queScript) -and (Test-Path variable:queUrl)
    $IsDirectExecution = -not $IsDotSourced -and -not $IsRunFromUrl

    # MODE 1: DOT-SOURCED
    if ($IsDotSourced) {
        Write-Host "QUE commands loaded" -ForegroundColor Green
        return
    }

    # MODE 2: RUN FROM URL - Workspace/Clone Creation
    if ($IsRunFromUrl) {
        # Extract GitHub info from URL (if available)
        $UrlOwner = $null
        $UrlRepo = $null
        $IsBootstrapScript = $false

        if ($queUrl -match 'githubusercontent\.com/([^/]+)/([^/]+)/[^/]+/(.+)$') {
            $UrlOwner = $matches[1]
            $UrlRepo = $matches[2]
            $ScriptName = $matches[3]

            # Check if this is the bootstrap script (que57.ps1) or a project script (que-REPO.ps1)
            if ($ScriptName -eq 'que57.ps1') {
                $IsBootstrapScript = $true
            }
        }

        # Early check: If current folder is not empty and not a QUE workspace, error immediately
        # This prevents users from entering their PAT before discovering they're in the wrong location
        $CurrentFolderIsQueWorkspace = Test-Path ".que"
        if (-not $CurrentFolderIsQueWorkspace) {
            $CurrentItems = Get-ChildItem -Force -ErrorAction SilentlyContinue
            if ($CurrentItems.Count -gt 0) {
                Write-Error "Current folder is not empty. QUE workspace must be initialized in an empty folder."
                Write-Host "Please create and navigate to an empty folder, then run this command again." -ForegroundColor Yellow
                return
            }
        }

        # Detect workspace context
        $WorkspaceRoot = Find-QueWorkspace

        if ($WorkspaceRoot) {
            # In a workspace - check if it matches (for joining existing projects)
            $ExistingOwner = Get-Content "$WorkspaceRoot\.que\gh-repo-owner"
            $ExistingRepo = Get-Content "$WorkspaceRoot\.que\gh-repo-name"

            if ($UrlOwner -and $UrlRepo -and -not $IsBootstrapScript) {
                if ($ExistingOwner -eq $UrlOwner -and $ExistingRepo -eq $UrlRepo) {
                    # Mode 2A: Create new clone in matching workspace
                    Write-Host "Found matching workspace at: $WorkspaceRoot" -ForegroundColor Green
                    New-QueClone -WorkspaceRoot $WorkspaceRoot -ShouldClone $true
                } else {
                    # Mode 2B: Error - mismatched workspace
                    Write-Error "Current workspace is for $ExistingOwner/$ExistingRepo, but you're trying to create $UrlOwner/$UrlRepo"
                    Write-Host "Please run this command in a folder outside this workspace to create a new workspace, or within a $UrlRepo workspace to create a new clone." -ForegroundColor Yellow
                    return
                }
            } else {
                Write-Error "Already in a QUE workspace for $ExistingOwner/$ExistingRepo"
                Write-Host "To create a new workspace, run this command outside of an existing workspace." -ForegroundColor Yellow
                return
            }
        } else {
            # Not in a workspace - check if current folder is empty
            $CurrentItems = Get-ChildItem -Force -ErrorAction SilentlyContinue
            if ($CurrentItems.Count -gt 0) {
                Write-Error "Current folder is not empty. QUE workspace must be initialized in an empty folder."
                Write-Host "Please create and navigate to an empty folder, then run this command again." -ForegroundColor Yellow
                return
            }

            Write-Host "`nQUE 5.7 - Quick Unreal Engine Project Manager" -ForegroundColor Cyan
            $WorkspaceRoot = (Get-Location).Path

            if ($IsBootstrapScript) {
                ###QUE_CREATION_MODE_BEGIN###
                # Bootstrap mode - prompt for new repo name with default
                Write-Host "Setting up a new project workspace...`n" -ForegroundColor Green

                # Generate default repo name from current folder
                $CurrentFolderName = Split-Path $WorkspaceRoot -Leaf
                $DefaultRepoName = $CurrentFolderName -replace '[^a-zA-Z0-9_-]', ''

                # Prompt for repository name with default
                $GitHubRepo = Read-Host "Enter new repository name [$DefaultRepoName]"
                if ([string]::IsNullOrWhiteSpace($GitHubRepo)) {
                    $GitHubRepo = $DefaultRepoName
                }

                if ([string]::IsNullOrWhiteSpace($GitHubRepo)) {
                    Write-Error "Repository name cannot be empty"
                    return
                }

                Write-Host "Using repository name: $GitHubRepo" -ForegroundColor Green

                # Prompt for PAT
                $SecurePAT = Read-Host "Enter GitHub Personal Access Token" -AsSecureString
                $PlainPAT = [System.Net.NetworkCredential]::new('', $SecurePAT).Password

                # Get user info from PAT
                $UserInfo = Test-GitHubPAT -PlainPAT $PlainPAT
                if (-not $UserInfo) {
                    Write-Error "Invalid GitHub PAT. Please check your token and try again."
                    return
                }

                Write-Host "Authenticated as: $($UserInfo.login)" -ForegroundColor Green
                $GitHubOwner = $UserInfo.login

                # Create new workspace with initialization options
                New-QueWorkspace -GitHubOwner $GitHubOwner -GitHubRepo $GitHubRepo -PlainPAT $PlainPAT -UserInfo $UserInfo
                ###QUE_CREATION_MODE_END###
            } elseif ($UrlOwner -and $UrlRepo) {
                # Joining existing project - use URL owner/repo
                Write-Host "Joining project: $UrlOwner/$UrlRepo`n" -ForegroundColor Green

                # Prompt for PAT unless it was provided in the initial command
                if ($quePlainPAT) {
                    $PlainPAT = $quePlainPAT
                } else {
                    $SecurePAT = Read-Host "Enter GitHub Personal Access Token" -AsSecureString
                    $PlainPAT = [System.Net.NetworkCredential]::new('', $SecurePAT).Password
                }

                # Get user info from PAT
                $UserInfo = Test-GitHubPAT -PlainPAT $PlainPAT
                if (-not $UserInfo) {
                    Write-Error "Invalid GitHub PAT. Please check your token and try again."
                    return
                }

                Write-Host "Authenticated as: $($UserInfo.login)" -ForegroundColor Green

                # Create workspace and clone existing repo
                New-QueWorkspace -GitHubOwner $UrlOwner -GitHubRepo $UrlRepo -PlainPAT $PlainPAT -UserInfo $UserInfo
            } else {
                Write-Error "Cannot determine repository information from URL: $queUrl"
                return
            }
        }
    } else {

        # MODE 3: DIRECT EXECUTION - Management Terminal
        if ($IsDirectExecution) {
            # Find workspace and clone
            $WorkspaceRoot = Find-QueWorkspace
            if (-not $WorkspaceRoot) {
                Write-Error "Not in a QUE workspace. Run this script via iex (iwr ...) to create one."
                return
            }
        
            # Ensure SyncThing is running
            Write-Host "Ensuring SyncThing is running..." -ForegroundColor Cyan
            $SyncThingInfo = Ensure-SyncThingRunning -WorkspaceRoot $WorkspaceRoot
        
            # Ensure current device is in SyncThing devices list
            $CurrentDeviceId = $SyncThingInfo.DeviceId
            if ((-not [string]::IsNullOrWhiteSpace($CurrentDeviceId)) -and $script:SyncThingDevices -and ($script:SyncThingDevices -notcontains $CurrentDeviceId)) {
                Write-Host "Adding current device to SyncThing devices list..." -ForegroundColor Yellow

                # DEBUG: Show what we have before adding
                Write-Host "DEBUG: Current device ID: $CurrentDeviceId" -ForegroundColor Magenta
                Write-Host "DEBUG: SyncThingDevices before adding: $($script:SyncThingDevices -join ', ')" -ForegroundColor Magenta
                Write-Host "DEBUG: Count before: $($script:SyncThingDevices.Count)" -ForegroundColor Magenta

                # Add to array (use script scope to modify the script-level variable)
                $script:SyncThingDevices += $CurrentDeviceId

                # DEBUG: Show what we have after adding
                Write-Host "DEBUG: SyncThingDevices after adding: $($script:SyncThingDevices -join ', ')" -ForegroundColor Magenta
                Write-Host "DEBUG: Count after: $($script:SyncThingDevices.Count)" -ForegroundColor Magenta

                # Rewrite this script with updated devices
                $ScriptPath = $PSCommandPath
                $ScriptContent = Get-Content $ScriptPath -Raw

                # Rebuild SyncThing block
                $DevicesEntries = $script:SyncThingDevices | ForEach-Object {
                    "    `"$_`""
                }
                $DevicesBlock = "@(`n" + ($DevicesEntries -join ",`n") + "`n)"

                $NewSyncThingBlock = @"
{0}QUE_SYNCTHING_BEGIN{0}
`$SyncThingDevices = {1}
{0}QUE_SYNCTHING_END{0}
"@ -f @('###', $DevicesBlock)

                $UpdatedContent = $ScriptContent -replace ('{0}QUE_SYNCTHING_BEGIN{0}[\s\S]*?{0}QUE_SYNCTHING_END{0}' -f @('###')), $NewSyncThingBlock

                Set-Content -Path $ScriptPath -Value $UpdatedContent

                Write-Host "Script updated with current device. Please commit this change to share with team." -ForegroundColor Green
            }

            # Configure SyncThing with all known devices
            if ($script:SyncThingDevices -and $script:SyncThingDevices.Count -gt 0) {
                Update-SyncThingDevices -WorkspaceRoot $WorkspaceRoot -DeviceIds $script:SyncThingDevices -SyncThingInfo $SyncThingInfo
            }
        
            # Detect which clone we're in by checking the script location
            $ScriptPath = $PSCommandPath
            $CloneRoot = Split-Path $ScriptPath -Parent
            $CloneName = Split-Path $CloneRoot -Leaf
        
            # Check if user created UE project and auto-generate git config files if needed
            Write-UEGitConfigFiles -CloneRoot $CloneRoot
        
            # Display header
            Write-Host "`n===============================================================" -ForegroundColor Cyan
            Write-Host "  QUE - $GitHubOwner/$GitHubRepo" -ForegroundColor Green
            Write-Host "  Clone: $CloneName" -ForegroundColor Yellow
            Write-Host "  Workspace: $WorkspaceRoot" -ForegroundColor Gray
            Write-Host "===============================================================`n" -ForegroundColor Cyan
        
            # Command loop
            while ($true) {
                Write-Host "Commands: " -NoNewline -ForegroundColor White
                Write-Host "open, build, clean, package, info, exit" -ForegroundColor Gray
                $Command = Read-Host "`nQUE>"

                switch ($Command.ToLower()) {
                    "open"    { Open-UnrealProject }
                    "build"   { Build-UnrealProject }
                    "clean"   { Clean-UnrealProject }
                    "package" { Package-UnrealProject }
                    "info"    { Show-WorkspaceInfo }
                    "exit"    { return }
                    ""        { continue }
                    default   { Write-Host "Unknown command: $Command" -ForegroundColor Red }
                }
            }
        }
    }
}

# ----------------------------------------------------------------------------
# SCRIPT ENTRY POINT
# ----------------------------------------------------------------------------
# Detect if dot-sourced before calling main
$IsDotSourced = $MyInvocation.InvocationName -eq '.'
if (-not $IsDotSourced) {
    Invoke-QueMain
}
