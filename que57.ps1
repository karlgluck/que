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
# (Other constants will be dynamically substituted)
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
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ($queScript = (iwr -useb -Headers @{Authorization = "token $($quePlainPAT = Read-Host 'Enter Personal Access Token';$quePlainPAT)"} -Uri ($queUrl = "https://raw.githubusercontent.com/{{OWNER}}/{{REPO}}/main/que57-project.ps1")).Content)
```

3. Follow the prompts to:
   - Enter your GitHub Personal Access Token
   - Install dependencies (Git, GitLFS, SyncThing, Visual Studio Build Tools)
   - Install Unreal Engine 5.7 via Epic Games Launcher
   - Clone the repository

4. Launch the environment using the generated shortcut

**Note:** During setup, you may see a UAC prompt for .NET Framework 3.5 installation - this is required for Unreal Engine build tools.

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

Once your workspace is set up, launch the management terminal using `que57-project.ps1`:

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
    +-- kauilani/            # Clone directory (random name)
        +-- que57-project.ps1 # Project management script
```

**Clone Naming:** Each clone gets a unique Hawaiian-sounding name (e.g., Kauilani, Mahalo, Wakena) to make the randomness more pleasant and easily recognized.

## How It Works

**Git LFS + SyncThing:** Large binary files are stored in Git LFS but synchronized across team members using SyncThing instead of downloading from GitHub. This provides faster syncing and reduces bandwidth costs. During initial clone, LFS pointer files are created but actual objects sync via SyncThing in the background.

**Persistent SyncThing Port:** SyncThing uses a consistent port (stored in `.que/syncthing/gui.port`) to ensure the same instance is detected and reused across script runs.

## About QUE

QUE is a single-file PowerShell solution for managing Unreal Engine projects with Git, GitLFS, and SyncThing integration. Learn more at https://github.com/karlgluck/que
'@
###QUE_EMBEDDED_FILES_END###

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

# ----------------------------------------------------------------------------
# SYNCTHING DEVICES (only in que57-project.ps1)
# ----------------------------------------------------------------------------
###QUE_SYNCTHING_BEGIN###
# $SyncThingDevices = @()  # Embedded in que57-project.ps1 only (array of device IDs)
###QUE_SYNCTHING_END###

# ----------------------------------------------------------------------------
# HELPER FUNCTIONS
# ----------------------------------------------------------------------------

function Find-QueWorkspace {
    # Searches current and parent directories for .que folder. Returns workspace root path or $null if not found.
    $CurrentPath = Get-Location
    $Path = $CurrentPath
    while ($Path) {
        $QuePath = Join-Path $Path ".que"
        if (Test-Path $QuePath) {
            $OwnerFile = Join-Path $QuePath "gh-repo-owner"
            $RepoFile = Join-Path $QuePath "gh-repo-name"
            if ((Test-Path $OwnerFile) -and (Test-Path $RepoFile)) {
                return $Path
            }
        }
        $Parent = Split-Path $Path -Parent
        if ($Parent -eq $Path) { break }
        $Path = $Parent
    }
    return $null
}

function Get-AvailableSyncThingPort {
    # Finds an available port for SyncThing GUI in range 8384-8484
    $MinPort = 8384
    $MaxPort = 8484
    $StartPort = Get-Random -Minimum $MinPort -Maximum $MaxPort
    for ($i = 0; $i -lt ($MaxPort - $MinPort); $i++) {
        $Port = (($StartPort + $i - $MinPort) % ($MaxPort - $MinPort)) + $MinPort
        $InUse = [bool](Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue)
        if (-not $InUse) { return $Port }
    }
    throw "No available ports in range $MinPort-$MaxPort"
}

function Get-SecureGitHubPAT {
    # Reads and decrypts GitHub Personal Access Token from env/github/pat.dat
    param([string]$WorkspaceRoot)
    $PatFile = Join-Path $WorkspaceRoot "env\github\pat.dat"
    if (-not (Test-Path $PatFile)) { return $null }
    try {
        $SecureString = Get-Content $PatFile | ConvertTo-SecureString
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
    # Encrypts and stores GitHub Personal Access Token to env/github/pat.dat
    param([string]$PlainPAT, [string]$WorkspaceRoot)
    $EnvDir = Join-Path $WorkspaceRoot "env\github"
    if (-not (Test-Path $EnvDir)) {
        New-Item -ItemType Directory -Force -Path $EnvDir | Out-Null
    }
    $PatFile = Join-Path $WorkspaceRoot "env\github\pat.dat"
    $SecureString = ConvertTo-SecureString $PlainPAT -AsPlainText -Force
    $SecureString | ConvertFrom-SecureString | Set-Content $PatFile
}

function Store-GitCredentials {
    # Stores Git credentials in Windows Credential Manager
    param([string]$Login, [string]$PlainPAT)
    $env:GCM_INTERACTIVE = "never"
    @"
protocol=https
host=github.com
username=$Login
password=$PlainPAT
"@  | git credential-manager store
}

function Test-GitHubPAT {
    # Tests GitHub Personal Access Token validity by calling GitHub API /user
    # Returns user info object or $null if invalid
    # IMPORTANT: The email field from API should NOT be used for git config
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
    # Generates a unique Hawaiian-sounding clone directory name
    param([string]$WorkspaceRoot)
    $RepoDir = Join-Path $WorkspaceRoot "repo"
    $ExistingNames = @()
    if (Test-Path $RepoDir) {
        $ExistingNames = @(Get-ChildItem $RepoDir -Directory | ForEach-Object { $_.Name.ToLower() })
    }
    # Hawaiian phoneme sets
    [string[]]$Vowels = @('a','e','i','o','u')
    [string[]]$Consonants = @('h','k','l','m','n','p','w')
    [string[]]$Onsets = @(
        '', 'h','k','l','m','n','p','w',
        'ha','he','hi','ho','hu',
        'ka','ke','ki','ko','ku',
        'la','le','li','lo','lu',
        'ma','me','mi','mo','mu',
        'na','ne','ni','no','nu',
        'pa','pe','pi','po','pu',
        'wa','we','wi','wo','wu'
    )
    [string[]]$Diphthongs = @('ai','ae','ao','au','ei','eu','oi','ou','ia','io','iu')
    # Generate unique names until we find one that doesn't exist
    $MaxAttempts = 100
    for ($Attempt = 0; $Attempt -lt $MaxAttempts; $Attempt++) {
        $Length = Get-Random -Minimum 5 -Maximum 11
        $Syllables = @()
        $CurrentLength = 0
        while ($CurrentLength -lt $Length) {
            if ($Syllables.Count -eq 0) {
                # First syllable - can start with vowel or consonant
                if ((Get-Random -Maximum 10) -lt 4) {
                    $Syl = $Vowels[(Get-Random -Maximum $Vowels.Count)]
                } else {
                    $Syl = $Onsets[(Get-Random -Maximum $Onsets.Count)]
                    if ($Syl -eq '') { $Syl = $Vowels[(Get-Random -Maximum $Vowels.Count)] }
                }
            } else {
                # Subsequent syllables
                if ((Get-Random -Maximum 10) -lt 5) {
                    if ((Get-Random -Maximum 10) -lt 6) {
                        $Syl = $Diphthongs[(Get-Random -Maximum $Diphthongs.Count)]
                    } else {
                        $Syl = $Vowels[(Get-Random -Maximum $Vowels.Count)]
                    }
                } else {
                    $C = $Consonants[(Get-Random -Maximum $Consonants.Count)]
                    $V = $Vowels[(Get-Random -Maximum $Vowels.Count)]
                    $Syl = $C + $V
                }
            }
            if (($CurrentLength + $Syl.Length) -le $Length + 2) {
                $Syllables += $Syl
                $CurrentLength += $Syl.Length
            } else {
                if ($CurrentLength -lt $Length) {
                    $Syllables += $Vowels[(Get-Random -Maximum $Vowels.Count)]
                    $CurrentLength += 1
                }
                break
            }
        }
        $Word = ($Syllables -join '').Trim()
        $HasTripleRepeat = $Word -match '(.)\1\1'
        if ($Word -and -not $HasTripleRepeat -and ($Word.ToLower() -notin $ExistingNames)) {
            return $Word
        }
    }
    # Fallback: append timestamp if all attempts fail
    return "Clone-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
}

function Find-UProjectFile {
    # Finds .uproject file in clone directory using breadth-first search. Returns full path or $null.
    # Excludes Samples/ and Templates/ directories
    param([string]$CloneRoot)
    $Queue = @(Get-ChildItem -Path $CloneRoot -Directory -ErrorAction SilentlyContinue)
    $UProjects = @()
    $Visited = @{}  # Track visited directories to prevent infinite loops
    $MaxIterations = 10000  # Safety limit
    $Iterations = 0

    $RootProjects = Get-ChildItem -Path $CloneRoot -Filter "*.uproject" -ErrorAction SilentlyContinue
    if ($RootProjects) { $UProjects += $RootProjects }

    while ($Queue.Count -gt 0) {
        $Iterations++
        if ($Iterations -gt $MaxIterations) {
            Write-Warning "Search iteration limit reached. Possible circular directory reference detected."
            break
        }

        $Current = $Queue[0]
        # More robust array slicing
        if ($Queue.Count -eq 1) {
            $Queue = @()
        } else {
            $Queue = $Queue[1..($Queue.Count - 1)]
        }

        # Skip if already visited (prevents circular references)
        $CurrentPath = $Current.FullName
        if ($Visited.ContainsKey($CurrentPath)) { continue }
        $Visited[$CurrentPath] = $true

        if ($Current.Name -in @('Samples', 'Templates', 'Binaries', 'Intermediate', 'Saved')) { continue }

        $Projects = Get-ChildItem -Path $Current.FullName -Filter "*.uproject" -ErrorAction SilentlyContinue
        if ($Projects) { $UProjects += $Projects }

        $SubDirs = Get-ChildItem -Path $Current.FullName -Directory -ErrorAction SilentlyContinue
        $Queue += $SubDirs
    }
    if ($UProjects.Count -eq 0) { return $null }
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
    # Creates a Windows .lnk shortcut file that launches PowerShell script
    param([string]$ShortcutPath, [string]$TargetScript)
    $WshShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($ShortcutPath)
    $Shortcut.TargetPath = "powershell.exe"
    $Shortcut.Arguments = "-ExecutionPolicy Bypass -File `"$TargetScript`""
    $Shortcut.WorkingDirectory = Split-Path $TargetScript -Parent
    $Shortcut.Save()
}

function Test-IsAdmin {
    # Checks if current process is running as administrator
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Install-NetFx3WithElevation {
    # Checks and enables .NET Framework 3.5 with automatic elevation
    try {
        $netfx3 = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v3.5" -ErrorAction SilentlyContinue
        if ($netfx3.Version) {
            Write-Host ".NET Framework 3.5 (NetFx3) is already enabled." -ForegroundColor Green
            return $true
        }
    } catch { }
    Write-Host "Enabling .NET Framework 3.5 (NetFx3)..." -ForegroundColor Yellow
    if (-not (Test-IsAdmin)) {
        Write-Host "NetFx3 installation requires administrator privileges. Launching elevated process..." -ForegroundColor Yellow
        $ElevatedScript = {
            try {
                Enable-WindowsOptionalFeature -Online -FeatureName 'NetFx3' -All -NoRestart -ErrorAction Stop | Out-Null
                Write-Host ".NET Framework 3.5 enabled successfully" -ForegroundColor Green
                Start-Sleep 5
                exit 0
            } catch {
                Write-Error "Failed to enable NetFx3: $($_.Exception.Message)"
                Read-Host "Press Enter to close this window"
                exit 1
            }
        }
        $EncodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($ElevatedScript.ToString()))
        $Process = Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile", "-EncodedCommand", $EncodedCommand -Verb RunAs -Wait -PassThru
        if ($Process.ExitCode -eq 0) {
            Write-Host ".NET Framework 3.5 enabled successfully" -ForegroundColor Green
            return $true
        } else {
            Write-Warning "Failed to enable NetFx3. You may need to enable it manually."
            return $false
        }
    } else {
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
    # Installs or updates a package using winget with retry logic (3 attempts)
    param([string]$PackageName, [string]$PackageParameters = '')
    Write-Host "Ensuring $PackageName is installed..." -ForegroundColor Cyan
    $ListOutput = & winget list --id $PackageName --exact 2>&1
    if ($LASTEXITCODE -eq 0 -and $ListOutput -match $PackageName) {
        Write-Host "$PackageName is already installed" -ForegroundColor Green
        return
    }
    $MaxAttempts = 3
    for ($Attempt = 1; $Attempt -le $MaxAttempts; $Attempt++) {
        Write-Host "Installing $PackageName (attempt $Attempt of $MaxAttempts)..." -ForegroundColor Yellow
        $InstallArgs = @('install', '--id', $PackageName, '--exact', '--accept-source-agreements', '--accept-package-agreements')
        if ($Attempt -lt $MaxAttempts) { $InstallArgs += '--silent' }
        if ($PackageParameters) {
            $InstallArgs += '--override'
            $InstallArgs += $PackageParameters
        }
        & winget @InstallArgs
        if ($LASTEXITCODE -eq 0) {
            Write-Host "$PackageName installed successfully" -ForegroundColor Green
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            return
        }
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
    # Prompts the user to choose from a list of options. Returns the index of the selected option (0-based) or -1 if invalid.
    Param ([string[]]$Options, [int]$Default, [switch]$DontShortcutSingleChoice)
    if ($Options.Count -eq 0) { return -1 }
    if ($Options.Count -eq 1 -and (-not $DontShortcutSingleChoice)) { return 0 }
    for ($i = 0; $i -lt $Options.Count; $i++) {
        if ($i -eq $Default) { $Star = "*" } else { $Star = "" }
        Write-Host ("{0,5}: {1}" -f @(("{0}{1}" -f @($Star, ($i + 1))), $Options[$i]))
    }
    $Selection = Read-Host "Select an option [$($Default+1)]"
    if ($Selection -eq "") { return $Default }
    elseif ($Selection -match '^\d+$' -and $Selection -le $Options.Count -and $Selection -gt 0) {
        return ($Selection - 1)
    } else {
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
    $StandardPaths = @(
        'C:\Program Files (x86)\Epic Games\Launcher\Portal\Binaries\Win64\EpicGamesLauncher.exe',
        'C:\Program Files (x86)\Epic Games\Launcher\Portal\Binaries\Win32\EpicGamesLauncher.exe',
        'C:\Program Files\Epic Games\Launcher\Portal\Binaries\Win64\EpicGamesLauncher.exe'
    )
    foreach ($Path in $StandardPaths) {
        if (Test-Path $Path) { return $Path }
    }
    $WingetPackages = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages"
    if (Test-Path $WingetPackages) {
        $EpicDirs = Get-ChildItem -Path $WingetPackages -Filter "EpicGames.EpicGamesLauncher*" -Directory -ErrorAction SilentlyContinue
        foreach ($Dir in $EpicDirs) {
            $ExePath = Get-ChildItem -Path $Dir.FullName -Filter "EpicGamesLauncher.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($ExePath) { return $ExePath.FullName }
        }
    }
    $LocalPrograms = "$env:LOCALAPPDATA\Programs\Epic Games"
    if (Test-Path $LocalPrograms) {
        $ExePath = Get-ChildItem -Path $LocalPrograms -Filter "EpicGamesLauncher.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($ExePath) { return $ExePath.FullName }
    }
    return $null
}

# ----------------------------------------------------------------------------
# SyncThing Helper Functions
# ----------------------------------------------------------------------------

function Get-SyncThingExecutable {
    # Locates the Syncthing executable by checking PATH, winget locations, and program files
    $WherePath = & where.exe syncthing 2>$null | Select-Object -First 1
    if ($WherePath -and (Test-Path $WherePath)) { return $WherePath }
    $WingetPackages = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages"
    if (Test-Path $WingetPackages) {
        $SyncthingDirs = Get-ChildItem -Path $WingetPackages -Filter "Syncthing.Syncthing*" -Directory -ErrorAction SilentlyContinue
        foreach ($Dir in $SyncthingDirs) {
            $ExePath = Get-ChildItem -Path $Dir.FullName -Filter "syncthing.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($ExePath) { return $ExePath.FullName }
        }
    }
    $ProgramFilesPaths = @(
        "$env:ProgramFiles\Syncthing\syncthing.exe",
        "${env:ProgramFiles(x86)}\Syncthing\syncthing.exe"
    )
    foreach ($Path in $ProgramFilesPaths) {
        if (Test-Path $Path) { return $Path }
    }
    return $null
}

function Invoke-SyncThingCli {
    # Runs Syncthing CLI with common args
    param(
        [string]$SyncThingExe,
        [string]$SyncThingHome,
        [string]$GuiAddress,
        [string]$ApiKey,
        [Parameter(ValueFromRemainingArguments = $true)][string[]]$Args,
        [switch]$QuietErrors
    )
    $BaseArgs = @(
        "cli"
        "--home=$SyncThingHome"
        "--gui-address=$GuiAddress"
        "--gui-apikey=$ApiKey"
    )
    if ($QuietErrors) {
        return & $SyncThingExe @BaseArgs @Args 2>$null
    }
    return & $SyncThingExe @BaseArgs @Args
}

function Ensure-SyncThingRunning {
    # Ensures SyncThing is running, starts it if needed. Returns device ID and GUI address info.
    param([string]$WorkspaceRoot)
    $SyncThingExe = Get-SyncThingExecutable
    if (-not $SyncThingExe) {
        Write-Error "Syncthing executable not found. Please ensure Syncthing is installed."
        return $null
    }
    Write-Host "Found Syncthing at: $SyncThingExe" -ForegroundColor Gray
    $SyncThingHome = Join-Path $WorkspaceRoot "env\syncthing-home"
    if (-not (Test-Path $SyncThingHome)) {
        New-Item -ItemType Directory -Force -Path $SyncThingHome | Out-Null
    }
    $ConfigPath = Join-Path $SyncThingHome "config.xml"
    $ApiKeyFile = Join-Path $WorkspaceRoot "env\syncthing\api.key"
    $ApiKey = $null
    $GuiAddress = $null
    $IsFirstTime = $false
    if (Test-Path $ApiKeyFile) {
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
    if (-not $ApiKey) {
        $IsFirstTime = $true
        if (Test-Path $ConfigPath) {
            Write-Host "Removing existing SyncThing config for fresh initialization..." -ForegroundColor Yellow
            Remove-Item $ConfigPath -Force
        }
        $ApiKey = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 32 | ForEach-Object {[char]$_})
        $SyncThingEnvDir = Join-Path $WorkspaceRoot "env\syncthing"
        if (-not (Test-Path $SyncThingEnvDir)) {
            New-Item -ItemType Directory -Force -Path $SyncThingEnvDir | Out-Null
        }
        $SecureString = ConvertTo-SecureString $ApiKey -AsPlainText -Force
        $SecureString | ConvertFrom-SecureString | Set-Content $ApiKeyFile
        Write-Host "Generated and stored new SyncThing API key" -ForegroundColor Green
    }
    $PortFile = Join-Path $WorkspaceRoot ".que\syncthing\gui.port"
    $PortFileDir = Split-Path $PortFile -Parent
    if (-not (Test-Path $PortFileDir)) {
        New-Item -ItemType Directory -Force -Path $PortFileDir | Out-Null
    }
    if (Test-Path $PortFile) {
        try {
            $StoredPort = Get-Content $PortFile -Raw
            $StoredPort = $StoredPort.Trim()
            if ($StoredPort -match '^\d+$') {
                $GuiAddress = "127.0.0.1:$StoredPort"
                Write-Host "Using stored SyncThing port: $StoredPort" -ForegroundColor Gray
            }
        } catch {
            Write-Warning "Failed to read stored port: $($_.Exception.Message)"
        }
    }
    if (-not $GuiAddress) {
        $Port = Get-AvailableSyncThingPort
        $GuiAddress = "127.0.0.1:$Port"
        $Port | Set-Content $PortFile
        Write-Host "Generated and stored new SyncThing port: $Port" -ForegroundColor Green
    }
    $RawAddress = Invoke-SyncThingCli $SyncThingExe $SyncThingHome $GuiAddress $ApiKey -Args @("config", "gui", "raw-address", "get") -QuietErrors
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Starting SyncThing at $GuiAddress..." -ForegroundColor Cyan
        $StartArgs = @(
            "serve"
            "--home=$SyncThingHome"
            "--gui-address=$GuiAddress"
            "--gui-apikey=$ApiKey"
            "--unpaused"
            "--no-upgrade"
            "--no-browser"
        )
        Write-Host "$StartArgs"
        $StartProcessArgs = @{
            FilePath = $SyncThingExe
            ArgumentList = $StartArgs
            WindowStyle = 'Hidden'
        }
        Start-Process @StartProcessArgs
        Start-Sleep -Seconds 5
    } else {
        Write-Host "SyncThing already running at $RawAddress" -ForegroundColor Green
    }
    $DeviceIdList = Invoke-SyncThingCli $SyncThingExe $SyncThingHome $GuiAddress $ApiKey -Args @("config", "devices", "list") -QuietErrors
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
    # Initializes SyncThing for the workspace
    param([string]$WorkspaceRoot)
    $SyncThingInfo = Ensure-SyncThingRunning -WorkspaceRoot $WorkspaceRoot
    if (-not $SyncThingInfo) { throw "Failed to start SyncThing" }
    return $SyncThingInfo
}

function Configure-SyncThingFolders {
    # Configures SyncThing folders for git-lfs (with --ignore-delete flag) and depot (bidirectional)
    param([string]$WorkspaceRoot, [hashtable]$SyncThingInfo)
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
    $LfsPath = Join-Path $WorkspaceRoot "sync\git-lfs"
    $LfsFolderId = "$GitHubRepo-lfs"
    $LfsLabel = "$GitHubRepo Git LFS"
    Write-Host "Configuring SyncThing folder: $LfsLabel" -ForegroundColor Cyan
    Invoke-SyncThingCli $SyncThingExe $SyncThingHome $GuiAddress $ApiKey -Args @(
        "config"
        "folders"
        "add"
        "--id=$LfsFolderId"
        "--label=$LfsLabel"
        "--path=$LfsPath"
        "--ignore-delete"
    )
    # Add depot folder (bidirectional)
    $DepotPath = Join-Path $WorkspaceRoot "sync\depot"
    $DepotFolderId = "$GitHubRepo-depot"
    $DepotLabel = "$GitHubRepo Depot"
    Write-Host "Configuring SyncThing folder: $DepotLabel" -ForegroundColor Cyan
    Invoke-SyncThingCli $SyncThingExe $SyncThingHome $GuiAddress $ApiKey -Args @(
        "config"
        "folders"
        "add"
        "--id=$DepotFolderId"
        "--label=$DepotLabel"
        "--path=$DepotPath"
    )
    Write-Host "SyncThing folders configured successfully" -ForegroundColor Green
}

function Update-SyncThingDevices {
    # Adds known devices to SyncThing configuration and shares folders
    param([string]$WorkspaceRoot, [array]$DeviceIds, [hashtable]$SyncThingInfo)
    if ($DeviceIds.Count -eq 0) {
        Write-Host "No additional devices to configure" -ForegroundColor Yellow
        return
    }
    $SyncThingExe = Get-SyncThingExecutable
    if (-not $SyncThingExe) {
        Write-Error "Syncthing executable not found"
        return
    }
    $GitHubRepo = Get-Content "$WorkspaceRoot\.que\gh-repo-name"
    $SyncThingHome = Join-Path $WorkspaceRoot "env\syncthing-home"
    $GuiAddress = $SyncThingInfo.GuiAddress
    $ApiKey = $SyncThingInfo.ApiKey
    $LfsFolderId = "$GitHubRepo-lfs"
    $DepotFolderId = "$GitHubRepo-depot"
    $AllKnownDeviceIds = Invoke-SyncThingCli $SyncThingExe $SyncThingHome $GuiAddress $ApiKey -Args @("config", "devices", "list") -QuietErrors
    foreach ($DeviceId in $DeviceIds) {
        if ($DeviceId -and $AllKnownDeviceIds -notcontains $DeviceId) {
            Write-Host "Adding SyncThing peer: $DeviceId" -ForegroundColor Green
            Invoke-SyncThingCli $SyncThingExe $SyncThingHome $GuiAddress $ApiKey -Args @(
                "config"
                "devices"
                "add"
                "--device-id=$DeviceId"
                "--auto-accept-folders"
            )
            Write-Host "  Sharing git-lfs folder with peer" -ForegroundColor Cyan
            Invoke-SyncThingCli $SyncThingExe $SyncThingHome $GuiAddress $ApiKey -Args @(
                "config"
                "folders"
                $LfsFolderId
                "devices"
                "add"
                "--device-id=$DeviceId"
            ) -QuietErrors
            Write-Host "  Sharing depot folder with peer" -ForegroundColor Cyan
            Invoke-SyncThingCli $SyncThingExe $SyncThingHome $GuiAddress $ApiKey -Args @(
                "config"
                "folders"
                $DepotFolderId
                "devices"
                "add"
                "--device-id=$DeviceId"
            ) -QuietErrors
        } else {
            Write-Host "Device $DeviceId already configured, skipping" -ForegroundColor Gray
        }
    }
    Write-Host "SyncThing devices configured successfully" -ForegroundColor Green
}

function Wait-ForSyncThingLfsSync {
    # Waits for SyncThing to sync the git-lfs folder with a progress bar
    param(
        [string]$WorkspaceRoot,
        [int]$TimeoutSeconds = 300,
        [switch]$Silent
    )

    # Get SyncThing configuration (same paths as Ensure-SyncThingRunning)
    $SyncThingHome = Join-Path $WorkspaceRoot "env\syncthing-home"
    if (-not (Test-Path $SyncThingHome)) {
        if (-not $Silent) { Write-Host "SyncThing not configured, skipping sync wait" -ForegroundColor Yellow }
        return $true
    }

    $ApiKeyFile = Join-Path $WorkspaceRoot "env\syncthing\api.key"
    $PortFile = Join-Path $WorkspaceRoot ".que\syncthing\gui.port"

    if (-not (Test-Path $ApiKeyFile) -or -not (Test-Path $PortFile)) {
        if (-not $Silent) { Write-Host "SyncThing configuration incomplete, skipping sync wait" -ForegroundColor Yellow }
        return $true
    }

    try {
        # Decrypt the API key (stored as SecureString)
        $SecureString = Get-Content $ApiKeyFile | ConvertTo-SecureString
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
        $ApiKey = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)

        $Port = Get-Content $PortFile -Raw -ErrorAction Stop
        $Port = $Port.Trim()
        $GuiAddress = "127.0.0.1:$Port"
    } catch {
        if (-not $Silent) { Write-Host "Failed to read SyncThing config, skipping sync wait" -ForegroundColor Yellow }
        return $true
    }

    $GitHubRepo = Get-Content "$WorkspaceRoot\.que\gh-repo-name" -ErrorAction SilentlyContinue
    if (-not $GitHubRepo) {
        if (-not $Silent) { Write-Host "Cannot determine repository name, skipping sync wait" -ForegroundColor Yellow }
        return $true
    }

    $LfsFolderId = "$GitHubRepo-lfs"

    # Check if we need to wait at all
    $BaseUrl = "http://$GuiAddress/rest"
    $Headers = @{ "X-API-Key" = $ApiKey }

    try {
        # Get folder status to see if there are any out-of-sync items
        $StatusUrl = "$BaseUrl/db/status?folder=$LfsFolderId"
        $Status = Invoke-RestMethod -Uri $StatusUrl -Headers $Headers -Method Get -TimeoutSec 5 -ErrorAction Stop

        # Check if folder is already in sync
        if ($Status.needBytes -eq 0 -and $Status.needDeletes -eq 0 -and $Status.needFiles -eq 0) {
            if (-not $Silent) { Write-Host "LFS folder already in sync" -ForegroundColor Green }
            return $true
        }

        if (-not $Silent) {
            $needMB = [math]::Round($Status.needBytes / 1MB, 2)
            Write-Host "Waiting for SyncThing to sync LFS files ($($Status.needFiles) files, $needMB MB)..." -ForegroundColor Cyan
        }

        # Wait for sync with progress bar
        $StartTime = Get-Date
        $LastPercent = -1

        while (((Get-Date) - $StartTime).TotalSeconds -lt $TimeoutSeconds) {
            try {
                $Status = Invoke-RestMethod -Uri $StatusUrl -Headers $Headers -Method Get -TimeoutSec 5 -ErrorAction Stop

                # Calculate completion percentage
                if ($Status.globalBytes -gt 0) {
                    $Percent = [math]::Round((($Status.globalBytes - $Status.needBytes) / $Status.globalBytes) * 100, 1)
                } else {
                    $Percent = 100
                }

                # Show progress bar if percentage changed
                if ($Percent -ne $LastPercent -and -not $Silent) {
                    $ElapsedSeconds = [int]((Get-Date) - $StartTime).TotalSeconds
                    Write-Progress -Activity "Syncing LFS files via SyncThing" `
                                   -Status "$Percent% complete ($($Status.needFiles) files remaining)" `
                                   -PercentComplete $Percent `
                                   -SecondsRemaining (if ($Percent -gt 0) { [int]($ElapsedSeconds * (100 - $Percent) / $Percent) } else { -1 })
                    $LastPercent = $Percent
                }

                # Check if sync is complete
                if ($Status.needBytes -eq 0 -and $Status.needDeletes -eq 0 -and $Status.needFiles -eq 0) {
                    if (-not $Silent) {
                        Write-Progress -Activity "Syncing LFS files via SyncThing" -Completed
                        Write-Host "LFS sync complete" -ForegroundColor Green
                    }
                    return $true
                }

                Start-Sleep -Milliseconds 500
            } catch {
                # API call failed, likely SyncThing not running
                if (-not $Silent) {
                    Write-Progress -Activity "Syncing LFS files via SyncThing" -Completed
                    Write-Host "SyncThing API unavailable, proceeding without sync wait" -ForegroundColor Yellow
                }
                return $false
            }
        }

        # Timeout reached
        if (-not $Silent) {
            Write-Progress -Activity "Syncing LFS files via SyncThing" -Completed
            Write-Host "Sync wait timeout reached after $TimeoutSeconds seconds" -ForegroundColor Yellow
            Write-Host "Some LFS files may not be available yet" -ForegroundColor Yellow
        }
        return $false

    } catch {
        if (-not $Silent) { Write-Host "Failed to check SyncThing status: $($_.Exception.Message)" -ForegroundColor Yellow }
        return $false
    }
}

# Git Helper Functions

function Write-GitConfigFiles {
    # Writes repository-level Git configuration files (.gitattributes and .gitignore to repo root)
    param([string]$CloneRoot)
    Set-Content -Path "$CloneRoot\.gitattributes" -Value $EmbeddedGitAttributes
    Set-Content -Path "$CloneRoot\.gitignore" -Value $EmbeddedGitIgnore
}

function Write-UEGitConfigFiles {
    # Writes UE-specific Git configuration files alongside .uproject if they don't exist
    param([string]$CloneRoot)
    $UProjectPath = Find-UProjectFile -CloneRoot $CloneRoot
    if (-not $UProjectPath) { return }
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
    # Installs all dependencies required for Unreal Engine 5.7 development
    Write-Host "`nInstalling prerequisites for Unreal Engine 5.7..." -ForegroundColor Cyan
    Sync-WingetPackage -PackageName 'Git.Git'
    Sync-WingetPackage -PackageName 'Git.GCM'
    Sync-WingetPackage -PackageName 'EpicGames.EpicGamesLauncher'
    Sync-WingetPackage -PackageName 'Microsoft.DotNet.Framework.DeveloperPack_4'
    Install-NetFx3WithElevation | Out-Null
    & (where.exe git | Select-Object -First 1) lfs install | Out-Null
    Sync-WingetPackage -PackageName 'GitHub.GitLFS'
    Sync-WingetPackage -PackageName 'Syncthing.Syncthing'
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
    # Generates project-specific que57-project.ps1 script with marker-based substitution
    param([string]$CloneRoot, [string]$Owner, [string]$Repo, [string]$SyncThingDeviceId = "")
    $ThreeHashes = '###'
    $OutputPath = "$CloneRoot\que57-project.ps1"
    $ScriptContent = $queScript
    # Update constants section
    $ConstantsBlock = @"
$($ThreeHashes)QUE_CONSTANTS_BEGIN$($ThreeHashes)
`$UnrealEngineVersion = "5.7"
`$GitHubOwner = "$Owner"
`$GitHubRepo = "$Repo"
$($ThreeHashes)QUE_CONSTANTS_END$($ThreeHashes)
"@
    $ScriptContent = $ScriptContent -replace ('{0}QUE_CONSTANTS_BEGIN{0}[\s\S]*?{0}QUE_CONSTANTS_END{0}' -f @('###')), $ConstantsBlock
    # Add SyncThing devices section
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
    # Remove workspace creation code and embedded files
    $ScriptContent = $ScriptContent -replace ('{0}QUE_CREATION_MODE_BEGIN{0}[\s\S]*?{0}QUE_CREATION_MODE_END{0}' -f @($ThreeHashes)), ''
    $ScriptContent = $ScriptContent -replace ('{0}QUE_EMBEDDED_FILES_BEGIN{0}[\s\S]*?{0}QUE_EMBEDDED_FILES_END{0}' -f @($ThreeHashes)), ''
    # Uncomment management mode code
    $ScriptContent = $ScriptContent -replace ('<#{0}QUE_MANAGEMENT_MODE_BEGIN{0}' -f @($ThreeHashes)), ''
    $ScriptContent = $ScriptContent -replace ('#>{0}QUE_MANAGEMENT_MODE_END{0}' -f @($ThreeHashes)), ''
    Set-Content -Path $OutputPath -Value $ScriptContent
    Write-Host "Generated: $OutputPath" -ForegroundColor Green
}

# Workspace Creation Functions

function New-QueWorkspace {
    # Creates a new QUE workspace with initialization modes: blank, from GitHub, from local repo
    param([string]$GitHubOwner, [string]$GitHubRepo, [string]$PlainPAT, [object]$UserInfo)
    $WorkspaceRoot = (Get-Location).Path
    Write-Host "`nCreating QUE workspace for $GitHubOwner/$GitHubRepo..." -ForegroundColor Cyan
    Write-Host "`nCreating workspace structure..."
    New-Item -ItemType Directory -Force -Path ".que" | Out-Null
    New-Item -ItemType Directory -Force -Path ".que/repo" | Out-Null
    New-Item -ItemType Directory -Force -Path "sync/git-lfs/lfs" | Out-Null
    New-Item -ItemType Directory -Force -Path "sync/depot" | Out-Null
    New-Item -ItemType Directory -Force -Path "env/github" | Out-Null
    New-Item -ItemType Directory -Force -Path "env/syncthing-home" | Out-Null
    New-Item -ItemType Directory -Force -Path "repo" | Out-Null
    Set-Content -Path ".que/gh-repo-owner" -Value $GitHubOwner
    Set-Content -Path ".que/gh-repo-name" -Value $GitHubRepo
    Set-SecureGitHubPAT -PlainPAT $PlainPAT -WorkspaceRoot $WorkspaceRoot
    # Check if GitHub repo exists
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
    # Determine initialization mode
    $ShouldClone = $false
    $InitMode = 0  # 0 = blank, 1 = from other GitHub repo, 2 = from local, 3 = as part of existing GitHub repo
    if ($RepoExists) {
        $ShouldClone = $true
        $InitMode = 3
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
            0 { }
            1 {
                $SourceUrl = Read-Host "`nEnter GitHub project URL (e.g., https://github.com/owner/repo)"
                if ([string]::IsNullOrWhiteSpace($SourceUrl)) {
                    Write-Error "URL cannot be empty"
                    return
                }
                $CloneFromSource = $SourceUrl
            }
            2 {
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
    Install-AllDependencies
    Write-Host "`nInitializing SyncThing..." -ForegroundColor Cyan
    $SyncThingInfo = Initialize-SyncThing -WorkspaceRoot $WorkspaceRoot
    Write-Host "`nCreating first clone..." -ForegroundColor Cyan
    $CloneRoot = New-QueClone -WorkspaceRoot $WorkspaceRoot -IsFirstClone $true -ShouldClone $ShouldClone -UserInfo $UserInfo -PlainPAT $PlainPAT -SyncThingInfo $SyncThingInfo
    # Handle special initialization modes
    if ($InitMode -eq 0) {
        Write-Host "`nBlank project workspace created" -ForegroundColor Green
        Write-Host "Next steps:" -ForegroundColor Cyan
        Write-Host "  1. Create your Unreal Engine project in: $CloneRoot" -ForegroundColor White
        Write-Host "  2. Add and commit your files with git" -ForegroundColor White
        Write-Host "  3. Push to GitHub when ready" -ForegroundColor White
    } elseif ($InitMode -eq 1 -and $CloneFromSource) {
        Push-Location $CloneRoot
        git remote add source $CloneFromSource 2>&1 | ForEach-Object { "$_" } | Out-Host
        git fetch source 2>&1 | ForEach-Object { "$_" } | Out-Host
        git merge source/main --allow-unrelated-histories -m "Import from $CloneFromSource" 2>&1 | ForEach-Object { "$_" } | Out-Host
        git push origin main 2>&1 | ForEach-Object { "$_" } | Out-Host
        git remote remove source 2>&1 | ForEach-Object { "$_" } | Out-Host
        Pop-Location
        Write-Host "Imported from source repository into $CloneRoot" -ForegroundColor Green
    } elseif ($InitMode -eq 2 -and $CopyFromLocal) {
        $SourceFiles = Get-ChildItem $CopyFromLocal -Exclude ".git" -Force
        foreach ($File in $SourceFiles) {
            Copy-Item $File.FullName -Destination $CloneRoot -Recurse -Force
        }
        Push-Location $CloneRoot
        git add -A 2>&1 | ForEach-Object { "$_" } | Out-Host
        git commit -m "Import from local repository" 2>&1 | ForEach-Object { "$_" } | Out-Host
        git push origin main 2>&1 | ForEach-Object { "$_" } | Out-Host
        Pop-Location
        Write-Host "Imported from local repository into $CloneRoot" -ForegroundColor Green
    } elseif ($InitMode -eq 3) {
        # Wait for SyncThing to sync LFS files before pulling
        Wait-ForSyncThingLfsSync -WorkspaceRoot $WorkspaceRoot -TimeoutSeconds 300 | Out-Null
        Push-Location $CloneRoot
        git pull 2>&1 | ForEach-Object { "$_" } | Out-Host
        Pop-Location
        Write-Host "Pulled latest from repository into $CloneRoot" -ForegroundColor Green
    }
    Set-Content -Path ".que/workspace-version" -Value "1"
    Write-Host "`nWorkspace created successfully!" -ForegroundColor Green
}

function New-QueClone {
    # Creates a new clone in an existing workspace
    param(
        [string]$WorkspaceRoot,
        [bool]$IsFirstClone = $false,
        [bool]$ShouldClone = $false,
        [object]$UserInfo = $null,
        [string]$PlainPAT = $null,
        [hashtable]$SyncThingInfo = $null,
        [string]$CloneName = $null,
        [string]$SourcePath = $null
    )
    $GitHubOwner = Get-Content "$WorkspaceRoot\.que\gh-repo-owner"
    $GitHubRepo = Get-Content "$WorkspaceRoot\.que\gh-repo-name"
    if (-not $PlainPAT) {
        $PlainPAT = Get-SecureGitHubPAT -WorkspaceRoot $WorkspaceRoot
        $UserInfo = Test-GitHubPAT -PlainPAT $PlainPAT
        if (-not $UserInfo) {
            Write-Error "Failed to authenticate with stored PAT."
            return
        }
    }
    if (-not $SyncThingInfo) {
        Write-Host "Ensuring SyncThing is running..." -ForegroundColor Cyan
        $SyncThingInfo = Ensure-SyncThingRunning -WorkspaceRoot $WorkspaceRoot
    }
    if (-not $CloneName) {
        $CloneName = Get-NextCloneName -WorkspaceRoot $WorkspaceRoot
    }
    $CloneRoot = Join-Path $WorkspaceRoot "repo\$CloneName"
    Write-Host "Creating clone: $CloneName" -ForegroundColor Cyan
    New-Item -ItemType Directory -Force -Path $CloneRoot | Out-Null
    $CloneMetaPath = "$WorkspaceRoot\.que\repo\$CloneName"
    New-Item -ItemType Directory -Force -Path $CloneMetaPath | Out-Null
    Store-GitCredentials -Login $UserInfo.login -PlainPAT $PlainPAT
    if ($SourcePath) {
        if (-not (Test-Path $SourcePath)) {
            throw "Source path not found: $SourcePath"
        }
        Write-Host "Cloning from existing workspace state at $SourcePath..." -ForegroundColor Cyan
        $PreviousGitLfsSkipSmudge = $env:GIT_LFS_SKIP_SMUDGE
        $env:GIT_LFS_SKIP_SMUDGE = '1'
        Push-Location $CloneRoot
        git clone --no-hardlinks $SourcePath . 2>&1 | ForEach-Object { "$_" } | Out-Host
        if ($LASTEXITCODE -ne 0) {
            Pop-Location
            if ($null -ne $PreviousGitLfsSkipSmudge) {
                $env:GIT_LFS_SKIP_SMUDGE = $PreviousGitLfsSkipSmudge
            } else {
                Remove-Item env:GIT_LFS_SKIP_SMUDGE -ErrorAction SilentlyContinue
            }
            throw "git clone from $SourcePath failed with exit code $LASTEXITCODE"
        }
        if ($null -ne $PreviousGitLfsSkipSmudge) {
            $env:GIT_LFS_SKIP_SMUDGE = $PreviousGitLfsSkipSmudge
        } else {
            Remove-Item env:GIT_LFS_SKIP_SMUDGE -ErrorAction SilentlyContinue
        }
        git remote set-url origin "https://$($UserInfo.login)@github.com/$GitHubOwner/$GitHubRepo.git" 2>&1 | ForEach-Object { "$_" } | Out-Host
        git config --local user.name $UserInfo.name
        git config --local user.email ("{0}-{1}@users.noreply.github.com" -f @($UserInfo.id, $UserInfo.login))
        git config --local credential.username $UserInfo.login
        git config --local lfs.locksverify false
        git config --local push.autoSetupRemote true
        Pop-Location
        Write-Host "Clone complete. LFS pointer files created (objects will sync via SyncThing)" -ForegroundColor Yellow
        Write-UEGitConfigFiles -CloneRoot $CloneRoot
    } elseif ($ShouldClone) {
        Write-Host "Cloning $GitHubOwner/$GitHubRepo..." -ForegroundColor Cyan
        $PreviousGitLfsSkipSmudge = $env:GIT_LFS_SKIP_SMUDGE
        $env:GIT_LFS_SKIP_SMUDGE = '1'
        Push-Location $CloneRoot
        git clone "https://$($UserInfo.login)@github.com/$GitHubOwner/$GitHubRepo.git" . 2>&1 | ForEach-Object { "$_" } | Out-Host
        if ($LASTEXITCODE -ne 0) {
            Pop-Location
            throw "git clone failed with exit code $LASTEXITCODE"
        }
        if ($null -ne $PreviousGitLfsSkipSmudge) {
            $env:GIT_LFS_SKIP_SMUDGE = $PreviousGitLfsSkipSmudge
        } else {
            Remove-Item env:GIT_LFS_SKIP_SMUDGE -ErrorAction SilentlyContinue
        }
        Pop-Location
        Write-Host "Clone complete. LFS pointer files created (objects will sync via SyncThing)" -ForegroundColor Yellow
        Push-Location $CloneRoot
        git config --local user.name $UserInfo.name
        git config --local user.email ("{0}-{1}@users.noreply.github.com" -f @($UserInfo.id, $UserInfo.login))
        git config --local credential.username $UserInfo.login
        git config --local lfs.locksverify false
        git config --local push.autoSetupRemote true
        Pop-Location
        Write-UEGitConfigFiles -CloneRoot $CloneRoot
    } else {
        Write-Host "Initializing new repository..." -ForegroundColor Cyan
        Push-Location $CloneRoot
        git init -b main 2>&1 | ForEach-Object { "$_" } | Out-Host
        if ($LASTEXITCODE -ne 0) {
            Pop-Location
            throw "git init failed"
        }
        git config --local user.name $UserInfo.name
        git config --local user.email ("{0}-{1}@users.noreply.github.com" -f @($UserInfo.id, $UserInfo.login))
        git config --local credential.username $UserInfo.login
        git config --local lfs.locksverify false
        git config --local push.autoSetupRemote true
        git remote add origin "https://$($UserInfo.login)@github.com/$GitHubOwner/$GitHubRepo.git" 2>&1 | ForEach-Object { "$_" } | Out-Host
        Pop-Location
        Write-GitConfigFiles -CloneRoot $CloneRoot
        $ReadmeContent = $EmbeddedReadme -replace '{{OWNER}}', $GitHubOwner -replace '{{REPO}}', $GitHubRepo
        Set-Content -Path "$CloneRoot\README.md" -Value $ReadmeContent
        Write-Host "Generating que57-project.ps1..." -ForegroundColor Cyan
        $DeviceId = if ($SyncThingInfo) { $SyncThingInfo.DeviceId } else { "" }
        New-QueRepoScript -CloneRoot $CloneRoot -Owner $GitHubOwner -Repo $GitHubRepo -SyncThingDeviceId $DeviceId
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
    Push-Location $CloneRoot
    git lfs install --local 2>&1 | ForEach-Object { "$_" } | Out-Host
    $LfsStoragePath = Join-Path $WorkspaceRoot "sync\git-lfs\lfs"
    git config --local lfs.storage $LfsStoragePath
    Pop-Location
    $ShortcutPath = "$WorkspaceRoot\open-$CloneName.lnk"
    $TargetScript = "$CloneRoot\que57-project.ps1"
    New-WindowsShortcut -ShortcutPath $ShortcutPath -TargetScript $TargetScript
    Write-Host "Created shortcut: $ShortcutPath" -ForegroundColor Green
    Set-Content -Path "$CloneMetaPath\repo-version" -Value "1"
    return $CloneRoot
}

# ----------------------------------------------------------------------------
# MANAGEMENT COMMANDS (commented out in que57.ps1, active in que57-project.ps1)
# ----------------------------------------------------------------------------
<####QUE_MANAGEMENT_MODE_BEGIN###

# ----------------------------------------------------------------------------
# Que Git Workflow Helpers
# ----------------------------------------------------------------------------
if (-not $script:QueMainBranch) {
    $script:QueMainBranch = "main"
}
if (-not $script:QueDefaultPublishTag) {
    $script:QueDefaultPublishTag = "lkg"
}

function Get-QueCloneNameFromPath {
    param([string]$CloneRoot)
    return (Split-Path $CloneRoot -Leaf)
}

function Invoke-QueGit {
    param([string]$WorkingDir, [string[]]$GitArgs, [switch]$AllowFailure)
    if (-not (Test-Path $WorkingDir)) {
        throw "Working directory not found: $WorkingDir"
    }
    # Filter out null or empty arguments
    $FilteredArgs = @($GitArgs | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($FilteredArgs.Count -eq 0) {
        $CallStack = Get-PSCallStack | ForEach-Object { "  at $($_.Command) in $($_.ScriptName):$($_.ScriptLineNumber)" }
        throw "No git command specified (GitArgs was empty or contained only null/whitespace values)`nOriginal GitArgs count: $($GitArgs.Count), GitArgs: [$($GitArgs -join ', ')]`nCall stack:`n$($CallStack -join "`n")"
    }
    Push-Location $WorkingDir
    try {
        $Output = & git @FilteredArgs 2>&1
        $ExitCode = $LASTEXITCODE
    } finally {
        Pop-Location
    }
    if (-not $AllowFailure -and $ExitCode -ne 0) {
        throw "git $($FilteredArgs -join ' ') failed with exit code $ExitCode`n$($Output -join "`n")"
    }
    return [pscustomobject]@{
        ExitCode = $ExitCode
        Output = @($Output)
        Command = $FilteredArgs -join ' '
    }
}

function Get-QueCurrentBranch {
    param([string]$CloneRoot)
    $Result = Invoke-QueGit -WorkingDir $CloneRoot -GitArgs @("rev-parse", "--abbrev-ref", "HEAD")
    return ($Result.Output | Select-Object -First 1)
}

function Invoke-QueMerge {
    param([string]$CloneRoot, [string]$Source, [string]$Message)
    $MergeResult = Invoke-QueGit -WorkingDir $CloneRoot -GitArgs @("merge", "--no-ff", $Source, "-m", $Message) -AllowFailure
    if ($MergeResult.ExitCode -ne 0) {
        throw "Merge from $Source resulted in conflicts. Resolve them, commit, and rerun the command.`n$($MergeResult.Output -join "`n")"
    }
    return $MergeResult
}

function Invoke-QuePushWithRetry {
    param([string]$CloneRoot, [string]$Branch, [int]$MaxAttempts = 3)
    $DelaySeconds = 2
    for ($Attempt = 1; $Attempt -le $MaxAttempts; $Attempt++) {
        $PushResult = Invoke-QueGit -WorkingDir $CloneRoot -GitArgs @("push", "-u", "origin", $Branch) -AllowFailure
        if ($PushResult.ExitCode -eq 0) {
            return $PushResult
        }
        if ($Attempt -eq $MaxAttempts) {
            throw "Push failed after $MaxAttempts attempts.`n$($PushResult.Output -join "`n")"
        }
        Write-Host "Push rejected; merging origin/$($script:QueMainBranch) then retrying (attempt $($Attempt + 1) of $MaxAttempts)..." -ForegroundColor Yellow
        Invoke-QueGit -WorkingDir $CloneRoot -GitArgs @("fetch", "origin", $script:QueMainBranch)
        Invoke-QueMerge -CloneRoot $CloneRoot -Source ("origin/{0}" -f $script:QueMainBranch) -Message ("que: merge origin/{0}" -f $script:QueMainBranch)
        Start-Sleep -Seconds $DelaySeconds
        $DelaySeconds = [Math]::Min($DelaySeconds * 2, 30)
    }
}

function Invoke-QueStashAll {
    param([string]$CloneRoot, [string]$Reason)
    $Message = "que: $Reason"
    Invoke-QueGit -WorkingDir $CloneRoot -GitArgs @("stash", "push", "-u", "-m", $Message) -AllowFailure | Out-Null
}

function Invoke-QueSaveCommand {
    param([string]$CloneRoot)
    $CloneName = Get-QueCloneNameFromPath -CloneRoot $CloneRoot
    $CurrentBranch = Get-QueCurrentBranch -CloneRoot $CloneRoot
    if ($CurrentBranch -eq $script:QueMainBranch) {
        # Wait for SyncThing to sync LFS files before switching branches
        $WorkspaceRoot = Find-QueWorkspace -StartPath $CloneRoot
        if ($WorkspaceRoot) {
            Wait-ForSyncThingLfsSync -WorkspaceRoot $WorkspaceRoot -TimeoutSeconds 300 | Out-Null
        }
        $WorkBranch = "que/$CloneName"
        $Existing = Invoke-QueGit -WorkingDir $CloneRoot -GitArgs @("show-ref", "--verify", "refs/heads/$WorkBranch") -AllowFailure
        if ($Existing.ExitCode -eq 0) {
            Invoke-QueGit -WorkingDir $CloneRoot -GitArgs @("switch", $WorkBranch) | Out-Null
        } else {
            Invoke-QueGit -WorkingDir $CloneRoot -GitArgs @("switch", "-c", $WorkBranch) | Out-Null
        }
        $CurrentBranch = $WorkBranch
    }
    Invoke-QueGit -WorkingDir $CloneRoot -GitArgs @("add", "-A") | Out-Null
    $Status = Invoke-QueGit -WorkingDir $CloneRoot -GitArgs @("status", "--porcelain") -AllowFailure
    $HasChanges = $Status.Output | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    if ($HasChanges) {
        $CommitMessage = "que: save $CloneName"
        $CommitResult = Invoke-QueGit -WorkingDir $CloneRoot -GitArgs @("commit", "-m", $CommitMessage) -AllowFailure
        if ($CommitResult.ExitCode -ne 0 -and -not ($CommitResult.Output -join ' ' -match 'nothing to commit')) {
            throw "Commit failed: $($CommitResult.Output -join "`n")"
        }
    } else {
        Write-Host "No changes to commit; pushing to ensure upstream exists." -ForegroundColor Gray
    }
    Invoke-QuePushWithRetry -CloneRoot $CloneRoot -Branch $CurrentBranch | Out-Null
    return $CurrentBranch
}

function Invoke-QueLoadCommand {
    param([string]$WorkspaceRoot, [string]$SourceCloneRoot, [string]$Name, [switch]$SkipLaunch = $false)
    if (-not $Name) { throw "Branch name is required for 'que load'." }
    $BranchName = "que/$Name"
    $ExistingCloneRoot = $null
    $RepoDir = Join-Path $WorkspaceRoot "repo"
    if (Test-Path $RepoDir) {
        foreach ($CloneDir in Get-ChildItem $RepoDir -Directory) {
            $ClonePath = $CloneDir.FullName
            $HasBranch = $false
            $LocalBranchCheck = Invoke-QueGit -WorkingDir $ClonePath -GitArgs @("show-ref", "--verify", "refs/heads/$BranchName") -AllowFailure
            if ($LocalBranchCheck.ExitCode -eq 0) {
                $HasBranch = $true
            } else {
                $CurrentBranch = Invoke-QueGit -WorkingDir $ClonePath -GitArgs @("rev-parse", "--abbrev-ref", "HEAD") -AllowFailure
                if ($CurrentBranch.ExitCode -eq 0 -and ($CurrentBranch.Output | Select-Object -First 1) -eq $BranchName) {
                    $HasBranch = $true
                }
            }
            if ($HasBranch) {
                $ExistingCloneRoot = $ClonePath
                break
            }
        }
    }
    if ($ExistingCloneRoot) {
        $ExistingCloneName = Split-Path $ExistingCloneRoot -Leaf
        $ShortcutPath = Join-Path $WorkspaceRoot "open-$ExistingCloneName.lnk"
        if ((-not $SkipLaunch) -and (Test-Path $ShortcutPath)) {
            Start-Process -FilePath $ShortcutPath | Out-Null
        } else {
            Write-Host "Found existing clone for $BranchName at $ExistingCloneRoot" -ForegroundColor Green
        }
        return $ExistingCloneRoot
    }
    if (-not $SourceCloneRoot) {
        throw "A source clone path is required for 'que load'."
    }
    $RemoteCheck = Invoke-QueGit -WorkingDir $SourceCloneRoot -GitArgs @("ls-remote", "--exit-code", "origin", $BranchName) -AllowFailure
    if ($RemoteCheck.ExitCode -ne 0) {
        throw "Work branch $BranchName does not exist on origin."
    }
    $TargetClonePath = Join-Path $WorkspaceRoot "repo\$Name"
    if (Test-Path $TargetClonePath) {
        $CurrentBranch = Invoke-QueGit -WorkingDir $TargetClonePath -GitArgs @("rev-parse", "--abbrev-ref", "HEAD") -AllowFailure
        $CurrentBranchName = if ($CurrentBranch.ExitCode -eq 0) { $CurrentBranch.Output | Select-Object -First 1 } else { "(unknown)" }
        throw "Clone path already exists at $TargetClonePath (current branch: $CurrentBranchName). Please open that clone or choose a different branch name."
    }
    Write-Host "Loading $BranchName into a new clone..." -ForegroundColor Cyan
    $CloneRoot = Invoke-QueNewCommand -WorkspaceRoot $WorkspaceRoot -CloneName $Name -SkipLaunch
    Invoke-QueGit -WorkingDir $CloneRoot -GitArgs @("fetch", "origin", $BranchName) | Out-Null
    $SwitchResult = Invoke-QueGit -WorkingDir $CloneRoot -GitArgs @("switch", "-c", $BranchName, "--track", "origin/$BranchName") -AllowFailure
    if ($SwitchResult.ExitCode -ne 0) {
        throw "Failed to switch clone to $BranchName.`n$($SwitchResult.Output -join "`n")"
    }
    Write-Host "Loaded $BranchName into clone $(Split-Path $CloneRoot -Leaf)" -ForegroundColor Green
    $ShortcutPath = Join-Path $WorkspaceRoot "open-$((Split-Path $CloneRoot -Leaf)).lnk"
    if ((-not $SkipLaunch) -and (Test-Path $ShortcutPath)) {
        Start-Process -FilePath $ShortcutPath | Out-Null
    }
    return $CloneRoot
}

function Invoke-QueImportCommand {
    param([string]$CloneRoot, [string]$Name)
    if (-not $Name) { throw "Branch name is required for 'que import'." }
    $CurrentBranch = Get-QueCurrentBranch -CloneRoot $CloneRoot
    if ($CurrentBranch -eq $script:QueMainBranch) {
        $CurrentBranch = Invoke-QueSaveCommand -CloneRoot $CloneRoot
    }
    $SourceBranch = "que/$Name"
    Invoke-QueGit -WorkingDir $CloneRoot -GitArgs @("fetch", "origin", $SourceBranch) | Out-Null
    $RemoteCheck = Invoke-QueGit -WorkingDir $CloneRoot -GitArgs @("show-ref", "--verify", "refs/remotes/origin/$SourceBranch") -AllowFailure
    if ($RemoteCheck.ExitCode -ne 0) {
        throw "Work branch $SourceBranch not found on origin."
    }
    Invoke-QueMerge -CloneRoot $CloneRoot -Source ("origin/$SourceBranch") -Message ("que: import {0}" -f $SourceBranch) | Out-Null
    Write-Host "Imported $SourceBranch into $CurrentBranch" -ForegroundColor Green
}

function Invoke-QueUpdateCommand {
    param([string]$CloneRoot)
    # Wait for SyncThing to sync LFS files before pulling/merging
    $WorkspaceRoot = Find-QueWorkspace -StartPath $CloneRoot
    if ($WorkspaceRoot) {
        Wait-ForSyncThingLfsSync -WorkspaceRoot $WorkspaceRoot -TimeoutSeconds 300 | Out-Null
    }
    $CurrentBranch = Get-QueCurrentBranch -CloneRoot $CloneRoot
    if ($CurrentBranch -eq $script:QueMainBranch) {
        Invoke-QueGit -WorkingDir $CloneRoot -GitArgs @("pull", "--no-rebase", "origin", $script:QueMainBranch) | Out-Null
    } else {
        Invoke-QueGit -WorkingDir $CloneRoot -GitArgs @("fetch", "origin", $script:QueMainBranch) | Out-Null
        Invoke-QueMerge -CloneRoot $CloneRoot -Source ("origin/$($script:QueMainBranch)") -Message ("que: merge origin/{0}" -f $script:QueMainBranch) | Out-Null
    }
    return $CurrentBranch
}

function Invoke-QueRenameCommand {
    param([string]$CloneRoot, [string]$Name)
    if (-not $Name) { throw "New branch name is required for 'que rename'." }
    $CurrentBranch = Get-QueCurrentBranch -CloneRoot $CloneRoot
    if ($CurrentBranch -eq $script:QueMainBranch) {
        throw "Cannot rename the main branch."
    }
    $NewBranch = "que/$Name"
    if ($CurrentBranch -eq $NewBranch) {
        Write-Host "Branch already named $NewBranch" -ForegroundColor Gray
        return $NewBranch
    }
    $OldBranch = $CurrentBranch
    Invoke-QueGit -WorkingDir $CloneRoot -GitArgs @("branch", "-m", $NewBranch) | Out-Null
    Invoke-QuePushWithRetry -CloneRoot $CloneRoot -Branch $NewBranch | Out-Null
    Invoke-QueGit -WorkingDir $CloneRoot -GitArgs @("push", "origin", ":$OldBranch") -AllowFailure | Out-Null
    Write-Host "Renamed $OldBranch to $NewBranch locally and on origin." -ForegroundColor Green
    return $NewBranch
}

function Invoke-QueResetCommand {
    param([string]$CloneRoot)
    # Wait for SyncThing to sync LFS files before switching branches
    $WorkspaceRoot = Find-QueWorkspace -StartPath $CloneRoot
    if ($WorkspaceRoot) {
        Wait-ForSyncThingLfsSync -WorkspaceRoot $WorkspaceRoot -TimeoutSeconds 300 | Out-Null
    }
    Invoke-QueGit -WorkingDir $CloneRoot -GitArgs @("rebase", "--abort") -AllowFailure | Out-Null
    Invoke-QueGit -WorkingDir $CloneRoot -GitArgs @("merge", "--abort") -AllowFailure | Out-Null
    Invoke-QueGit -WorkingDir $CloneRoot -GitArgs @("cherry-pick", "--abort") -AllowFailure | Out-Null
    Invoke-QueStashAll -CloneRoot $CloneRoot -Reason "reset"
    Invoke-QueGit -WorkingDir $CloneRoot -GitArgs @("switch", $script:QueMainBranch) | Out-Null
    Invoke-QueGit -WorkingDir $CloneRoot -GitArgs @("fetch", "origin", $script:QueMainBranch) | Out-Null
    Invoke-QueGit -WorkingDir $CloneRoot -GitArgs @("reset", "--hard", "origin/$($script:QueMainBranch)") | Out-Null
    Write-Host "Reset to origin/$($script:QueMainBranch). Local changes stashed." -ForegroundColor Green
}

function Invoke-QuePublishCommand {
    param([string]$CloneRoot, [string]$TagName)
    $WorkBranch = Invoke-QueSaveCommand -CloneRoot $CloneRoot
    Invoke-QueUpdateCommand -CloneRoot $CloneRoot | Out-Null
    $CurrentBranch = Get-QueCurrentBranch -CloneRoot $CloneRoot
    if ($CurrentBranch -eq $script:QueMainBranch) {
        $WorkBranch = $script:QueMainBranch
    } else {
        $WorkBranch = $CurrentBranch
    }
    Invoke-QueGit -WorkingDir $CloneRoot -GitArgs @("switch", $script:QueMainBranch) | Out-Null
    Invoke-QueGit -WorkingDir $CloneRoot -GitArgs @("pull", "--no-rebase", "origin", $script:QueMainBranch) | Out-Null
    Invoke-QueMerge -CloneRoot $CloneRoot -Source $WorkBranch -Message ("que: publish {0}" -f $WorkBranch) | Out-Null
    Invoke-QuePushWithRetry -CloneRoot $CloneRoot -Branch $script:QueMainBranch | Out-Null

    # Push LFS objects to GitHub for disaster recovery
    Write-Host "Publishing LFS files to GitHub for backup..." -ForegroundColor Cyan
    Push-Location $CloneRoot
    try {
        # Check if there are any LFS files to push
        $LfsFiles = git lfs ls-files 2>&1
        if ($LASTEXITCODE -eq 0 -and $LfsFiles) {
            Write-Host "Uploading LFS objects to GitHub (this provides disaster recovery)..." -ForegroundColor Yellow
            git lfs push --all origin 2>&1 | ForEach-Object {
                if ($_ -match "Uploading|Upload|Counting|^Git LFS:") {
                    Write-Host "  $_" -ForegroundColor Gray
                }
            }
            if ($LASTEXITCODE -eq 0) {
                Write-Host "LFS objects backed up to GitHub successfully" -ForegroundColor Green
            } else {
                Write-Host "Warning: LFS push encountered issues (exit code: $LASTEXITCODE)" -ForegroundColor Yellow
                Write-Host "Pointer files were published, but some LFS objects may not be backed up to GitHub" -ForegroundColor Yellow
            }
        } else {
            Write-Host "No LFS files to back up" -ForegroundColor Gray
        }
    } catch {
        Write-Host "Warning: Failed to push LFS objects: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "Continuing - pointer files were published successfully" -ForegroundColor Yellow
    } finally {
        Pop-Location
    }

    if ($TagName) {
        Invoke-QueGit -WorkingDir $CloneRoot -GitArgs @("tag", "-f", $TagName) | Out-Null
        Invoke-QueGit -WorkingDir $CloneRoot -GitArgs @("push", "-f", "origin", $TagName) | Out-Null
        Write-Host "Moved tag $TagName to $script:QueMainBranch and pushed." -ForegroundColor Green
    }
    return $WorkBranch
}

function Invoke-QueNewCommand {
    param([string]$WorkspaceRoot, [string]$CloneName = $null, [switch]$SkipLaunch = $false)
    Write-Host "Creating new clone from origin/$($script:QueMainBranch)..." -ForegroundColor Cyan
    $CloneRoot = New-QueClone -WorkspaceRoot $WorkspaceRoot -IsFirstClone:$false -ShouldClone:$true -CloneName $CloneName
    $Name = Split-Path $CloneRoot -Leaf
    $ShortcutPath = Join-Path $WorkspaceRoot "open-$Name.lnk"
    if ((-not $SkipLaunch) -and (Test-Path $ShortcutPath)) {
        Start-Process -FilePath $ShortcutPath | Out-Null
    }
    return $CloneRoot
}

function Invoke-QueCloneCommand {
    param([string]$WorkspaceRoot, [string]$SourceCloneRoot, [string]$CloneName = $null, [switch]$SkipLaunch = $false)
    if (-not $SourceCloneRoot) {
        throw "A source clone path is required for 'que clone'."
    }
    Write-Host "Cloning current branch state into a new workspace clone..." -ForegroundColor Cyan
    $CloneRoot = New-QueClone -WorkspaceRoot $WorkspaceRoot -IsFirstClone:$false -CloneName $CloneName -SourcePath $SourceCloneRoot
    $Name = Split-Path $CloneRoot -Leaf
    $ShortcutPath = Join-Path $WorkspaceRoot "open-$Name.lnk"
    if ((-not $SkipLaunch) -and (Test-Path $ShortcutPath)) {
        Start-Process -FilePath $ShortcutPath | Out-Null
    }
    return $CloneRoot
}

# ----------------------------------------------------------------------------
# Unreal Engine Helper Functions
# ----------------------------------------------------------------------------

function Get-UnrealProjectEngineVersion {
    param([string]$UProjectPath)
    if (Test-Path $UProjectPath -PathType Container) {
        $UProjectPath = Find-UProjectFile -CloneRoot $UProjectPath
        if (-not $UProjectPath) { throw "No .uproject file found in directory" }
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
    Write-Host "Performing manual cleanup..." -ForegroundColor Cyan
    $FoldersToDelete = @("Binaries", "Intermediate", "Saved", "DerivedDataCache")
    foreach ($Folder in $FoldersToDelete) {
        $FolderPath = Join-Path $ProjectDir $Folder
        if (Test-Path $FolderPath) {
            Write-Host "Deleting $Folder..." -ForegroundColor Yellow
            Remove-Item $FolderPath -Recurse -Force
        }
    }
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
    param([string]$CloneRoot)
    Write-Host "`nOpening Unreal Engine project..." -ForegroundColor Cyan
    $UProjectPath = Find-UProjectFile -CloneRoot $CloneRoot
    if (-not $UProjectPath) {
        Write-Error "No .uproject file found. Please create your Unreal project first."
        return
    }
    Write-Host "Generating project files..."
    try {
        Invoke-UnrealGenerate -UProjectPath $UProjectPath
    } catch {
        Write-Error "Project file generation failed: $($_.Exception.Message)"
        return
    }
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
    Write-Host "Launching Unreal Editor..."
    try {
        Invoke-UnrealEditor -UProjectPath $UProjectPath
        Write-Host "Editor launched successfully!" -ForegroundColor Green
    } catch {
        Write-Error "Failed to launch editor: $($_.Exception.Message)"
    }
}

function Build-UnrealProject {
    param([string]$CloneRoot)
    Write-Host "`nBuilding Unreal Engine project..." -ForegroundColor Cyan
    $UProjectPath = Find-UProjectFile -CloneRoot $CloneRoot
    if (-not $UProjectPath) {
        Write-Error "No .uproject file found."
        return
    }
    Write-Host "Generating project files..."
    try {
        Invoke-UnrealGenerate -UProjectPath $UProjectPath
    } catch {
        Write-Error "Project file generation failed: $($_.Exception.Message)"
        return
    }
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
    param([string]$CloneRoot)
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
    param([string]$CloneRoot)
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

function Open-SyncThingBrowser {
    param([string]$WorkspaceRoot)
    $SyncThingHome = "$WorkspaceRoot\.que\syncthing"
    $SyncThingExe = Get-SyncThingExecutable
    if (-not $SyncThingExe) {
        Write-Host "SyncThing executable not found" -ForegroundColor Red
        return
    }
    & $SyncThingExe browser --home="$SyncThingHome"
}

function Show-WorkspaceInfo {
    param([string]$WorkspaceRoot, [string]$CloneRoot)
    $CloneName = Split-Path $CloneRoot -Leaf
    Write-Host "`n===============================================================" -ForegroundColor Cyan
    Write-Host "  QUE Workspace Information" -ForegroundColor Green
    Write-Host "===============================================================" -ForegroundColor Cyan
    Write-Host "`nWorkspace:" -ForegroundColor Yellow
    Write-Host "  Root: $WorkspaceRoot"
    Write-Host "  Version: $(Get-Content "$WorkspaceRoot\.que\workspace-version" -ErrorAction SilentlyContinue)"
    Write-Host "`nClone:" -ForegroundColor Yellow
    Write-Host "  Name: $CloneName"
    Write-Host "  Root: $CloneRoot"
    $RepoVersion = Get-Content "$WorkspaceRoot\.que\repo\$CloneName\repo-version" -ErrorAction SilentlyContinue
    Write-Host "  Version: $(if ($RepoVersion) { $RepoVersion } else { 'Not set' })"
    Write-Host "`nGitHub:" -ForegroundColor Yellow
    Write-Host "  Repository: $script:GitHubOwner/$script:GitHubRepo"
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
    $UProjectPath = Find-UProjectFile -CloneRoot $CloneRoot
    if ($UProjectPath) {
        Write-Host "`nUnreal Engine:" -ForegroundColor Yellow
        Write-Host "  Project: $UProjectPath"
        Write-Host "  Version: $script:UnrealEngineVersion"
    } else {
        Write-Host "`nUnreal Engine:" -ForegroundColor Yellow
        Write-Host "  No .uproject file found"
    }
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

function Show-QueHelp {
    param([string]$DefaultPublishTag)
    Write-Host "`nAvailable commands:" -ForegroundColor Cyan
    Write-Host "  help                     - Show this help text"
    Write-Host "  open                     - Generate project files, build, and launch the editor"
    Write-Host "  build                    - Build the editor target"
    Write-Host "  clean                    - Remove intermediates for a clean rebuild"
    Write-Host "  package                  - Package client/server builds"
    Write-Host "  syncthing                - Open the SyncThing web UI"
    Write-Host "  info                     - Display workspace and clone info"
    Write-Host "  new [name]               - Create a new clone from origin/main"
    Write-Host "  clone [name]             - Duplicate the current clone's state"
    Write-Host "  save                     - Commit/push current branch (creates que/<clone> if on main)"
    Write-Host "  load <branch>            - Load branch que/<branch> into a clone (reuses existing if present)"
    Write-Host "  import <branch>          - Merge origin/que/<branch> into the current branch"
    Write-Host "  update                   - Merge latest origin/main into the current branch"
    Write-Host "  rename <branch>          - Rename current work branch to que/<branch>"
    Write-Host "  reset                    - Stash changes and reset to origin/main"
    Write-Host "  publish [tag=$DefaultPublishTag] - Publish current work into main and tag it"
    Write-Host "  exit                     - Close the QUE session`n"
}
#>###QUE_MANAGEMENT_MODE_END###

# ----------------------------------------------------------------------------
# MAIN EXECUTION FUNCTION
# ----------------------------------------------------------------------------
function Invoke-QueMain {
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
        $UrlOwner = $null
        $UrlRepo = $null
        $IsBootstrapScript = $false
        if ($queUrl -match 'githubusercontent\.com/([^/]+)/([^/]+)/[^/]+/(.+)$') {
            $UrlOwner = $matches[1]
            $UrlRepo = $matches[2]
            $ScriptName = $matches[3]
            if ($ScriptName -eq 'que57.ps1') {
                $IsBootstrapScript = $true
            }
        }
        # Early check: If current folder is not empty and not a QUE workspace, error immediately
        $CurrentFolderIsQueWorkspace = Test-Path ".que"
        if (-not $CurrentFolderIsQueWorkspace) {
            $CurrentItems = Get-ChildItem -Force -ErrorAction SilentlyContinue
            if ($CurrentItems.Count -gt 0) {
                Write-Error "Current folder is not empty. QUE workspace must be initialized in an empty folder."
                Write-Host "Please create and navigate to an empty folder, then run this command again." -ForegroundColor Yellow
                return
            }
        }
        $WorkspaceRoot = Find-QueWorkspace
        if ($WorkspaceRoot) {
            $ExistingOwner = Get-Content "$WorkspaceRoot\.que\gh-repo-owner"
            $ExistingRepo = Get-Content "$WorkspaceRoot\.que\gh-repo-name"
            if ($UrlOwner -and $UrlRepo -and -not $IsBootstrapScript) {
                if ($ExistingOwner -eq $UrlOwner -and $ExistingRepo -eq $UrlRepo) {
                    Write-Host "Found matching workspace at: $WorkspaceRoot" -ForegroundColor Green
                    New-QueClone -WorkspaceRoot $WorkspaceRoot -ShouldClone $true
                } else {
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
                Write-Host "Setting up a new project workspace...`n" -ForegroundColor Green
                $CurrentFolderName = Split-Path $WorkspaceRoot -Leaf
                $DefaultRepoName = $CurrentFolderName -replace '[^a-zA-Z0-9_-]', ''
                $GitHubRepo = Read-Host "Enter new repository name [$DefaultRepoName]"
                if ([string]::IsNullOrWhiteSpace($GitHubRepo)) {
                    $GitHubRepo = $DefaultRepoName
                }
                if ([string]::IsNullOrWhiteSpace($GitHubRepo)) {
                    Write-Error "Repository name cannot be empty"
                    return
                }
                Write-Host "Using repository name: $GitHubRepo" -ForegroundColor Green
                $SecurePAT = Read-Host "Enter GitHub Personal Access Token" -AsSecureString
                $PlainPAT = [System.Net.NetworkCredential]::new('', $SecurePAT).Password
                $UserInfo = Test-GitHubPAT -PlainPAT $PlainPAT
                if (-not $UserInfo) {
                    Write-Error "Invalid GitHub PAT. Please check your token and try again."
                    return
                }
                Write-Host "Authenticated as: $($UserInfo.login)" -ForegroundColor Green
                $GitHubOwner = $UserInfo.login
                New-QueWorkspace -GitHubOwner $GitHubOwner -GitHubRepo $GitHubRepo -PlainPAT $PlainPAT -UserInfo $UserInfo
                ###QUE_CREATION_MODE_END###
            } elseif ($UrlOwner -and $UrlRepo) {
                Write-Host "Joining project: $UrlOwner/$UrlRepo`n" -ForegroundColor Green
                if ($quePlainPAT) {
                    $PlainPAT = $quePlainPAT
                } else {
                    $SecurePAT = Read-Host "Enter GitHub Personal Access Token" -AsSecureString
                    $PlainPAT = [System.Net.NetworkCredential]::new('', $SecurePAT).Password
                }
                $UserInfo = Test-GitHubPAT -PlainPAT $PlainPAT
                if (-not $UserInfo) {
                    Write-Error "Invalid GitHub PAT. Please check your token and try again."
                    return
                }
                Write-Host "Authenticated as: $($UserInfo.login)" -ForegroundColor Green
                New-QueWorkspace -GitHubOwner $UrlOwner -GitHubRepo $UrlRepo -PlainPAT $PlainPAT -UserInfo $UserInfo
            } else {
                Write-Error "Cannot determine repository information from URL: $queUrl"
                return
            }
        }
    } else {
        # MODE 3: DIRECT EXECUTION - Management Terminal
        if ($IsDirectExecution) {
            $WorkspaceRoot = Find-QueWorkspace
            if (-not $WorkspaceRoot) {
                Write-Error "Not in a QUE workspace. Run this script via iex (iwr ...) to create one."
                return
            }
            Write-Host "Ensuring SyncThing is running..." -ForegroundColor Cyan
            $SyncThingInfo = Ensure-SyncThingRunning -WorkspaceRoot $WorkspaceRoot
            $CurrentDeviceId = $SyncThingInfo.DeviceId
            if ((-not [string]::IsNullOrWhiteSpace($CurrentDeviceId)) -and $script:SyncThingDevices -and ($script:SyncThingDevices -notcontains $CurrentDeviceId)) {
                Write-Host "Adding current device to SyncThing devices list..." -ForegroundColor Yellow
                Write-Host "DEBUG: Current device ID: $CurrentDeviceId" -ForegroundColor Magenta
                Write-Host "DEBUG: SyncThingDevices before adding: $($script:SyncThingDevices -join ', ')" -ForegroundColor Magenta
                Write-Host "DEBUG: Count before: $($script:SyncThingDevices.Count)" -ForegroundColor Magenta
                $script:SyncThingDevices += $CurrentDeviceId
                Write-Host "DEBUG: SyncThingDevices after adding: $($script:SyncThingDevices -join ', ')" -ForegroundColor Magenta
                Write-Host "DEBUG: Count after: $($script:SyncThingDevices.Count)" -ForegroundColor Magenta
                $ScriptPath = $PSCommandPath
                $ScriptContent = Get-Content $ScriptPath -Raw
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
            if ($script:SyncThingDevices -and $script:SyncThingDevices.Count -gt 0) {
                Update-SyncThingDevices -WorkspaceRoot $WorkspaceRoot -DeviceIds $script:SyncThingDevices -SyncThingInfo $SyncThingInfo
            }
            $ScriptPath = $PSCommandPath
            $CloneRoot = Split-Path $ScriptPath -Parent
            $CloneName = Split-Path $CloneRoot -Leaf
            Write-UEGitConfigFiles -CloneRoot $CloneRoot
            Write-Host "`n===============================================================" -ForegroundColor Cyan
            Write-Host "  QUE - $script:GitHubOwner/$script:GitHubRepo" -ForegroundColor Green
            Write-Host "  Clone: $CloneName" -ForegroundColor Yellow
            Write-Host "  Workspace: $WorkspaceRoot" -ForegroundColor Gray
            Write-Host "===============================================================`n" -ForegroundColor Cyan
            while ($true) {
                Write-Host "Commands: " -NoNewline -ForegroundColor White
                Write-Host "open, build, clean, package, syncthing, info, new, clone, save, load, import, update, rename, reset, publish, help, exit" -ForegroundColor Gray
                $RawCommand = Read-Host "`nQUE>"
                $Tokens = $RawCommand.Trim().Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries)
                if (-not $Tokens -or $Tokens.Count -eq 0) { continue }
                $Command = $Tokens[0].ToLower()
                $Arg1 = if ($Tokens.Count -gt 1) { $Tokens[1] } else { $null }
                try {
                    switch ($Command) {
                        "open"      { Open-UnrealProject -CloneRoot $CloneRoot }
                        "build"     { Build-UnrealProject -CloneRoot $CloneRoot }
                        "clean"     { Clean-UnrealProject -CloneRoot $CloneRoot }
                        "package"   { Package-UnrealProject -CloneRoot $CloneRoot }
                        "syncthing" { Open-SyncThingBrowser -WorkspaceRoot $WorkspaceRoot }
                        "info"      { Show-WorkspaceInfo -WorkspaceRoot $WorkspaceRoot -CloneRoot $CloneRoot }
                        "new"       { Invoke-QueNewCommand -WorkspaceRoot $WorkspaceRoot -CloneName $Arg1 | Out-Null }
                        "clone"     { Invoke-QueCloneCommand -WorkspaceRoot $WorkspaceRoot -SourceCloneRoot $CloneRoot -CloneName $Arg1 | Out-Null }
                        "save"      { Invoke-QueSaveCommand -CloneRoot $CloneRoot | Out-Null }
                        "load"      { Invoke-QueLoadCommand -WorkspaceRoot $WorkspaceRoot -SourceCloneRoot $CloneRoot -Name $Arg1 | Out-Null }
                        "import"    { Invoke-QueImportCommand -CloneRoot $CloneRoot -Name $Arg1 | Out-Null }
                        "update"    { Invoke-QueUpdateCommand -CloneRoot $CloneRoot | Out-Null }
                        "rename"    { Invoke-QueRenameCommand -CloneRoot $CloneRoot -Name $Arg1 | Out-Null }
                        "reset"     { Invoke-QueResetCommand -CloneRoot $CloneRoot | Out-Null }
                        "publish"   {
                            $TagName = $Arg1
                            Invoke-QuePublishCommand -CloneRoot $CloneRoot -TagName $TagName | Out-Null
                        }
                        "help"      { Show-QueHelp -DefaultPublishTag $script:QueDefaultPublishTag }
                        "exit"      { return }
                        ""          { continue }
                        default     { Write-Host "Unknown command: $RawCommand. Type 'help' for a list of commands." -ForegroundColor Red }
                    }
                } catch {
                    Write-Host $_.Exception.Message -ForegroundColor Red
                }
            }
        }
    }
}

# ----------------------------------------------------------------------------
# SCRIPT ENTRY POINT
# ----------------------------------------------------------------------------
$IsDotSourced = $MyInvocation.InvocationName -eq '.'
if (-not $IsDotSourced) {
    Invoke-QueMain
}

