#Requires -Version 5.1

# Enable TLS 1.2 support for the git host API
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072

# ============================================================================
# QUE 5.7 - Quick Unreal Engine Project Manager
# ============================================================================
# Repository: https://github.com/karlgluck/que
# Target: Unreal Engine 5.7
#
# ARCHITECTURE:
# This is a single-file tool with 3 execution modes determined at runtime:
#   Mode 1 (dot-sourced): Exports functions only, no side effects.
#   Mode 2 (iex from URL): Bootstrap/installer. Creates workspaces and clones.
#     Generates que-project.ps1 by regex-replacing marker sections in itself.
#   Mode 3 (direct execution): Management session. Injects `que` function +
#     tab completion into PS session, then returns to normal prompt.
#
# SELF-REWRITE: Sections between ###QUE_*_BEGIN### / ###QUE_*_END### markers
# are replaced at generation time. The script can also rewrite its own
# SyncThing device list at runtime (Mode 3).
#
# TOKEN BUDGET: This script is designed to fit in ~20k tokens for single-pass
# LLM processing. Keep it concise. Use short helper names (WG/WC/WY/WR/WW).
# ============================================================================

# ----------------------------------------------------------------------------
# CONSTANTS - Edit these when customizing for your project
# ----------------------------------------------------------------------------
###QUE_CONSTANTS_BEGIN###
$QueUnrealEngineVersion = "5.7"
$QueForgeHost = "github.com"
# (Other constants will be dynamically substituted)
###QUE_CONSTANTS_END###

# ----------------------------------------------------------------------------
# GIT HOST - github.com or any Forgejo/Gitea server. Everything host-specific
# is derived here; nothing else in the script names a host.
# ----------------------------------------------------------------------------
function Initialize-QueForgeConfig {
    param([string]$ForgeHost)
    if ([string]::IsNullOrWhiteSpace($ForgeHost)) { $ForgeHost = 'github.com' }
    $ForgeHost = ($ForgeHost.Trim().ToLowerInvariant() -replace '^https?://', '' -replace '/.*$', '')
    $script:QueForgeHost = $ForgeHost
    $script:QueIsGitHub = ($ForgeHost -eq 'github.com')
    if ($script:QueIsGitHub) {
        $script:QueForgeLabel = 'GitHub'
        $script:QueApiBase = 'https://api.github.com'
        $script:QueRawUrlFormat = 'https://raw.githubusercontent.com/{0}/{1}/main/{2}'
        $script:QueTokenHelpUrl = 'https://github.com/settings/tokens'
        $script:QueTokenScopesHelp = "'repo' (all)"
    } else {
        $script:QueForgeLabel = $ForgeHost
        $script:QueApiBase = "https://$ForgeHost/api/v1"
        $script:QueRawUrlFormat = "https://$ForgeHost/{0}/{1}/raw/branch/main/{2}"
        $script:QueTokenHelpUrl = "https://$ForgeHost/user/settings/applications"
        $script:QueTokenScopesHelp = "write:repository, read:user (plus write:user to create repositories)"
    }
    $script:QueCloneUrlFormat = "https://{0}@$ForgeHost/{1}/{2}.git"
}
Initialize-QueForgeConfig -ForgeHost $QueForgeHost
function Get-QueCloneUrl($Login, $Owner, $Repo) { return ($script:QueCloneUrlFormat -f $Login, $Owner, $Repo) }
function Import-QueWorkspaceForge($WorkspaceRoot) {
    # Workspaces remember their host in .que/forge-host; older workspaces have no file and mean GitHub.
    $HostFile = Join-Path $WorkspaceRoot ".que\forge-host"
    $StoredHost = if (Test-Path $HostFile) { (Get-Content $HostFile | Select-Object -First 1) } else { $null }
    Initialize-QueForgeConfig -ForgeHost $StoredHost
}
function Expand-QueReadme($Owner, $Repo) {
    $RawUrl = $script:QueRawUrlFormat -f $Owner, $Repo, 'que-project.ps1'
    return ($EmbeddedReadme -replace '{{OWNER}}', $Owner -replace '{{REPO}}', $Repo -replace '{{HOST}}', $script:QueForgeHost -replace '{{HOST_LABEL}}', $script:QueForgeLabel -replace '{{RAW_URL}}', $RawUrl -replace '{{TOKEN_URL}}', $script:QueTokenHelpUrl -replace '{{TOKEN_SCOPES}}', $script:QueTokenScopesHelp)
}
function Write-QueTokenError {
    Write-Error "Invalid $script:QueForgeLabel token. Check the token and its scopes ($script:QueTokenScopesHelp)."
    if (-not $script:QueIsGitHub) {
        WY "If $script:QueForgeHost requires two-factor auth, a token only works after you have signed in on the website, set your password and enrolled 2FA."
    }
}

# ----------------------------------------------------------------------------
# EMBEDDED FILES
# ----------------------------------------------------------------------------
###QUE_EMBEDDED_FILES_BEGIN###
$EmbeddedGitAttributes = @'
*.uasset filter=lfs diff=lfs merge=lfs -text
*.umap filter=lfs diff=lfs merge=lfs -text
*.upk filter=lfs diff=lfs merge=lfs -text
*.udk filter=lfs diff=lfs merge=lfs -text
*.dll filter=lfs diff=lfs merge=lfs -text
*.exe filter=lfs diff=lfs merge=lfs -text
*.pdb filter=lfs diff=lfs merge=lfs -text
*.so filter=lfs diff=lfs merge=lfs -text
*.dylib filter=lfs diff=lfs merge=lfs -text
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
*.fbx filter=lfs diff=lfs merge=lfs -text
*.obj filter=lfs diff=lfs merge=lfs -text
*.blend filter=lfs diff=lfs merge=lfs -text
*.3ds filter=lfs diff=lfs merge=lfs -text
'@
$EmbeddedGitIgnore = @'
env/
.vs/
*.suo
*.user
*.userosscache
*.sln.docstates
*.userprefs
*.sln.ide/
.vscode/
*.code-workspace
Thumbs.db
ehthumbs.db
Desktop.ini
$RECYCLE.BIN/
.DS_Store
.AppleDouble
.LSOverride
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
2. Get your {{HOST_LABEL}} access token (see below)
3. Run this command in PowerShell:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ($queScript = (iwr -useb -Headers @{Authorization = "token $($queToken = [System.Net.NetworkCredential]::new('', (Read-Host 'Enter access token' -AsSecureString)).Password; $queToken)"} -Uri ($queUrl = "{{RAW_URL}}")).Content)
```

3. Follow the prompts to:
   - Enter your {{HOST_LABEL}} access token
   - Install dependencies (Git, GitLFS, SyncThing, Visual Studio Build Tools)
   - Install Unreal Engine 5.7 via Epic Games Launcher
   - Clone the repository

4. Launch the environment using the generated shortcut

**Note:** During setup, you may see a UAC prompt for .NET Framework 3.5 installation - this is required for Unreal Engine build tools.

## Prerequisites

- Windows 10/11
- PowerShell 5.1 or later
- An access token for {{HOST}} with scopes: {{TOKEN_SCOPES}}

## Getting an access token

1. Go to {{TOKEN_URL}}
2. Create a new token with scopes: {{TOKEN_SCOPES}}
3. Copy the token; you will paste it during setup

## Management Commands

Once your workspace is set up, launch the management terminal using `que-project.ps1`:

- **open** - Generate project files, build, and launch UE editor
- **build** - Build the editor target
- **clean** - Delete intermediate files for full rebuild
- **package** - Create standalone builds
- **deps** - Install or repair prerequisites (MSVC toolchain, Unreal Engine)
- **info** - Display workspace information

## Project Structure

```
workspace-root/
+-- .que/                    # Workspace metadata
+-- sync/                    # SyncThing-managed folders
|   +-- git-lfs/lfs/         # Shared LFS storage
|   +-- depot/               # Shared asset depot
+-- env/                     # Environment data (token, SyncThing)
+-- repo/                    # Repository clones
    +-- kauilani/            # Clone directory (random name)
        +-- que-project.ps1 # Project management script
```

**Clone Naming:** Each clone gets a unique Hawaiian-sounding name (e.g., Kauilani, Mahalo, Wakena) to make the randomness more pleasant and easily recognized. Its work branch is `que/<your login>/<name>`, so it is easy to see whose branches are whose. A name you choose works the same way: `que clone aurelia` and `que clone karl/aurelia` both make `repo/aurelia` on `que/karl/aurelia` for the user karl. Another owner's prefix stays in the folder name with dashes for slashes (`que load gaston/foo` makes `repo/gaston-foo`).

## How It Works

**Git LFS + SyncThing:** Large binary files are stored in Git LFS but synchronized across team members using SyncThing instead of downloading from the git server. This provides faster syncing and reduces bandwidth costs. During initial clone, LFS pointer files are created but actual objects sync via SyncThing in the background.

**Persistent SyncThing Port:** SyncThing uses a consistent port (stored in `.que/syncthing/gui.port`) to ensure the same instance is detected and reused across script runs.

## About QUE

QUE is a single-file PowerShell solution for managing Unreal Engine projects with Git, GitLFS, and SyncThing integration. Learn more at https://github.com/karlgluck/que
'@
# Written over an older project script name (e.g. que57-project.ps1) by Update-QueRepoScript
$QueLegacyStub = @'
# This clone's project script is now que-project.ps1. Shortcuts, older sessions and old join
# one-liners still use this name, so this file updates the workspace and hands over to que-project.ps1.
if (-not $PSScriptRoot) {
    # Run from an old join one-liner: fetch que-project.ps1 from the same place and run that instead
    if (-not $queToken) { $queToken = $quePlainPAT }
    Remove-Variable -Name quePlainPAT -ErrorAction SilentlyContinue
    $queUrl = $queUrl -replace '[^/]+$', 'que-project.ps1'
    $queScript = (Invoke-WebRequest -UseBasicParsing -Headers @{ Authorization = "token $queToken" } -Uri $queUrl -ErrorAction Stop).Content
    Invoke-Expression $queScript
    return
}
& {
    $Workspace = $PSScriptRoot
    while ($Workspace -and -not (Test-Path (Join-Path $Workspace '.que'))) {
        $Parent = Split-Path $Workspace -Parent
        $Workspace = if ($Parent -ne $Workspace) { $Parent } else { $null }
    }
    if (-not $Workspace) { return }
    # Workspaces made before que 15e9702 keep their details under older names; copy them to the current ones
    foreach ($Pair in @(@('.que\gh-repo-owner', '.que\forge-owner'), @('.que\gh-repo-name', '.que\forge-repo'), @('.que\gh-host', '.que\forge-host'), @('env\github\pat.dat', 'env\forge\token.dat'))) {
        $From = Join-Path $Workspace $Pair[0]
        $To = Join-Path $Workspace $Pair[1]
        if ((Test-Path $From) -and -not (Test-Path $To)) {
            New-Item -ItemType Directory -Force -Path (Split-Path $To -Parent) | Out-Null
            Copy-Item $From $To
            Write-Host "Copied $($Pair[0]) to $($Pair[1])" -ForegroundColor Yellow
        }
    }
    # Point shortcuts that open this file at que-project.ps1
    $Shell = New-Object -ComObject WScript.Shell
    $NewScript = Join-Path $PSScriptRoot 'que-project.ps1'
    Get-ChildItem -Path $Workspace -Filter 'open-*.lnk' -File | ForEach-Object {
        $Link = $Shell.CreateShortcut($_.FullName)
        if ($Link.Arguments -match [regex]::Escape($PSCommandPath)) {
            $Link.Arguments = $Link.Arguments -replace [regex]::Escape($PSCommandPath), $NewScript.Replace('$', '$$')
            $Link.Save()
            Write-Host "Shortcut $($_.Name) now opens que-project.ps1" -ForegroundColor Yellow
        }
    }
}
if ($MyInvocation.InvocationName -eq '.') { . (Join-Path $PSScriptRoot 'que-project.ps1') } else { & (Join-Path $PSScriptRoot 'que-project.ps1') @args }
'@
###QUE_EMBEDDED_FILES_END###

$EmbeddedUEGitAttributes = @'
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
$EmbeddedUEGitIgnore = @'
Binaries/
Build/
DerivedDataCache/
Intermediate/
Saved/
Script/
.vs/
*.VC.db
*.opensdf
*.opendb
*.sdf
*.sln
*.suo
*.xcodeproj
*.xcworkspace
*.com
*.class
*.dll
*.exe
*.o
*.so
Plugins/*/Binaries/
Plugins/*/Intermediate/
*.VC.VC.opendb
'@

# ----------------------------------------------------------------------------
# SYNCTHING DEVICES (only in que-project.ps1)
# ----------------------------------------------------------------------------
###QUE_SYNCTHING_BEGIN###
# $SyncThingDevices = @()  # Embedded in que-project.ps1 only (array of device IDs)
###QUE_SYNCTHING_END###

# ----------------------------------------------------------------------------
# HELPER FUNCTIONS
# ----------------------------------------------------------------------------

# Short color output helpers to reduce verbosity
function WG($m){Write-Host $m -ForegroundColor Green}
function WC($m){Write-Host $m -ForegroundColor Cyan}
function WY($m){Write-Host $m -ForegroundColor Yellow}
function WW($m){Write-Host $m -ForegroundColor White}
function WR($m){Write-Host $m -ForegroundColor Red}

# Read plaintext from a SecureString file
function Read-SecureFile($Path) {
    $ss = Get-Content $Path | ConvertTo-SecureString
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ss)
    $plain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    return $plain
}

# Configure local git settings for a QUE clone
function Set-QueGitConfig($UserInfo) {
    git config --local user.name $UserInfo.name
    $Email = if ($script:QueIsGitHub) { "{0}@users.noreply.github.com" -f @($UserInfo.login) } elseif ($UserInfo.email) { $UserInfo.email } else { "{0}@{1}" -f @($UserInfo.login, $script:QueForgeHost) }
    git config --local user.email $Email
    git config --local credential.username $UserInfo.login
    git config --local lfs.locksverify false
    git config --local push.autoSetupRemote true
}

function Find-QueWorkspace {
    # Searches current and parent directories for .que folder. Returns workspace root path or $null if not found.
    $CurrentPath = Get-Location
    $Path = $CurrentPath
    while ($Path) {
        $QuePath = Join-Path $Path ".que"
        if (Test-Path $QuePath) {
            $OwnerFile = Join-Path $QuePath "forge-owner"
            $RepoFile = Join-Path $QuePath "forge-repo"
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

function Get-SecureForgeToken {
    # Reads and decrypts the forge access token from env/forge/token.dat
    param([string]$WorkspaceRoot)
    $TokenFile = Join-Path $WorkspaceRoot "env\forge\token.dat"
    if (-not (Test-Path $TokenFile)) { return $null }
    try {
        return Read-SecureFile $TokenFile
    } catch {
        Write-Warning "Failed to decrypt token: $($_.Exception.Message)"
        return $null
    }
}

function Set-SecureForgeToken {
    # Encrypts and stores the forge access token to env/forge/token.dat
    param([string]$Token, [string]$WorkspaceRoot)
    $EnvDir = Join-Path $WorkspaceRoot "env\forge"
    if (-not (Test-Path $EnvDir)) {
        New-Item -ItemType Directory -Force -Path $EnvDir | Out-Null
    }
    $TokenFile = Join-Path $WorkspaceRoot "env\forge\token.dat"
    $SecureString = ConvertTo-SecureString $Token -AsPlainText -Force
    $SecureString | ConvertFrom-SecureString | Set-Content $TokenFile
}

function Store-GitCredentials {
    # Stores Git credentials in Windows Credential Manager
    param([string]$Login, [string]$Token)
    $env:GCM_INTERACTIVE = "never"
    @"
protocol=https
host=$($script:QueForgeHost)
username=$Login
password=$Token
"@  | git credential-manager store
}

function Test-ForgeToken {
    # Tests an access token by calling the host API /user
    # Returns user info object or $null if invalid
    # IMPORTANT: The email field from API should NOT be used for git config
    param([string]$Token)
    try {
        $AuthHeaders = @{
            Authorization = "token $Token"
            'Cache-Control' = 'no-store'
        }
        $Response = Invoke-WebRequest -Uri "$script:QueApiBase/user" -Headers $AuthHeaders -UseBasicParsing -ErrorAction Stop
        if ($Response.StatusCode -eq 200) {
            return ($Response.Content | ConvertFrom-Json)
        }
    } catch {
        return $null
    }
    return $null
}

function Test-ForgeRepoEmpty {
    # Returns $true if the repo exists but has no commits
    param([string]$Owner, [string]$Repo, [string]$Token, [int]$Retry = 3)
    try {
        $AuthHeaders = @{Authorization=@('token ', $Token) -join ''; 'Cache-Control'='no-store'}
        $CommitsUrl = "$script:QueApiBase/repos/$Owner/$Repo/commits?per_page=1&limit=1"
        $Response = Invoke-WebRequest -UseBasicParsing -Uri $CommitsUrl -Headers $AuthHeaders -Method Get -ErrorAction Stop
        if ($Response.StatusCode -eq 200) {
            $Content = $Response.Content
            if (-not $Content -or $Content.Trim() -eq "[]") { return $true }
            return $false
        }
    } catch {
        $StatusCode = $null
        if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
            $StatusCode = [int]$_.Exception.Response.StatusCode
        }
        if ($StatusCode -eq 409) {
            # Forgejo/Gitea flip the empty flag about a second after the first push; re-check once
            if ($Retry -gt 0 -and -not $script:QueIsGitHub) {
                Start-Sleep -Seconds 1
                return (Test-ForgeRepoEmpty -Owner $Owner -Repo $Repo -Token $Token -Retry ($Retry - 1))
            }
            return $true # Git Repository is empty
        }
        if ($StatusCode -eq 404) { return $false }
        Write-Warning "Failed to check if repository has commits: $($_.Exception.Message)"
        return $false
    }
    return $false
}

function Ensure-ForgeRepoExists {
    # Creates the repo on the git host if it does not exist
    param([string]$Owner, [string]$Repo, [string]$Token, [object]$UserInfo)
    try {
        $AuthHeaders = @{Authorization=@('token ', $Token) -join ''; 'Cache-Control'='no-store'}
        $RepoUrl = "$script:QueApiBase/repos/$Owner/$Repo"
        $Response = Invoke-WebRequest -UseBasicParsing -Uri $RepoUrl -Headers $AuthHeaders -Method Get -ErrorAction Stop
        if ($Response.StatusCode -eq 200) { return $true }
    } catch {
        $StatusCode = $null
        if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
            $StatusCode = [int]$_.Exception.Response.StatusCode
        }
        if ($StatusCode -ne 404) {
            Write-Error "Failed to check if repository exists: $($_.Exception.Message)"
            return $false
        }
    }
    WC "`nCreating $script:QueForgeLabel repository $Owner/$Repo..."
    try {
        $AuthHeaders = @{Authorization=@('token ', $Token) -join ''; 'Cache-Control'='no-store'}
        $CreateRepoBody = @{
            name = $Repo
            private = $true
            auto_init = $false
        } | ConvertTo-Json
        $CreateUrl = if ($Owner -eq $UserInfo.login) {
            "$script:QueApiBase/user/repos"
        } else {
            "$script:QueApiBase/orgs/$Owner/repos"
        }
        Invoke-WebRequest -UseBasicParsing -Uri $CreateUrl -Headers $AuthHeaders -Method Post -Body $CreateRepoBody -ContentType "application/json" | Out-Null
        WG "Repository created successfully"
        return $true
    } catch {
        Write-Error "Failed to create repository: $($_.Exception.Message)"
        Write-Error "Verify your token has $script:QueTokenScopesHelp and you can create repos in $Owner"
        return $false
    }
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

function Resolve-QueCloneName {
    # Maps a clone or branch name as typed (aurelia, karl/aurelia, gaston/foo, que/gaston/foo, origin/que/gaston/foo)
    # to its work branch and clone folder. Work branches are que/<owner>/<name>: a bare name gets $Login as
    # its owner, while a name typed with que/ is taken as written. The folder drops the owner when it is
    # $Login and joins any remaining segments with dashes (karl/aurelia -> aurelia, gaston/foo -> gaston-foo).
    # Returns $null if the name cannot be a branch and a folder.
    param([string]$Name, [string]$Login)
    if ([string]::IsNullOrWhiteSpace($Name)) { return $null }
    $Path = $Name.Trim() -replace '\\', '/'
    $IsExplicit = $Path -match '^(origin/)?que/'
    $Path = $Path -replace '^origin/', '' -replace '^que/', ''
    [string[]]$Segments = @($Path -split '/' | Where-Object { $_ })
    if ($Segments.Count -eq 0) { return $null }
    foreach ($Segment in $Segments) {
        if ($Segment -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$' -or $Segment -match '\.\.' -or $Segment -like '*.lock') { return $null }
    }
    $IsBare = (-not $IsExplicit) -and $Segments.Count -eq 1
    if ($IsBare -and $Login) { $Segments = @($Login) + $Segments }
    $FolderSegments = if ($Login -and $Segments.Count -gt 1 -and $Segments[0] -eq $Login) { $Segments[1..($Segments.Count - 1)] } else { $Segments }
    return [pscustomobject]@{
        WorkBranch = 'que/' + ($Segments -join '/')
        Folder     = $FolderSegments -join '-'
        IsBare     = $IsBare
    }
}

function Get-QueLogin {
    # The forge login this clone works as (set by Set-QueGitConfig), or $null
    param([string]$CloneRoot)
    $Result = Invoke-QueGit -WorkingDir $CloneRoot -GitArgs @("config", "--get", "credential.username") -AllowFailure
    if ($Result.ExitCode -ne 0) { return $null }
    $Login = "$($Result.Output | Select-Object -First 1)".Trim()
    if ($Login) { return $Login }
    return $null
}

function Get-QueDefaultWorkBranch {
    # The branch a clone goes to when it is on main: que/<login>/<clone folder>
    param([string]$CloneRoot)
    return (Resolve-QueCloneName -Name (Split-Path $CloneRoot -Leaf) -Login (Get-QueLogin -CloneRoot $CloneRoot)).WorkBranch
}

function Find-UProjectFile {
    # Finds .uproject file in clone directory. Returns full path or $null.
    param([string]$CloneRoot)
    $Exclude = @('Samples', 'Templates', 'Binaries', 'Intermediate', 'Saved')
    $UProjects = @(Get-ChildItem -Path $CloneRoot -Recurse -Filter "*.uproject" -ErrorAction SilentlyContinue |
        Where-Object { $Rel = $_.FullName.Substring($CloneRoot.Length + 1); -not ($Exclude | Where-Object { $Rel.StartsWith("$_\") }) })
    if ($UProjects.Count -eq 0) { return $null }
    if ($UProjects.Count -gt 1) {
        Write-Warning "Multiple .uproject files found. Using first one: $($UProjects[0].FullName)"
        Write-Warning "Other .uproject files found: $(($UProjects[1..($UProjects.Count - 1)] | ForEach-Object { $_.FullName }) -join ', ')"
    }
    return $UProjects[0].FullName
}

function New-WindowsShortcut {
    # Creates a Windows .lnk shortcut file that launches PowerShell script
    param([string]$ShortcutPath, [string]$TargetScript)
    $WshShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($ShortcutPath)
    $Shortcut.TargetPath = "powershell.exe"
    # Dot-source directly in the -NoExit session. Wrapping it in & { } would scope every helper
    # function and script variable to the block, leaving only the global 'que' stub behind.
    $Shortcut.Arguments = "-ExecutionPolicy Bypass -NoExit -Command `"`$QueLaunchSession = `$true; . '$TargetScript'`""
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
            WG ".NET Framework 3.5 (NetFx3) is already enabled."
            return $true
        }
    } catch { }
    WY "Enabling .NET Framework 3.5 (NetFx3)..."
    if (-not (Test-IsAdmin)) {
        WY "NetFx3 installation requires administrator privileges. Launching elevated process..."
        $ElevatedScript = {
            try {
                Enable-WindowsOptionalFeature -Online -FeatureName 'NetFx3' -All -NoRestart -ErrorAction Stop | Out-Null
                WG ".NET Framework 3.5 enabled successfully"
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
            WG ".NET Framework 3.5 enabled successfully"
            return $true
        } else {
            Write-Warning "Failed to enable NetFx3. You may need to enable it manually."
            return $false
        }
    } else {
        try {
            Enable-WindowsOptionalFeature -Online -FeatureName 'NetFx3' -All -NoRestart -ErrorAction Stop | Out-Null
            WG ".NET Framework 3.5 enabled successfully"
            return $true
        } catch {
            Write-Warning "Failed to enable NetFx3: $($_.Exception.Message)"
            return $false
        }
    }
}

function Sync-WingetPackage {
    # Installs or updates a package using winget with retry logic (3 attempts)
    param([string]$PackageName, [string]$PackageParameters = '', [string]$Version = '')
    WC "Ensuring $PackageName is installed..."
    $ListOutput = & winget list --id $PackageName --exact --accept-source-agreements 2>&1
    if ($LASTEXITCODE -eq 0 -and (($ListOutput -join "`n") -match [regex]::Escape($PackageName))) {
        WG "$PackageName is already installed"
        return
    }
    $MaxAttempts = 3
    for ($Attempt = 1; $Attempt -le $MaxAttempts; $Attempt++) {
        WY "Installing $PackageName (attempt $Attempt of $MaxAttempts)..."
        $InstallArgs = @('install', '--id', $PackageName, '--exact', '--accept-source-agreements', '--accept-package-agreements')
        if ($Attempt -lt $MaxAttempts) { $InstallArgs += '--silent' }
        if ($Version) { $InstallArgs += @('--version', $Version) }
        if ($PackageParameters) {
            $InstallArgs += '--override'
            $InstallArgs += $PackageParameters
        }
        & winget @InstallArgs
        if ($LASTEXITCODE -eq 0) {
            WG "$PackageName installed successfully"
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
            $ApiKey = Read-SecureFile $ApiKeyFile
            Write-Host "Using existing SyncThing API key" -ForegroundColor Gray
        } catch {
            Write-Warning "Failed to decrypt API key: $($_.Exception.Message)"
            $ApiKey = $null
        }
    }
    if (-not $ApiKey) {
        $IsFirstTime = $true
        if (Test-Path $ConfigPath) {
            WY "Removing existing SyncThing config for fresh initialization..."
            Remove-Item $ConfigPath -Force
        }
        $ApiKey = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 32 | ForEach-Object {[char]$_})
        $SyncThingEnvDir = Join-Path $WorkspaceRoot "env\syncthing"
        if (-not (Test-Path $SyncThingEnvDir)) {
            New-Item -ItemType Directory -Force -Path $SyncThingEnvDir | Out-Null
        }
        $SecureString = ConvertTo-SecureString $ApiKey -AsPlainText -Force
        $SecureString | ConvertFrom-SecureString | Set-Content $ApiKeyFile
        WG "Generated and stored new SyncThing API key"
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
        WG "Generated and stored new SyncThing port: $Port"
    }
    $RawAddress = Invoke-SyncThingCli $SyncThingExe $SyncThingHome $GuiAddress $ApiKey -Args @("config", "gui", "raw-address", "get") -QuietErrors
    if ($LASTEXITCODE -ne 0) {
        WC "Starting SyncThing at $GuiAddress..."
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
        WG "SyncThing already running at $RawAddress"
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

function Configure-SyncThingFolders {
    # Configures SyncThing folders for git-lfs (with --ignore-delete flag) and depot (bidirectional)
    param([string]$WorkspaceRoot, [hashtable]$SyncThingInfo)
    $SyncThingExe = Get-SyncThingExecutable
    if (-not $SyncThingExe) {
        Write-Error "Syncthing executable not found"
        return
    }
    $ForgeRepo = Get-Content "$WorkspaceRoot\.que\forge-repo"
    $SyncThingHome = Join-Path $WorkspaceRoot "env\syncthing-home"
    $GuiAddress = $SyncThingInfo.GuiAddress
    $ApiKey = $SyncThingInfo.ApiKey
    # Add git-lfs folder with --ignore-delete flag
    $LfsPath = Join-Path $WorkspaceRoot "sync\git-lfs"
    $LfsFolderId = "$ForgeRepo-lfs"
    $LfsLabel = "$ForgeRepo Git LFS"
    WC "Configuring SyncThing folder: $LfsLabel"
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
    $DepotFolderId = "$ForgeRepo-depot"
    $DepotLabel = "$ForgeRepo Depot"
    WC "Configuring SyncThing folder: $DepotLabel"
    Invoke-SyncThingCli $SyncThingExe $SyncThingHome $GuiAddress $ApiKey -Args @(
        "config"
        "folders"
        "add"
        "--id=$DepotFolderId"
        "--label=$DepotLabel"
        "--path=$DepotPath"
    )
    WG "SyncThing folders configured successfully"
}

function Update-SyncThingDevices {
    # Adds known devices to SyncThing configuration and shares folders
    param([string]$WorkspaceRoot, [array]$DeviceIds, [hashtable]$SyncThingInfo)
    if ($DeviceIds.Count -eq 0) {
        WY "No additional devices to configure"
        return
    }
    $SyncThingExe = Get-SyncThingExecutable
    if (-not $SyncThingExe) {
        Write-Error "Syncthing executable not found"
        return
    }
    $ForgeRepo = Get-Content "$WorkspaceRoot\.que\forge-repo"
    $SyncThingHome = Join-Path $WorkspaceRoot "env\syncthing-home"
    $GuiAddress = $SyncThingInfo.GuiAddress
    $ApiKey = $SyncThingInfo.ApiKey
    $LfsFolderId = "$ForgeRepo-lfs"
    $DepotFolderId = "$ForgeRepo-depot"
    $AllKnownDeviceIds = Invoke-SyncThingCli $SyncThingExe $SyncThingHome $GuiAddress $ApiKey -Args @("config", "devices", "list") -QuietErrors
    foreach ($DeviceId in $DeviceIds) {
        if ($DeviceId -and $AllKnownDeviceIds -notcontains $DeviceId) {
            WG "Adding SyncThing peer: $DeviceId"
            Invoke-SyncThingCli $SyncThingExe $SyncThingHome $GuiAddress $ApiKey -Args @(
                "config"
                "devices"
                "add"
                "--device-id=$DeviceId"
                "--auto-accept-folders"
            )
            WC "  Sharing git-lfs folder with peer"
            Invoke-SyncThingCli $SyncThingExe $SyncThingHome $GuiAddress $ApiKey -Args @(
                "config"
                "folders"
                $LfsFolderId
                "devices"
                "add"
                "--device-id=$DeviceId"
            ) -QuietErrors
            WC "  Sharing depot folder with peer"
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
    WG "SyncThing devices configured successfully"
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
        if (-not $Silent) { WY "SyncThing not configured, skipping sync wait" }
        return $true
    }

    $ApiKeyFile = Join-Path $WorkspaceRoot "env\syncthing\api.key"
    $PortFile = Join-Path $WorkspaceRoot ".que\syncthing\gui.port"

    if (-not (Test-Path $ApiKeyFile) -or -not (Test-Path $PortFile)) {
        if (-not $Silent) { WY "SyncThing configuration incomplete, skipping sync wait" }
        return $true
    }

    try {
        $ApiKey = Read-SecureFile $ApiKeyFile
        $Port = Get-Content $PortFile -Raw -ErrorAction Stop
        $Port = $Port.Trim()
        $GuiAddress = "127.0.0.1:$Port"
    } catch {
        if (-not $Silent) { WY "Failed to read SyncThing config, skipping sync wait" }
        return $true
    }

    $ForgeRepo = Get-Content "$WorkspaceRoot\.que\forge-repo" -ErrorAction SilentlyContinue
    if (-not $ForgeRepo) {
        if (-not $Silent) { WY "Cannot determine repository name, skipping sync wait" }
        return $true
    }

    $LfsFolderId = "$ForgeRepo-lfs"

    # Check if we need to wait at all
    $BaseUrl = "http://$GuiAddress/rest"
    $Headers = @{ "X-API-Key" = $ApiKey }

    try {
        # Get folder status to see if there are any out-of-sync items
        $StatusUrl = "$BaseUrl/db/status?folder=$LfsFolderId"
        $Status = Invoke-RestMethod -Uri $StatusUrl -Headers $Headers -Method Get -TimeoutSec 5 -ErrorAction Stop

        # Check if folder is already in sync
        if ($Status.needBytes -eq 0 -and $Status.needDeletes -eq 0 -and $Status.needFiles -eq 0) {
            if (-not $Silent) { WG "LFS folder already in sync" }
            return $true
        }

        if (-not $Silent) {
            $needMB = [math]::Round($Status.needBytes / 1MB, 2)
            WC "Waiting for SyncThing to sync LFS files ($($Status.needFiles) files, $needMB MB)..."
        }

        $StartTime = Get-Date
        while (((Get-Date) - $StartTime).TotalSeconds -lt $TimeoutSeconds) {
            try {
                $Status = Invoke-RestMethod -Uri $StatusUrl -Headers $Headers -Method Get -TimeoutSec 5 -ErrorAction Stop
                if ($Status.needBytes -eq 0 -and $Status.needDeletes -eq 0 -and $Status.needFiles -eq 0) {
                    if (-not $Silent) { WG "LFS sync complete" }
                    return $true
                }
                if (-not $Silent) { Write-Host "." -NoNewline }
                Start-Sleep -Milliseconds 500
            } catch {
                if (-not $Silent) { WY "`nSyncThing API unavailable, proceeding without sync wait" }
                return $false
            }
        }

        if (-not $Silent) {
            WY "`nSync wait timeout reached after $TimeoutSeconds seconds"
            WY "Some LFS files may not be available yet"
        }
        return $false

    } catch {
        if (-not $Silent) { WY "Failed to check SyncThing status: $($_.Exception.Message)" }
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
        WG "Created UE .gitattributes at: $UEGitAttributesPath"
    }
    if (-not (Test-Path $UEGitIgnorePath)) {
        Set-Content -Path $UEGitIgnorePath -Value $EmbeddedUEGitIgnore
        WG "Created UE .gitignore at: $UEGitIgnorePath"
    }
}

function Test-WingetPackageInstalled {
    param([string]$PackageName)
    $ListOutput = & winget list --id $PackageName --exact --accept-source-agreements 2>&1
    return ($LASTEXITCODE -eq 0 -and (($ListOutput -join "`n") -match [regex]::Escape($PackageName)))
}

function Test-NetFx3Enabled {
    try { return [bool](Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v3.5" -ErrorAction SilentlyContinue).Version } catch { return $false }
}

function Get-UnrealEngineInstallDirectory {
    # Returns the install directory of a launcher-installed engine version (e.g. "5.7"), or $null.
    # The Epic Games Launcher records every install in %ProgramData%\Epic\UnrealEngineLauncher\LauncherInstalled.dat
    # (the same list UnrealVersionSelector reads); it does not reliably write per-version registry keys.
    param([string]$EngineVersion)
    $ManifestPath = Join-Path ([Environment]::GetFolderPath('CommonApplicationData')) 'Epic\UnrealEngineLauncher\LauncherInstalled.dat'
    if (-not (Test-Path $ManifestPath)) { return $null }
    try { $Manifest = Get-Content $ManifestPath -Raw | ConvertFrom-Json } catch { return $null }
    $Entry = @($Manifest.InstallationList) | Where-Object { $_.AppName -eq "UE_$EngineVersion" -and $_.InstallLocation -and (Test-Path (Join-Path $_.InstallLocation 'Engine')) } | Select-Object -First 1
    if ($Entry) { return $Entry.InstallLocation }
    return $null
}

# The MSVC this engine version builds with, as Visual Studio 2022 Build Tools components
$QueMsvcComponents = @('Microsoft.VisualStudio.Component.VC.14.38.17.8.x86.x64', 'Microsoft.VisualStudio.Component.VC.14.38.17.8.ATL')

function Get-QueBuildToolsPath {
    # Returns the install path of Visual Studio 2022 Build Tools, or $null
    $VsWhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (-not (Test-Path $VsWhere)) { return $null }
    return (& $VsWhere -products Microsoft.VisualStudio.Product.BuildTools -version '[17.0,18.0)' -latest -property installationPath | Select-Object -First 1)
}

function Test-QueMsvcInstalled {
    # True when Visual Studio 2022 Build Tools has every MSVC component this engine version pins
    param([string[]]$Components)
    $VsWhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (-not (Test-Path $VsWhere)) { return $false }
    return [bool](& $VsWhere -products Microsoft.VisualStudio.Product.BuildTools -version '[17.0,18.0)' -requires $Components -property installationPath)
}

function Repair-QueBuildTools {
    # winget skips Build Tools when any version is installed, so a machine set up for an older engine can lack the MSVC
    # this engine pins, or default to one Unreal bans. Updates the install to the latest VS 2022 release, then adds the
    # components. Uses the Build Tools bootstrapper, which also updates the Visual Studio Installer. Needs admin rights.
    param([string]$InstallPath, [string[]]$Components)
    $Bootstrapper = Join-Path $env:TEMP 'vs_buildtools.exe'
    try {
        Invoke-WebRequest -UseBasicParsing -Uri 'https://aka.ms/vs/17/release/vs_buildtools.exe' -OutFile $Bootstrapper -ErrorAction Stop
    } catch {
        Write-Warning "Could not download the Visual Studio Build Tools bootstrapper: $($_.Exception.Message)"
        return $false
    }
    WY "Updating Visual Studio Build Tools at $InstallPath (this can take a while)..."
    $Update = Start-Process -FilePath $Bootstrapper -ArgumentList @('update', '--installPath', "`"$InstallPath`"", '--quiet', '--wait', '--norestart') -Wait -PassThru
    if ($Update.ExitCode -notin @(0, 3010)) {
        Write-Warning "Visual Studio Build Tools update failed with exit code $($Update.ExitCode)"
        return $false
    }
    WY "Adding $($Components -join ', ')..."
    $ModifyArgs = @('modify', '--installPath', "`"$InstallPath`"") + @($Components | ForEach-Object { '--add'; $_ }) + @('--quiet', '--wait', '--norestart')
    $Modify = Start-Process -FilePath $Bootstrapper -ArgumentList $ModifyArgs -Wait -PassThru
    if ($Modify.ExitCode -notin @(0, 3010)) {
        Write-Warning "Adding the MSVC components failed with exit code $($Modify.ExitCode)"
        return $false
    }
    if (3010 -in @($Update.ExitCode, $Modify.ExitCode)) { WY "Restart Windows to finish the Visual Studio update." }
    WG "Visual Studio Build Tools now has $($Components -join ', ')"
    return $true
}

function Install-AllDependencies {
    # Installs everything Unreal development needs. Packages that require administrator rights are
    # installed together in ONE elevated PowerShell (a single UAC prompt, none when all are present).
    # Syncthing is a per-user portable package and is installed unelevated so it lands where
    # Get-SyncThingExecutable looks.
    WC "`nInstalling prerequisites for Unreal Engine $QueUnrealEngineVersion..."
    # Engine-specific toolchain: each package is a winget Id plus an optional pinned Version and installer Override
    $MsvcComponents = $QueMsvcComponents
    $VSOverride = @(
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
        '--add Microsoft.VisualStudio.Component.Unreal.Workspace'
        $MsvcComponents | ForEach-Object { "--add $_" }
        '--remove Microsoft.VisualStudio.Component.Windows11SDK.26100'
    ) -join ' '
    $ToolchainPackages = @(
        @{ Id = 'Microsoft.DotNet.Framework.DeveloperPack_4' }
        @{ Id = 'Microsoft.VisualStudio.2022.BuildTools'; Override = $VSOverride }
    )
    $ElevatedPackages = @(@('Git.Git', 'Git.GCM', 'EpicGames.EpicGamesLauncher') | ForEach-Object { @{ Id = $_ } }) + $ToolchainPackages
    # Git for Windows bundles git-lfs; the standalone package needs elevation, so only ask for it when lfs is really missing
    if (Get-Command git -ErrorAction SilentlyContinue) {
        $null = git lfs version 2>&1
        if ($LASTEXITCODE -ne 0) { $ElevatedPackages += @{ Id = 'GitHub.GitLFS' } }
    }
    $Missing = @($ElevatedPackages | Where-Object { -not (Test-WingetPackageInstalled $_.Id) })
    $NeedNetFx3 = -not (Test-NetFx3Enabled)
    # winget skips Build Tools when any version is installed, so also check an existing install has this engine's MSVC
    $BuildToolsPath = Get-QueBuildToolsPath
    $NeedMsvc = [bool]$BuildToolsPath -and -not (Test-QueMsvcInstalled $MsvcComponents)
    if ($Missing.Count -eq 0 -and -not $NeedNetFx3 -and -not $NeedMsvc) {
        WG "All machine-level prerequisites are already installed"
    } elseif (Test-IsAdmin) {
        foreach ($Pkg in $Missing) { Sync-WingetPackage -PackageName $Pkg.Id -Version "$($Pkg.Version)" -PackageParameters "$($Pkg.Override)" }
        if ($NeedNetFx3) { Install-NetFx3WithElevation | Out-Null }
        if ($NeedMsvc) { Repair-QueBuildTools -InstallPath $BuildToolsPath -Components $MsvcComponents | Out-Null }
    } else {
        $What = @($Missing | ForEach-Object { $_.Id }) + @($(if ($NeedNetFx3) { '.NET Framework 3.5' })) + @($(if ($NeedMsvc) { "MSVC for Unreal Engine $QueUnrealEngineVersion ($($MsvcComponents -join ', '))" }))
        WY "Administrator rights are needed to install: $($What -join ', ')"
        WY "One elevation prompt will follow; everything installs in that window."
        $Helpers = @('WG', 'WC', 'WY', 'WW', 'WR', 'Sync-WingetPackage', 'Test-WingetPackageInstalled', 'Repair-QueBuildTools') | ForEach-Object {
            "function $_ {`n$((Get-Item "function:$_").ScriptBlock)`n}"
        }
        $Steps = @()
        foreach ($Pkg in $Missing) { $Steps += "Sync-WingetPackage -PackageName '$($Pkg.Id)' -Version '$($Pkg.Version)' -PackageParameters '$($Pkg.Override)'; if (-not (Test-WingetPackageInstalled '$($Pkg.Id)')) { `$Failed++ }" }
        if ($NeedMsvc) { $Steps += "if (-not (Repair-QueBuildTools -InstallPath '$BuildToolsPath' -Components @('$($MsvcComponents -join "', '")'))) { `$Failed++ }" }
        if ($NeedNetFx3) { $Steps += "try { WY 'Enabling .NET Framework 3.5...'; Enable-WindowsOptionalFeature -Online -FeatureName 'NetFx3' -All -NoRestart -ErrorAction Stop | Out-Null; WG '.NET Framework 3.5 enabled' } catch { Write-Warning `$_.Exception.Message; `$Failed++ }" }
        $ElevatedScript = (@('$ErrorActionPreference = "Continue"', '$Failed = 0') + $Helpers + $Steps + @(
            'if ($Failed -gt 0) { Write-Warning "$Failed install(s) failed"; Read-Host "Press Enter to close this window" }',
            'exit $Failed')) -join "`n"
        $Encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($ElevatedScript))
        # Start-Process throws when the elevation prompt is declined; treat that like a failed install
        try {
            $Process = Start-Process -FilePath 'powershell.exe' -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-EncodedCommand', $Encoded -Verb RunAs -Wait -PassThru -ErrorAction Stop
        } catch {
            $Process = [pscustomobject]@{ ExitCode = $What.Count }
        }
        if ($Process.ExitCode -ne 0) {
            Write-Warning "$($Process.ExitCode) prerequisite install(s) failed or the elevation was declined. Continuing; run setup again to retry."
        }
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    }
    if (Get-Command git -ErrorAction SilentlyContinue) {
        git lfs install 2>&1 | Out-Null
        $null = git lfs version 2>&1
        if ($LASTEXITCODE -ne 0) { Sync-WingetPackage -PackageName 'GitHub.GitLFS' }
    }
    Sync-WingetPackage -PackageName 'Syncthing.Syncthing'
    WG "`nDependencies installed successfully"
    WC "`nChecking Unreal Engine $QueUnrealEngineVersion installation..."
    $UEInstallPath = Get-UnrealEngineInstallDirectory -EngineVersion $QueUnrealEngineVersion
    if ($UEInstallPath) {
        WG "Unreal Engine $QueUnrealEngineVersion is installed at: $UEInstallPath"
    } else {
        WY "Unreal Engine $QueUnrealEngineVersion is not installed."
        WY "Please install it using the Epic Games Launcher"
        $LauncherPath = Get-EpicGamesLauncherExecutable
        if ($LauncherPath) {
            Write-Host "Launching Epic Games Launcher from: $LauncherPath" -ForegroundColor Gray
            Start-Process $LauncherPath -ArgumentList "-openueversion=$QueUnrealEngineVersion"
        } else {
            Write-Warning "Could not locate Epic Games Launcher executable"
            WY "Please open Epic Games Launcher manually and install Unreal Engine $QueUnrealEngineVersion"
        }
        WY "Continuing setup (UE will be required before opening the project)..."
    }
}

function New-QueRepoScript {
    # Generates project-specific que-project.ps1 script with marker-based substitution
    param([string]$CloneRoot, [string]$Owner, [string]$Repo, [string]$SyncThingDeviceId = "", [string[]]$SyncThingDeviceIds = @(), [string]$SourceScript = $queScript)
    $ThreeHashes = '###'
    $OutputPath = "$CloneRoot\que-project.ps1"
    $ScriptContent = $SourceScript
    $DeviceIds = @(@($SyncThingDeviceIds) + @($SyncThingDeviceId) | Where-Object { $_ } | Select-Object -Unique)
    # Update constants section
    $ConstantsBlock = @"
$($ThreeHashes)QUE_CONSTANTS_BEGIN$($ThreeHashes)
`$QueUnrealEngineVersion = "$QueUnrealEngineVersion"
`$QueForgeHost = "$($script:QueForgeHost)"
`$QueForgeOwner = "$Owner"
`$QueForgeRepo = "$Repo"
$($ThreeHashes)QUE_CONSTANTS_END$($ThreeHashes)
"@
    $ScriptContent = $ScriptContent -replace ('{0}QUE_CONSTANTS_BEGIN{0}[\s\S]*?{0}QUE_CONSTANTS_END{0}' -f @('###')), $ConstantsBlock
    # Add SyncThing devices section
    if ($DeviceIds.Count -gt 0) {
        $SyncThingBlock = @"
$($ThreeHashes)QUE_SYNCTHING_BEGIN$($ThreeHashes)
`$SyncThingDevices = @(
$(($DeviceIds | ForEach-Object { "    `"$_`"" }) -join ",`n")
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
    WG "Generated: $OutputPath"
}

function Update-QueRepoScript {
    # Regenerates the project script of an existing clone from this generator, keeping the project identity
    # (from the workspace's .que folder) and the SyncThing devices listed in the clone's current project script.
    # Usage: . .\que57.ps1; Update-QueRepoScript -CloneRoot <clone dir>. Writes the file only; review and commit it yourself.
    param([string]$CloneRoot = (Get-Location).Path)
    $ThreeHashes = '###'
    $SourceScript = if ((Test-Path variable:queScript) -and $queScript) { $queScript } else { Get-Content $PSCommandPath -Raw }
    if ($SourceScript -notmatch ('{0}QUE_CREATION_MODE_BEGIN{0}' -f @($ThreeHashes))) {
        throw "Update-QueRepoScript must be run from the que generator script (e.g. que57.ps1), not from a generated project script."
    }
    $CloneRoot = (Resolve-Path $CloneRoot -ErrorAction Stop).Path
    Push-Location $CloneRoot
    try { $WorkspaceRoot = Find-QueWorkspace } finally { Pop-Location }
    if (-not $WorkspaceRoot) {
        throw "$CloneRoot is not inside a QUE workspace (no .que folder with forge-owner and forge-repo above it)."
    }
    Import-QueWorkspaceForge $WorkspaceRoot
    $Owner = Get-Content "$WorkspaceRoot\.que\forge-owner" | Select-Object -First 1
    $Repo = Get-Content "$WorkspaceRoot\.que\forge-repo" | Select-Object -First 1
    # Carry forward every SyncThing device already recorded by the clone's project script(s)
    $ExistingScripts = @(Get-ChildItem -Path $CloneRoot -Filter 'que*-project.ps1' -File -ErrorAction SilentlyContinue)
    $DeviceIds = @($ExistingScripts | ForEach-Object {
        $Block = [regex]::Match((Get-Content $_.FullName -Raw), ('{0}QUE_SYNCTHING_BEGIN{0}([\s\S]*?){0}QUE_SYNCTHING_END{0}' -f @($ThreeHashes))).Groups[1].Value
        [regex]::Matches($Block, '"([A-Z0-9]{7}(?:-[A-Z0-9]{7}){7})"') | ForEach-Object { $_.Groups[1].Value }
    } | Select-Object -Unique)
    WC "Regenerating project script for $Owner/$Repo ($script:QueForgeHost) with $($DeviceIds.Count) SyncThing device(s)..."
    New-QueRepoScript -CloneRoot $CloneRoot -Owner $Owner -Repo $Repo -SyncThingDeviceIds $DeviceIds -SourceScript $SourceScript
    # Older names stay as stubs so existing shortcuts, sessions and join one-liners keep working
    foreach ($Old in @($ExistingScripts | Where-Object { $_.Name -ne 'que-project.ps1' })) {
        Set-Content -Path $Old.FullName -Value $QueLegacyStub
        WY "Replaced $($Old.Name) with a stub that migrates the workspace and opens que-project.ps1"
    }
    WY "Review the change with git diff, then commit and push it to share with your team."
}


# Workspace Creation Functions

function New-QueWorkspace {
    # Creates a new QUE workspace with initialization modes: blank, from another git URL, from local repo
    param([string]$ForgeOwner, [string]$ForgeRepo, [string]$Token, [object]$UserInfo)
    $WorkspaceRoot = (Get-Location).Path
    WC "`nCreating QUE workspace for $ForgeOwner/$ForgeRepo..."
    Write-Host "`nCreating workspace structure..."
    New-Item -ItemType Directory -Force -Path ".que" | Out-Null
    New-Item -ItemType Directory -Force -Path ".que/repo" | Out-Null
    New-Item -ItemType Directory -Force -Path "sync/git-lfs/lfs" | Out-Null
    New-Item -ItemType Directory -Force -Path "sync/depot" | Out-Null
    New-Item -ItemType Directory -Force -Path "env/forge" | Out-Null
    New-Item -ItemType Directory -Force -Path "env/syncthing-home" | Out-Null
    New-Item -ItemType Directory -Force -Path "repo" | Out-Null
    Set-Content -Path ".que/forge-owner" -Value $ForgeOwner
    Set-Content -Path ".que/forge-repo" -Value $ForgeRepo
    Set-Content -Path ".que/forge-host" -Value $script:QueForgeHost
    Set-SecureForgeToken -Token $Token -WorkspaceRoot $WorkspaceRoot
    # Check if the repo exists on the host
    $RepoExists = $false
    try {
        $AuthHeaders = @{Authorization=@('token ', $Token) -join ''; 'Cache-Control'='no-store'}
        $RepoUrl = "$script:QueApiBase/repos/$ForgeOwner/$ForgeRepo"
        $Response = Invoke-WebRequest -UseBasicParsing -Uri $RepoUrl -Headers $AuthHeaders -Method Get -ErrorAction Stop
        $RepoExists = $true
        WG "`nRepository $ForgeOwner/$ForgeRepo already exists on $script:QueForgeLabel"
    } catch {
        if ($_.Exception.Response.StatusCode -eq 404) {
            $RepoExists = $false
            Write-Host "`nRepository $ForgeOwner/$ForgeRepo does not exist on $script:QueForgeLabel and will be created"
        } else {
            Write-Error "Failed to check if repository exists: $($_.Exception.Message)"
            return
        }
    }
    # Determine initialization mode
    $ShouldClone = $false
    $InitMode = 0  # 0 = blank, 1 = from another git URL, 2 = from local, 3 = as part of an existing forge repo
    $RepoIsEmpty = $false
    if ($RepoExists) {
        $RepoIsEmpty = Test-ForgeRepoEmpty -Owner $ForgeOwner -Repo $ForgeRepo -Token $Token
        if ($RepoIsEmpty) {
            WY "Repository exists but is empty. Proceeding with blank project initialization."
            $ShouldClone = $false
            $InitMode = 0
        } else {
            WG "`nRepository $ForgeOwner/$ForgeRepo already exists. Cloning it for this workspace..."
            $ShouldClone = $true
            $InitMode = 3
        }
    } else {
        WY "`nSelect initialization method:"
        $Options = @(
            "Create a blank project",
            "Create from an existing git project URL",
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
                $SourceUrl = Read-Host "`nEnter git project URL to clone from (e.g., https://github.com/owner/repo)"
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
        Write-Host "`nRepository will be created later in the setup process." -ForegroundColor Gray
    }
    Install-AllDependencies
    WC "`nInitializing SyncThing..."
    $SyncThingInfo = Ensure-SyncThingRunning -WorkspaceRoot $WorkspaceRoot
    if (-not $SyncThingInfo) { throw "Failed to start SyncThing" }
    WC "`nCreating first clone..."
    $CloneRoot = New-QueClone -WorkspaceRoot $WorkspaceRoot -IsFirstClone $true -ShouldClone $ShouldClone -UserInfo $UserInfo -Token $Token -SyncThingInfo $SyncThingInfo
    # Handle special initialization modes
    if ($InitMode -eq 0) {
        WG "`nBlank project workspace created"
        WC "Next steps:"
        WW "  1. Create your Unreal Engine project in: $CloneRoot"
        WW "  2. Add and commit your files with git"
        WW "  3. Push to $script:QueForgeLabel when ready"
    } elseif ($InitMode -eq 1 -and $CloneFromSource) {
        if (-not (Ensure-ForgeRepoExists -Owner $ForgeOwner -Repo $ForgeRepo -Token $Token -UserInfo $UserInfo)) {
            return
        }
        Push-Location $CloneRoot
        git remote add source $CloneFromSource 2>&1 | ForEach-Object { "$_" } | Out-Host
        git fetch source 2>&1 | ForEach-Object { "$_" } | Out-Host
        git merge source/main --allow-unrelated-histories -m "Import from $CloneFromSource" 2>&1 | ForEach-Object { "$_" } | Out-Host
        git push origin main 2>&1 | ForEach-Object { "$_" } | Out-Host
        git remote remove source 2>&1 | ForEach-Object { "$_" } | Out-Host
        Pop-Location
        WG "Imported from source repository into $CloneRoot"
    } elseif ($InitMode -eq 2 -and $CopyFromLocal) {
        $SourceFiles = Get-ChildItem $CopyFromLocal -Exclude ".git" -Force
        foreach ($File in $SourceFiles) {
            Copy-Item $File.FullName -Destination $CloneRoot -Recurse -Force
        }
        if (-not (Ensure-ForgeRepoExists -Owner $ForgeOwner -Repo $ForgeRepo -Token $Token -UserInfo $UserInfo)) {
            return
        }
        Push-Location $CloneRoot
        git add -A 2>&1 | ForEach-Object { "$_" } | Out-Host
        git commit -m "Import from local repository" 2>&1 | ForEach-Object { "$_" } | Out-Host
        git push origin main 2>&1 | ForEach-Object { "$_" } | Out-Host
        Pop-Location
        WG "Imported from local repository into $CloneRoot"
    } elseif ($InitMode -eq 3) {
        # Wait for SyncThing to sync LFS files before pulling
        Wait-ForSyncThingLfsSync -WorkspaceRoot $WorkspaceRoot -TimeoutSeconds 300 | Out-Null
        Push-Location $CloneRoot
        git pull 2>&1 | ForEach-Object { "$_" } | Out-Host
        Pop-Location
        WG "Pulled latest from repository into $CloneRoot"
    }
    $ProjectScriptPath = Join-Path $CloneRoot "que-project.ps1"
    if (-not (Test-Path $ProjectScriptPath)) {
        if (Test-Path variable:queScript -and $queScript) {
            WY "que-project.ps1 missing; generating now..."
            $DeviceId = if ($SyncThingInfo) { $SyncThingInfo.DeviceId } else { "" }
            New-QueRepoScript -CloneRoot $CloneRoot -Owner $ForgeOwner -Repo $ForgeRepo -SyncThingDeviceId $DeviceId
        }
    }
    if (-not (Test-Path $ProjectScriptPath)) {
        Write-Error "Workspace creation incomplete: que-project.ps1 is missing in $CloneRoot"
        WY "Fix the repository or rerun the setup to generate que-project.ps1 before continuing."
        return
    }
    Set-Content -Path ".que/workspace-version" -Value "1"
    WG "`nWorkspace created successfully!"
}

function Invoke-WithLfsSkip([scriptblock]$Block) {
    $prev = $env:GIT_LFS_SKIP_SMUDGE; $env:GIT_LFS_SKIP_SMUDGE = '1'
    try { & $Block } finally {
        if ($null -ne $prev) { $env:GIT_LFS_SKIP_SMUDGE = $prev }
        else { Remove-Item env:GIT_LFS_SKIP_SMUDGE -EA 0 }
    }
}

function Get-QueLfsPointerFiles {
    # Returns the LFS files of a clone that are still pointer files: @{ Oid; Path; InStore }. InStore says whether
    # the object is already in the clone's LFS storage (lfs.storage, or .git\lfs when unset).
    param([string]$CloneRoot)
    $Listing = Invoke-QueGit -WorkingDir $CloneRoot -GitArgs @("lfs", "ls-files", "--long") -AllowFailure
    if ($Listing.ExitCode -ne 0) { return @() }
    $Storage = (Invoke-QueGit -WorkingDir $CloneRoot -GitArgs @("config", "--get", "lfs.storage") -AllowFailure).Output | Select-Object -First 1
    if (-not $Storage) { $Storage = Join-Path $CloneRoot ".git\lfs" }
    $Pointers = @()
    foreach ($Line in $Listing.Output) {
        if ("$Line" -match '^([0-9a-f]{64}) - (.+)$') {
            $Oid = $matches[1]
            $ObjectPath = Join-Path $Storage ("objects\{0}\{1}\{2}" -f $Oid.Substring(0, 2), $Oid.Substring(2, 2), $Oid)
            $Pointers += [pscustomobject]@{ Oid = $Oid; Path = $matches[2]; InStore = (Test-Path $ObjectPath); ObjectPath = $ObjectPath }
        }
    }
    return $Pointers
}

function Sync-QueLfsFiles {
    # Replaces the LFS pointer files of a clone with their content. Clones are made with smudge skipped (fast: the
    # objects usually are in the workspace's shared store already), so this runs once lfs.storage is set. Missing
    # objects are taken, in order, from the source clone's own .git\lfs (que clone of a clone without lfs.storage),
    # from SyncThing (waits for the git-lfs folder), and from origin. Returns the number of files still pointers.
    param([string]$CloneRoot, [string]$WorkspaceRoot, [string]$SourcePath = $null)
    $Pointers = @(Get-QueLfsPointerFiles -CloneRoot $CloneRoot)
    if ($Pointers.Count -eq 0) { return 0 }
    $Missing = @($Pointers | Where-Object { -not $_.InStore })
    if ($Missing.Count -gt 0 -and $SourcePath) {
        $Copied = 0
        foreach ($Pointer in $Missing) {
            $SourceObject = Join-Path $SourcePath (".git\lfs\objects\{0}\{1}\{2}" -f $Pointer.Oid.Substring(0, 2), $Pointer.Oid.Substring(2, 2), $Pointer.Oid)
            if (Test-Path $SourceObject) {
                New-Item -ItemType Directory -Force -Path (Split-Path $Pointer.ObjectPath -Parent) | Out-Null
                Copy-Item -Path $SourceObject -Destination $Pointer.ObjectPath -Force
                $Copied++
            }
        }
        if ($Copied -gt 0) { WC "Copied $Copied LFS objects from the source clone into the shared store" }
        $Missing = @(Get-QueLfsPointerFiles -CloneRoot $CloneRoot | Where-Object { -not $_.InStore })
    }
    if ($Missing.Count -gt 0 -and $WorkspaceRoot) {
        WC "$($Missing.Count) LFS objects are not in the shared store yet; waiting for SyncThing..."
        Wait-ForSyncThingLfsSync -WorkspaceRoot $WorkspaceRoot -Silent | Out-Null
        $Missing = @(Get-QueLfsPointerFiles -CloneRoot $CloneRoot | Where-Object { -not $_.InStore })
    }
    if ($Missing.Count -gt 0) {
        WC "Fetching $($Missing.Count) LFS objects from origin..."
        $Fetch = Invoke-QueGit -WorkingDir $CloneRoot -GitArgs @("lfs", "fetch", "origin") -AllowFailure
        if ($Fetch.ExitCode -ne 0) { WY "git lfs fetch origin failed (exit $($Fetch.ExitCode)); continuing with the objects present" }
    }
    $Checkout = Invoke-QueGit -WorkingDir $CloneRoot -GitArgs @("lfs", "checkout") -AllowFailure
    if ($Checkout.ExitCode -ne 0) { WY "git lfs checkout failed (exit $($Checkout.ExitCode))" }
    $Left = @(Get-QueLfsPointerFiles -CloneRoot $CloneRoot)
    if ($Left.Count -eq 0) {
        WG "LFS files checked out ($($Pointers.Count) files)"
    } else {
        WY "$($Left.Count) LFS files are still pointer files (objects not available yet), for example:"
        $Left | Select-Object -First 5 | ForEach-Object { WY "  $($_.Path)" }
        WY "Run 'que lfs' once SyncThing has synced or origin has the objects."
    }
    return $Left.Count
}

function New-QueClone {
    # Creates a new clone in an existing workspace
    param(
        [string]$WorkspaceRoot,
        [bool]$IsFirstClone = $false,
        [bool]$ShouldClone = $false,
        [object]$UserInfo = $null,
        [string]$Token = $null,
        [hashtable]$SyncThingInfo = $null,
        [string]$CloneName = $null,
        [string]$SourcePath = $null,
        [string]$WorkBranch = $null
    )
    $ForgeOwner = Get-Content "$WorkspaceRoot\.que\forge-owner"
    $ForgeRepo = Get-Content "$WorkspaceRoot\.que\forge-repo"
    Import-QueWorkspaceForge $WorkspaceRoot
    if (-not $Token) {
        $Token = Get-SecureForgeToken -WorkspaceRoot $WorkspaceRoot
        $UserInfo = Test-ForgeToken -Token $Token
        if (-not $UserInfo) {
            Write-Error "Failed to authenticate with the stored token."
            return
        }
    }
    if (-not $SyncThingInfo) {
        WC "Ensuring SyncThing is running..."
        $SyncThingInfo = Ensure-SyncThingRunning -WorkspaceRoot $WorkspaceRoot
    }
    if (-not $CloneName) {
        $CloneName = Get-NextCloneName -WorkspaceRoot $WorkspaceRoot
    }
    $CloneSpec = Resolve-QueCloneName -Name $CloneName -Login $UserInfo.login
    if (-not $CloneSpec) {
        throw "Invalid clone name '$CloneName'. Use letters, digits, '.', '_' and '-', with '/' between an owner and a name."
    }
    $CloneName = $CloneSpec.Folder
    if (-not $WorkBranch) { $WorkBranch = $CloneSpec.WorkBranch }
    $CloneRoot = Join-Path $WorkspaceRoot "repo\$CloneName"
    if ((Test-Path $CloneRoot) -and (Get-ChildItem -Force -Path $CloneRoot | Select-Object -First 1)) {
        throw "Clone folder already exists and is not empty: $CloneRoot"
    }
    WC "Creating clone: $CloneName (work branch $WorkBranch)"
    New-Item -ItemType Directory -Force -Path $CloneRoot | Out-Null
    $CloneMetaPath = "$WorkspaceRoot\.que\repo\$CloneName"
    New-Item -ItemType Directory -Force -Path $CloneMetaPath | Out-Null
    Store-GitCredentials -Login $UserInfo.login -Token $Token
    if ($SourcePath) {
        if (-not (Test-Path $SourcePath)) {
            throw "Source path not found: $SourcePath"
        }
        WC "Cloning from existing workspace state at $SourcePath..."
        Invoke-WithLfsSkip {
            Push-Location $CloneRoot
            try {
                git clone --no-hardlinks $SourcePath . 2>&1 | ForEach-Object { "$_" } | Out-Host
                if ($LASTEXITCODE -ne 0) { throw "git clone from $SourcePath failed with exit code $LASTEXITCODE" }
                git remote set-url origin (Get-QueCloneUrl $UserInfo.login $ForgeOwner $ForgeRepo) 2>&1 | ForEach-Object { "$_" } | Out-Host
                Set-QueGitConfig $UserInfo
            } finally { Pop-Location }
        }
        WC "Clone complete. LFS files are checked out once the shared store is set up"
        Write-UEGitConfigFiles -CloneRoot $CloneRoot
    } elseif ($ShouldClone) {
        WC "Cloning $ForgeOwner/$ForgeRepo..."
        Invoke-WithLfsSkip {
            Push-Location $CloneRoot
            try {
                git clone (Get-QueCloneUrl $UserInfo.login $ForgeOwner $ForgeRepo) . 2>&1 | ForEach-Object { "$_" } | Out-Host
                if ($LASTEXITCODE -ne 0) { throw "git clone failed with exit code $LASTEXITCODE" }
                Set-QueGitConfig $UserInfo
            } finally { Pop-Location }
        }
        WC "Clone complete. LFS files are checked out once the shared store is set up"
        Write-UEGitConfigFiles -CloneRoot $CloneRoot
        $ProjectScriptPath = "$CloneRoot\que-project.ps1"
        $RepoHasCommits = $true
        Push-Location $CloneRoot
        git rev-parse --verify HEAD 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) { $RepoHasCommits = $false }
        Pop-Location
        if (-not $RepoHasCommits) {
            WY "Repository is empty. Initializing default QUE files..."
            Write-GitConfigFiles -CloneRoot $CloneRoot
            $ReadmeContent = Expand-QueReadme $ForgeOwner $ForgeRepo
            Set-Content -Path "$CloneRoot\README.md" -Value $ReadmeContent
            if (-not (Test-Path $ProjectScriptPath)) {
                WC "Generating que-project.ps1..."
                $DeviceId = if ($SyncThingInfo) { $SyncThingInfo.DeviceId } else { "" }
                if (Test-Path variable:queScript -and $queScript) {
                    New-QueRepoScript -CloneRoot $CloneRoot -Owner $ForgeOwner -Repo $ForgeRepo -SyncThingDeviceId $DeviceId
                } else {
                    Write-Warning "Cannot generate que-project.ps1 (bootstrap script not available)."
                }
            }
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
            WG "`nRepository initialized and pushed to $script:QueForgeLabel!"
            WY "After creating the .uproject file, the UE git config files will be auto-generated."
        } elseif (-not (Test-Path $ProjectScriptPath)) {
            if (Test-Path variable:queScript -and $queScript) {
                WY "que-project.ps1 missing; generating from bootstrap script..."
                $DeviceId = if ($SyncThingInfo) { $SyncThingInfo.DeviceId } else { "" }
                New-QueRepoScript -CloneRoot $CloneRoot -Owner $ForgeOwner -Repo $ForgeRepo -SyncThingDeviceId $DeviceId
                WY "Please commit and push que-project.ps1 to share with your team."
            } else {
                Write-Warning "que-project.ps1 missing and cannot be generated (bootstrap script not available)."
            }
        }
    } else {
        WC "Initializing new repository..."
        Push-Location $CloneRoot
        git init -b main 2>&1 | ForEach-Object { "$_" } | Out-Host
        if ($LASTEXITCODE -ne 0) {
            Pop-Location
            throw "git init failed"
        }
        Set-QueGitConfig $UserInfo
        git remote add origin (Get-QueCloneUrl $UserInfo.login $ForgeOwner $ForgeRepo) 2>&1 | ForEach-Object { "$_" } | Out-Host
        Pop-Location
        Write-GitConfigFiles -CloneRoot $CloneRoot
        $ReadmeContent = Expand-QueReadme $ForgeOwner $ForgeRepo
        Set-Content -Path "$CloneRoot\README.md" -Value $ReadmeContent
        WC "Generating que-project.ps1..."
        $DeviceId = if ($SyncThingInfo) { $SyncThingInfo.DeviceId } else { "" }
        New-QueRepoScript -CloneRoot $CloneRoot -Owner $ForgeOwner -Repo $ForgeRepo -SyncThingDeviceId $DeviceId
        if (-not (Ensure-ForgeRepoExists -Owner $ForgeOwner -Repo $ForgeRepo -Token $Token -UserInfo $UserInfo)) {
            return
        }
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
        WG "`nRepository initialized and pushed to $script:QueForgeLabel!"
        WY "After creating the .uproject file, the UE git config files will be auto-generated."
    }
    Push-Location $CloneRoot
    git lfs install --local 2>&1 | ForEach-Object { "$_" } | Out-Host
    $LfsStoragePath = Join-Path $WorkspaceRoot "sync\git-lfs\lfs"
    git config --local lfs.storage $LfsStoragePath
    Pop-Location
    # Full files before the branch switch: a checkout with smudge on fails on objects nobody can provide
    Sync-QueLfsFiles -CloneRoot $CloneRoot -WorkspaceRoot $WorkspaceRoot -SourcePath $SourcePath | Out-Null
    $ShortcutPath = "$WorkspaceRoot\open-$CloneName.lnk"
    $TargetScript = "$CloneRoot\que-project.ps1"
    New-WindowsShortcut -ShortcutPath $ShortcutPath -TargetScript $TargetScript
    WG "Created shortcut: $ShortcutPath"
    Set-Content -Path "$CloneMetaPath\repo-version" -Value "1"
    Ensure-QueCloneOnWorkBranch -CloneRoot $CloneRoot -WorkBranch $WorkBranch -SkipIfDirty:$false
    Sync-QueLfsFiles -CloneRoot $CloneRoot -WorkspaceRoot $WorkspaceRoot | Out-Null
    return $CloneRoot
}

function Invoke-QueGit {
    param([string]$WorkingDir, [string[]]$GitArgs, [switch]$AllowFailure)
    if (-not (Test-Path $WorkingDir)) {
        throw "Working directory not found: $WorkingDir"
    }
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

# Keeps a clone off main when safe to do so. The branch a clone is on is its work branch: any branch other
# than main (your own, someone else's you loaded, a rename) is left alone. On main or a detached HEAD the clone
# goes to $WorkBranch, or by default que/<login>/<clone folder>. A clone still on the older default
# que/<clone folder> has that local branch renamed to the new default once; origin's copy is left as it is.
function Ensure-QueCloneOnWorkBranch {
    param([string]$CloneRoot, [string]$WorkBranch = $null, [switch]$SkipIfDirty = $true)
    if (-not $CloneRoot) { return }
    $CurrentBranchResult = Invoke-QueGit -WorkingDir $CloneRoot -GitArgs @("rev-parse", "--abbrev-ref", "HEAD") -AllowFailure
    $CurrentBranch = $CurrentBranchResult.Output | Select-Object -First 1
    if ($CurrentBranchResult.ExitCode -ne 0 -or -not $CurrentBranch) { return }
    $IsExplicit = [bool]$WorkBranch
    if (-not $WorkBranch) { $WorkBranch = Get-QueDefaultWorkBranch -CloneRoot $CloneRoot }
    if ($CurrentBranch -eq $WorkBranch) { return }
    $MainBranch = if ($script:QueMainBranch) { $script:QueMainBranch } else { "main" }
    $LegacyBranch = "que/$(Split-Path $CloneRoot -Leaf)"
    $IsLegacy = -not $IsExplicit -and $CurrentBranch -eq $LegacyBranch
    if (-not $IsExplicit -and -not $IsLegacy -and $CurrentBranch -ne $MainBranch -and $CurrentBranch -ne "HEAD") { return }

    if ($SkipIfDirty) {
        $Status = Invoke-QueGit -WorkingDir $CloneRoot -GitArgs @("status", "--porcelain") -AllowFailure
        if ($Status.ExitCode -eq 0 -and ($Status.Output | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
            return
        }
    }

    $BranchExists = (Invoke-QueGit -WorkingDir $CloneRoot -GitArgs @("show-ref", "--verify", "refs/heads/$WorkBranch") -AllowFailure).ExitCode -eq 0
    if ($IsLegacy) {
        if ($BranchExists) {
            Write-Warning "Not renaming $LegacyBranch to ${WorkBranch}: it already exists in this clone."
            return
        }
        Invoke-QueGit -WorkingDir $CloneRoot -GitArgs @("branch", "-m", $WorkBranch) | Out-Null
        # The upstream still names the old branch; the next save pushes the new name and tracks it
        Invoke-QueGit -WorkingDir $CloneRoot -GitArgs @("branch", "--unset-upstream") -AllowFailure | Out-Null
        WY "Renamed work branch $LegacyBranch to $WorkBranch (origin/$LegacyBranch is unchanged)."
        return
    }

    $RemoteBranchExists = (Invoke-QueGit -WorkingDir $CloneRoot -GitArgs @("show-ref", "--verify", "refs/remotes/origin/$WorkBranch") -AllowFailure).ExitCode -eq 0
    if ($BranchExists) {
        Invoke-QueGit -WorkingDir $CloneRoot -GitArgs @("checkout", $WorkBranch) -AllowFailure | Out-Null
    } elseif ($RemoteBranchExists) {
        Invoke-QueGit -WorkingDir $CloneRoot -GitArgs @("checkout", "-b", $WorkBranch, "--track", "origin/$WorkBranch") -AllowFailure | Out-Null
    } else {
        Invoke-QueGit -WorkingDir $CloneRoot -GitArgs @("checkout", "-b", $WorkBranch) -AllowFailure | Out-Null
    }

    $FinalBranchResult = Invoke-QueGit -WorkingDir $CloneRoot -GitArgs @("rev-parse", "--abbrev-ref", "HEAD") -AllowFailure
    $FinalBranch = $FinalBranchResult.Output | Select-Object -First 1
    if ($FinalBranchResult.ExitCode -ne 0 -or $FinalBranch -ne $WorkBranch) {
        Write-Warning "Failed to switch clone to work branch $WorkBranch"
    }
}

# ----------------------------------------------------------------------------
# MANAGEMENT COMMANDS (commented out in que57.ps1, active in que-project.ps1)
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

function Get-QueCurrentBranch {
    param([string]$CloneRoot)
    $Result = Invoke-QueGit -WorkingDir $CloneRoot -GitArgs @("rev-parse", "--abbrev-ref", "HEAD")
    return ($Result.Output | Select-Object -First 1)
}

function Resolve-QueWorkBranchInput {
    # Resolves a work branch name as typed (see Resolve-QueCloneName). A bare name means your own
    # que/<login>/<name>, or the older que/<name> when only that exists on origin.
    param([string]$CloneRoot, [string]$Name)
    $Login = Get-QueLogin -CloneRoot $CloneRoot
    $Spec = Resolve-QueCloneName -Name $Name -Login $Login
    if (-not $Spec -or -not ($Spec.IsBare -and $Login)) { return $Spec }
    $OwnCheck = Invoke-QueGit -WorkingDir $CloneRoot -GitArgs @("ls-remote", "--exit-code", "origin", "refs/heads/$($Spec.WorkBranch)") -AllowFailure
    if ($OwnCheck.ExitCode -eq 0) { return $Spec }
    $Legacy = Resolve-QueCloneName -Name $Name -Login $null
    $LegacyCheck = Invoke-QueGit -WorkingDir $CloneRoot -GitArgs @("ls-remote", "--exit-code", "origin", "refs/heads/$($Legacy.WorkBranch)") -AllowFailure
    if ($LegacyCheck.ExitCode -eq 0) { return $Legacy }
    return $Spec
}

function Get-QueRemoteWorkBranchNames {
    param([string]$WorkingDir)
    if (-not $WorkingDir -or -not (Test-Path $WorkingDir)) {
        return @()
    }

    $Result = Invoke-QueGit -WorkingDir $WorkingDir -GitArgs @("branch", "-r", "--list", "origin/que/*") -AllowFailure
    if ($Result.ExitCode -ne 0) {
        return @()
    }

    return @(
        $Result.Output |
            ForEach-Object { "$_".Trim() } |
            Where-Object { $_ -like 'origin/que/*' } |
            ForEach-Object { $_.Substring('origin/que/'.Length) } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Sort-Object -Unique
    )
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
    # Pushes a work branch as a backup. Repository push hooks (such as a review gate) are skipped with
    # --no-verify; they run when the branch is published (Invoke-QuePrePushHook). The Git LFS upload the
    # skipped hook would have done is run directly.
    param([string]$CloneRoot, [string]$Branch, [int]$MaxAttempts = 3)
    $DelaySeconds = 2
    for ($Attempt = 1; $Attempt -le $MaxAttempts; $Attempt++) {
        $PushResult = Invoke-QueGit -WorkingDir $CloneRoot -GitArgs @("push", "--no-verify", "-u", "origin", $Branch) -AllowFailure
        if ($PushResult.ExitCode -eq 0) {
            $LfsResult = Invoke-QueGit -WorkingDir $CloneRoot -GitArgs @("lfs", "push", "origin", $Branch) -AllowFailure
            if ($LfsResult.ExitCode -ne 0) {
                WY "Warning: pushed $Branch, but uploading its LFS objects failed:`n$($LfsResult.Output -join "`n")"
            }
            return $PushResult
        }
        # Only a push that lost a race (origin's copy of the branch moved on) is worth merging and retrying.
        # Anything else, such as an authentication error or a server-side refusal, fails the same way every time.
        if (($PushResult.Output -join "`n") -notmatch '\[rejected\][^\r\n]*\((fetch first|non-fast-forward)\)') {
            throw "Push failed.`n$($PushResult.Output -join "`n")"
        }
        if ($Attempt -eq $MaxAttempts) {
            throw "Push failed after $MaxAttempts attempts.`n$($PushResult.Output -join "`n")"
        }
        WY "Push rejected; merging origin/$Branch then retrying (attempt $($Attempt + 1) of $MaxAttempts)..."
        Invoke-QueGit -WorkingDir $CloneRoot -GitArgs @("fetch", "origin", $Branch)
        Invoke-QueMerge -CloneRoot $CloneRoot -Source "origin/$Branch" -Message "que: merge origin/$Branch"
        Start-Sleep -Seconds $DelaySeconds
        $DelaySeconds = [Math]::Min($DelaySeconds * 2, 30)
    }
}

function Get-QueShell {
    # Git for Windows' sh, which git itself uses to run hooks
    $Git = (Get-Command git -ErrorAction SilentlyContinue).Source
    if ($Git) {
        $GitRoot = Split-Path (Split-Path $Git -Parent) -Parent
        foreach ($Candidate in @("bin\sh.exe", "usr\bin\sh.exe")) {
            $Path = Join-Path $GitRoot $Candidate
            if (Test-Path $Path) { return $Path }
        }
    }
    $Sh = (Get-Command sh -ErrorAction SilentlyContinue).Source
    if ($Sh) { return $Sh }
    throw "Cannot find sh to run the repository's git hooks. Is Git for Windows installed?"
}

function Invoke-QuePrePushHook {
    # Runs the repository's pre-push hook for the branch about to be published, exactly as 'git push' would
    # (arguments: remote and URL; stdin: one ref line), so publishing goes through the same checks as a manual
    # push even though 'que save' skipped them. Throws with the hook's output if it refuses.
    param([string]$CloneRoot, [string]$Branch)
    $HooksDir = "$((Invoke-QueGit -WorkingDir $CloneRoot -GitArgs @("rev-parse", "--git-path", "hooks")).Output | Select-Object -First 1)".Trim()
    if (-not [System.IO.Path]::IsPathRooted($HooksDir)) { $HooksDir = Join-Path $CloneRoot $HooksDir }
    $Hook = Join-Path $HooksDir "pre-push"
    if (-not (Test-Path $Hook)) { return }
    $Sha = "$((Invoke-QueGit -WorkingDir $CloneRoot -GitArgs @("rev-parse", "HEAD")).Output | Select-Object -First 1)".Trim()
    $RemoteShaResult = Invoke-QueGit -WorkingDir $CloneRoot -GitArgs @("rev-parse", "--verify", "--quiet", "refs/remotes/origin/$Branch") -AllowFailure
    $RemoteSha = if ($RemoteShaResult.ExitCode -eq 0) { "$($RemoteShaResult.Output | Select-Object -First 1)".Trim() } else { "0" * 40 }
    $Url = "$((Invoke-QueGit -WorkingDir $CloneRoot -GitArgs @("remote", "get-url", "origin")).Output | Select-Object -First 1)".Trim()
    WC "Running the repository's pre-push checks for $Branch..."
    $StartInfo = New-Object System.Diagnostics.ProcessStartInfo
    $StartInfo.FileName = Get-QueShell
    # sh pipes the ref line into the hook itself: .NET's redirected stdin would start with a UTF-8 BOM, which
    # the hook would read as part of the ref. Arguments: hook, remote, URL, ref line; stderr folds into stdout.
    $RefLine = "refs/heads/$Branch $Sha refs/heads/$Branch $RemoteSha"
    $StartInfo.Arguments = "-c 'printf ""%s\n"" ""`$3"" | ""`$0"" ""`$1"" ""`$2"" 2>&1' ""$($Hook -replace '\\', '/')"" origin ""$Url"" ""$RefLine"""
    $StartInfo.WorkingDirectory = $CloneRoot
    $StartInfo.UseShellExecute = $false
    $StartInfo.RedirectStandardOutput = $true
    $Process = [System.Diagnostics.Process]::Start($StartInfo)
    $Output = $Process.StandardOutput.ReadToEnd()
    $Process.WaitForExit()
    if ($Output.Trim()) { Write-Host $Output.TrimEnd() }
    if ($Process.ExitCode -ne 0) {
        throw "The repository's pre-push hook refused to publish $Branch (exit code $($Process.ExitCode)). Nothing was merged."
    }
}

function Invoke-QueForgeApi {
    param([string]$WorkspaceRoot, [string]$Method, [string]$Path, [object]$Body = $null)
    $Token = Get-SecureForgeToken -WorkspaceRoot $WorkspaceRoot
    if (-not $Token) { throw "No $script:QueForgeLabel token found in $WorkspaceRoot\env\forge." }
    $Params = @{
        Method = $Method
        Uri = "$script:QueApiBase$Path"
        Headers = @{ Authorization = "token $Token"; 'Cache-Control' = 'no-store' }
        UseBasicParsing = $true
        ErrorAction = 'Stop'
    }
    if ($null -ne $Body) {
        $Params.Body = [System.Text.Encoding]::UTF8.GetBytes(($Body | ConvertTo-Json -Depth 5))
        $Params.ContentType = 'application/json; charset=utf-8'
    }
    return Invoke-RestMethod @Params
}

function Get-QueOpenPullRequest {
    # The open pull request from $Branch into main, or $null
    param([string]$WorkspaceRoot, [string]$Branch)
    $RepoPath = "/repos/$script:QueForgeOwner/$script:QueForgeRepo"
    if ($script:QueIsGitHub) {
        $Pulls = @(Invoke-QueForgeApi -WorkspaceRoot $WorkspaceRoot -Method Get -Path "$RepoPath/pulls?state=open&base=$($script:QueMainBranch)&head=$($script:QueForgeOwner):$Branch")
        return ($Pulls | Select-Object -First 1)
    }
    for ($Page = 1; $Page -le 10; $Page++) {
        $Pulls = @(Invoke-QueForgeApi -WorkspaceRoot $WorkspaceRoot -Method Get -Path "$RepoPath/pulls?state=open&limit=50&page=$Page")
        $Match = $Pulls | Where-Object { $_.head.ref -eq $Branch -and $_.base.ref -eq $script:QueMainBranch } | Select-Object -First 1
        if ($Match) { return $Match }
        if ($Pulls.Count -lt 50) { break }
    }
    return $null
}

function Invoke-QueMergePullRequest {
    # Merges a pull request on the forge with a merge commit, only if its head is still $HeadSha (the commit the
    # pre-push checks saw), so a later push to the branch cannot ride along. Returns $true once merged, or
    # $false with the reason shown.
    param([string]$WorkspaceRoot, [object]$PullRequest, [string]$HeadSha)
    $PullPath = "/repos/$script:QueForgeOwner/$script:QueForgeRepo/pulls/$($PullRequest.number)"
    # The forge works out whether a new pull request can merge in the background; give it a few tries
    for ($Attempt = 1; $Attempt -le 5; $Attempt++) {
        try {
            if ($script:QueIsGitHub) {
                Invoke-QueForgeApi -WorkspaceRoot $WorkspaceRoot -Method Put -Path "$PullPath/merge" -Body @{ merge_method = "merge"; sha = $HeadSha } | Out-Null
            } else {
                Invoke-QueForgeApi -WorkspaceRoot $WorkspaceRoot -Method Post -Path "$PullPath/merge" -Body @{ Do = "merge"; head_commit_id = $HeadSha } | Out-Null
            }
            return $true
        } catch {
            $Reason = $_.Exception.Message
            if ($_.ErrorDetails -and $_.ErrorDetails.Message) { $Reason = "$Reason $($_.ErrorDetails.Message)" }
            if ($Attempt -eq 5) {
                WY "$script:QueForgeLabel did not merge pull request #$($PullRequest.number): $Reason"
                return $false
            }
            Start-Sleep -Seconds 2
        }
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
        $WorkBranch = Get-QueDefaultWorkBranch -CloneRoot $CloneRoot
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
    if (-not $SourceCloneRoot) {
        throw "A source clone path is required for 'que load'."
    }
    $BranchSpec = Resolve-QueWorkBranchInput -CloneRoot $SourceCloneRoot -Name $Name
    if (-not $BranchSpec) {
        throw "Invalid work branch name for 'que load': $Name"
    }
    $BranchName = $BranchSpec.WorkBranch
    $FolderName = $BranchSpec.Folder
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
            WG "Found existing clone for $BranchName at $ExistingCloneRoot"
        }
        return $ExistingCloneRoot
    }
    $RemoteCheck = Invoke-QueGit -WorkingDir $SourceCloneRoot -GitArgs @("ls-remote", "--exit-code", "origin", "refs/heads/$BranchName") -AllowFailure
    if ($RemoteCheck.ExitCode -ne 0) {
        throw "Work branch $BranchName does not exist on origin."
    }
    $TargetClonePath = Join-Path $WorkspaceRoot "repo\$FolderName"
    if (Test-Path $TargetClonePath) {
        $CurrentBranch = Invoke-QueGit -WorkingDir $TargetClonePath -GitArgs @("rev-parse", "--abbrev-ref", "HEAD") -AllowFailure
        $CurrentBranchName = if ($CurrentBranch.ExitCode -eq 0) { $CurrentBranch.Output | Select-Object -First 1 } else { "(unknown)" }
        throw "Clone path already exists at $TargetClonePath (current branch: $CurrentBranchName). Please open that clone or choose a different branch name."
    }
    WC "Loading $BranchName into a new clone..."
    # New-QueClone switches to the recorded work branch, tracking origin's copy
    $CloneRoot = Invoke-QueNewCommand -WorkspaceRoot $WorkspaceRoot -CloneName $FolderName -WorkBranch $BranchName -SkipLaunch
    if ((Get-QueCurrentBranch -CloneRoot $CloneRoot) -ne $BranchName) {
        throw "Failed to switch clone to $BranchName."
    }
    WG "Loaded $BranchName into clone $(Split-Path $CloneRoot -Leaf)"
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
    $BranchSpec = Resolve-QueWorkBranchInput -CloneRoot $CloneRoot -Name $Name
    if (-not $BranchSpec) {
        throw "Invalid work branch name for 'que import': $Name"
    }
    $SourceBranch = $BranchSpec.WorkBranch
    Invoke-QueGit -WorkingDir $CloneRoot -GitArgs @("fetch", "origin", $SourceBranch) | Out-Null
    $RemoteCheck = Invoke-QueGit -WorkingDir $CloneRoot -GitArgs @("show-ref", "--verify", "refs/remotes/origin/$SourceBranch") -AllowFailure
    if ($RemoteCheck.ExitCode -ne 0) {
        throw "Work branch $SourceBranch not found on origin."
    }
    Invoke-QueMerge -CloneRoot $CloneRoot -Source ("origin/$SourceBranch") -Message ("que: import {0}" -f $SourceBranch) | Out-Null
    WG "Imported $SourceBranch into $CurrentBranch"
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
    $BranchSpec = Resolve-QueCloneName -Name $Name -Login (Get-QueLogin -CloneRoot $CloneRoot)
    if (-not $BranchSpec) {
        throw "Invalid work branch name for 'que rename': $Name"
    }
    $NewBranch = $BranchSpec.WorkBranch
    if ($CurrentBranch -eq $NewBranch) {
        Write-Host "Branch already named $NewBranch" -ForegroundColor Gray
        return $NewBranch
    }
    $OldBranch = $CurrentBranch
    Invoke-QueGit -WorkingDir $CloneRoot -GitArgs @("branch", "-m", $NewBranch) | Out-Null
    Invoke-QuePushWithRetry -CloneRoot $CloneRoot -Branch $NewBranch | Out-Null
    Invoke-QueGit -WorkingDir $CloneRoot -GitArgs @("push", "origin", ":$OldBranch") -AllowFailure | Out-Null
    WG "Renamed $OldBranch to $NewBranch locally and on origin."
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
    WG "Reset to origin/$($script:QueMainBranch). Local changes stashed."
}

function Invoke-QuePublishCommand {
    # Gets the current work into main through a pull request: back up the branch, run the repository's pre-push
    # checks on it, then open (or reuse) the pull request and merge it on the forge. Main is not merged into the
    # branch first: the forge does the merge, so publishing adds no commit that would need checking again.
    param([string]$CloneRoot, [string]$TagName)
    $WorkspaceRoot = Split-Path (Split-Path $CloneRoot -Parent) -Parent
    $WorkBranch = Invoke-QueSaveCommand -CloneRoot $CloneRoot
    Invoke-QueGit -WorkingDir $CloneRoot -GitArgs @("fetch", "origin", $script:QueMainBranch) | Out-Null
    $Head = "$((Invoke-QueGit -WorkingDir $CloneRoot -GitArgs @("rev-parse", "HEAD")).Output | Select-Object -First 1)".Trim()
    $TagTarget = "origin/$($script:QueMainBranch)"
    $Ahead = [int]"$((Invoke-QueGit -WorkingDir $CloneRoot -GitArgs @("rev-list", "--count", "origin/$($script:QueMainBranch)..HEAD")).Output | Select-Object -First 1)".Trim()
    if ($Ahead -eq 0) {
        WG "$WorkBranch has nothing that is not already in $script:QueMainBranch."
    } else {
        # What gets checked and merged is the commit origin has, which must be this clone's HEAD
        $OriginHead = "$((Invoke-QueGit -WorkingDir $CloneRoot -GitArgs @("ls-remote", "origin", "refs/heads/$WorkBranch")).Output | Select-Object -First 1)".Split("`t")[0].Trim()
        if ($OriginHead -ne $Head) {
            throw "origin's $WorkBranch is at $OriginHead, not this clone's $Head. Bring them together (run 'que save' again), then publish."
        }
        $HooksPath = "$((Invoke-QueGit -WorkingDir $CloneRoot -GitArgs @("config", "--get", "core.hooksPath") -AllowFailure).Output | Select-Object -First 1)".Trim()
        if ((Test-Path (Join-Path $CloneRoot ".githooks")) -and -not $HooksPath) {
            WY "Warning: this repository ships git hooks in .githooks, but they are not enabled in this clone, so its push checks will not run."
            WY "Enable them with: git config core.hooksPath .githooks"
        }
        Invoke-QuePrePushHook -CloneRoot $CloneRoot -Branch $WorkBranch
        $PullRequest = Get-QueOpenPullRequest -WorkspaceRoot $WorkspaceRoot -Branch $WorkBranch
        if ($PullRequest) {
            WC "Using open pull request #$($PullRequest.number): $($PullRequest.html_url)"
        } else {
            $Commits = @((Invoke-QueGit -WorkingDir $CloneRoot -GitArgs @("log", "--no-merges", "--format=- %s", "-n", "50", "origin/$($script:QueMainBranch)..HEAD")).Output)
            $PullRequest = Invoke-QueForgeApi -WorkspaceRoot $WorkspaceRoot -Method Post -Path "/repos/$script:QueForgeOwner/$script:QueForgeRepo/pulls" -Body @{
                title = "Publish $WorkBranch"
                head  = $WorkBranch
                base  = $script:QueMainBranch
                body  = "Published with 'que publish'.`n`n$($Commits -join "`n")"
            }
            WC "Opened pull request #$($PullRequest.number): $($PullRequest.html_url)"
        }
        if (-not (Invoke-QueMergePullRequest -WorkspaceRoot $WorkspaceRoot -PullRequest $PullRequest -HeadSha $Head)) {
            WY "Your work is pushed and the pull request is open: $($PullRequest.html_url)"
            WY "Resolve what the forge reports (for example run 'que update' to merge main again), then run 'que publish' again."
            return $WorkBranch
        }
        WG "Merged pull request #$($PullRequest.number) into $script:QueMainBranch."
        $TagTarget = $null
        try {
            $TagTarget = "$((Invoke-QueForgeApi -WorkspaceRoot $WorkspaceRoot -Method Get -Path "/repos/$script:QueForgeOwner/$script:QueForgeRepo/pulls/$($PullRequest.number)").merge_commit_sha)".Trim()
        } catch { }
        if (-not $TagTarget -and $TagName) {
            WY "Could not read the merge commit of pull request #$($PullRequest.number); tag $TagName was not moved."
            $TagName = $null
        }
    }
    Invoke-QueGit -WorkingDir $CloneRoot -GitArgs @("fetch", "origin", $script:QueMainBranch) | Out-Null

    # Push LFS objects to the git host for disaster recovery
    WC "Publishing LFS files to $script:QueForgeLabel for backup..."
    Push-Location $CloneRoot
    try {
        # Check if there are any LFS files to push
        $LfsFiles = git lfs ls-files 2>&1
        if ($LASTEXITCODE -eq 0 -and $LfsFiles) {
            WY "Uploading LFS objects to $script:QueForgeLabel (this provides disaster recovery)..."
            git lfs push --all origin 2>&1 | ForEach-Object {
                if ($_ -match "Uploading|Upload|Counting|^Git LFS:") {
                    Write-Host "  $_" -ForegroundColor Gray
                }
            }
            if ($LASTEXITCODE -eq 0) {
                WG "LFS objects backed up to $script:QueForgeLabel successfully"
            } else {
                WY "Warning: LFS push encountered issues (exit code: $LASTEXITCODE)"
                WY "Pointer files were published, but some LFS objects may not be backed up to $script:QueForgeLabel"
            }
        } else {
            Write-Host "No LFS files to back up" -ForegroundColor Gray
        }
    } catch {
        WY "Warning: Failed to push LFS objects: $($_.Exception.Message)"
        WY "Continuing - pointer files were published successfully"
    } finally {
        Pop-Location
    }

    if ($TagName) {
        # The tag names the merge the forge just made (or main itself when there was nothing to merge), which the
        # repository's push checks never saw as a branch tip; what it adds went through them as a branch (above,
        # or in the pull requests that built main), so the tag push skips them
        Invoke-QueGit -WorkingDir $CloneRoot -GitArgs @("tag", "-f", $TagName, $TagTarget) | Out-Null
        Invoke-QueGit -WorkingDir $CloneRoot -GitArgs @("push", "--no-verify", "-f", "origin", $TagName) | Out-Null
        WG "Moved tag $TagName to $script:QueMainBranch and pushed."
    }
    return $WorkBranch
}

function Invoke-QueNewCommand {
    param([string]$WorkspaceRoot, [string]$CloneName = $null, [string]$WorkBranch = $null, [switch]$SkipLaunch = $false)
    WC "Creating new clone from origin/$($script:QueMainBranch)..."
    $CloneRoot = New-QueClone -WorkspaceRoot $WorkspaceRoot -IsFirstClone:$false -ShouldClone:$true -CloneName $CloneName -WorkBranch $WorkBranch
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
    WC "Cloning current branch state into a new workspace clone..."
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
    $InstallDir = Get-UnrealEngineInstallDirectory -EngineVersion $EngineVersion
    if (-not $InstallDir) {
        throw "Unreal Engine $EngineVersion is not installed. Install it via Epic Games Launcher."
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
    # Go through Build.bat so UBT runs on the engine's bundled .NET runtime rather than requiring a system-wide install
    $BuildBatchFile = Join-Path (Get-UnrealEngineDirectory -UProjectPath $UProjectPath) "Engine\Build\BatchFiles\Build.bat"
    WC "Generating project files..."
    & $BuildBatchFile -ProjectFiles "-Project=`"$UProjectPath`"" -Game -Silent | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "Project file generation failed with exit code $LASTEXITCODE"
    }
    WG "Project files generated successfully"
}

function Invoke-UnrealBuild {
    param([string]$UProjectPath)
    $EngineDir = Get-UnrealEngineDirectory -UProjectPath $UProjectPath
    $BuildBatchFile = Join-Path $EngineDir "Engine\Build\BatchFiles\Build.bat"
    $ProjectName = [System.IO.Path]::GetFileNameWithoutExtension($UProjectPath)
    if (-not (Test-Path $BuildBatchFile)) {
        throw "Build.bat not found at: $BuildBatchFile"
    }
    WC "Building $ProjectName Editor (Development Win64)..."
    # Out-Host: the build log must reach the screen, not become part of this function's $true/$false result
    & $BuildBatchFile "${ProjectName}Editor" Win64 Development "-Project=`"$UProjectPath`"" -Progress -NoEngineChanges -NoHotReloadFromIDE | Out-Host
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Build failed with exit code $LASTEXITCODE"
        return $false
    }
    WG "Build completed successfully"
    return $true
}

function Invoke-UnrealEditor {
    param([string]$UProjectPath)
    $EngineDir = Get-UnrealEngineDirectory -UProjectPath $UProjectPath
    $EditorPath = Join-Path $EngineDir "Engine\Binaries\Win64\UnrealEditor.exe"
    if (-not (Test-Path $EditorPath)) {
        throw "UnrealEditor.exe not found at: $EditorPath"
    }
    WC "Launching Unreal Editor..."
    Start-Process -FilePath $EditorPath -ArgumentList "`"$UProjectPath`"" -WorkingDirectory (Split-Path $UProjectPath -Parent)
    WG "Editor launched"
}

function Invoke-UnrealClean {
    param([string]$UProjectPath)
    $ProjectDir = Split-Path $UProjectPath -Parent
    $ProjectName = [System.IO.Path]::GetFileNameWithoutExtension($UProjectPath)
    try {
        $EngineDir = Get-UnrealEngineDirectory -UProjectPath $UProjectPath
        $CleanBatchFile = Join-Path $EngineDir "Engine\Build\BatchFiles\Clean.bat"
        if (Test-Path $CleanBatchFile) {
            WC "Running Clean.bat..."
            & $CleanBatchFile $ProjectName Win64 Development
            if ($LASTEXITCODE -eq 0) {
                WG "Clean completed successfully"
                return
            }
            Write-Warning "Clean.bat failed, falling back to manual cleanup"
        }
    } catch {
        Write-Warning "Could not run Clean.bat: $($_.Exception.Message)"
    }
    WC "Performing manual cleanup..."
    $FoldersToDelete = @("Binaries", "Intermediate", "Saved", "DerivedDataCache")
    foreach ($Folder in $FoldersToDelete) {
        $FolderPath = Join-Path $ProjectDir $Folder
        if (Test-Path $FolderPath) {
            WY "Deleting $Folder..."
            Remove-Item $FolderPath -Recurse -Force
        }
    }
    $SlnFiles = Get-ChildItem -Path (Split-Path $ProjectDir -Parent) -Filter "*.sln" -ErrorAction SilentlyContinue
    foreach ($SlnFile in $SlnFiles) {
        WY "Deleting $($SlnFile.Name)..."
        Remove-Item $SlnFile.FullName -Force
    }
    WG "Clean completed. Next build will be a full rebuild."
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
    WY "`nSelect build configuration:"
    WW "1. Development"
    WW "2. Shipping"
    WW "3. DebugGame"
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
    WG "Using configuration: $BuildConfig"
    WC "`nPackaging client build ($BuildConfig)..."
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
    WC "`nPackaging server build ($BuildConfig)..."
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
    WC "`nOpening Unreal Engine project..."
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
        WG "Editor launched successfully!"
    } catch {
        Write-Error "Failed to launch editor: $($_.Exception.Message)"
    }
}

function Build-UnrealProject {
    param([string]$CloneRoot)
    WC "`nBuilding Unreal Engine project..."
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
            WG "Build completed successfully!"
        } else {
            Write-Error "Build failed."
        }
    } catch {
        Write-Error "Build failed: $($_.Exception.Message)"
    }
}

function Clean-UnrealProject {
    param([string]$CloneRoot)
    WC "`nCleaning Unreal Engine project..."
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
    WC "`nPackaging Unreal Engine project..."
    $UProjectPath = Find-UProjectFile -CloneRoot $CloneRoot
    if (-not $UProjectPath) {
        Write-Error "No .uproject file found."
        return
    }
    try {
        $PackageResult = Invoke-UnrealPackage -UProjectPath $UProjectPath
        if ($PackageResult) {
            WG "`nPackaging complete ($($PackageResult.Configuration))!"
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
    $SyncThingInfo = Ensure-SyncThingRunning -WorkspaceRoot $WorkspaceRoot
    if (-not $SyncThingInfo) {
        Write-Host "SyncThing is not available" -ForegroundColor Red
        return
    }
    $SyncThingExe = Get-SyncThingExecutable
    if (-not $SyncThingExe) {
        Write-Host "SyncThing executable not found" -ForegroundColor Red
        return
    }
    $SyncThingHome = Join-Path $WorkspaceRoot "env\syncthing-home"
    $GuiAddress = $SyncThingInfo.GuiAddress
    $ApiKey = $SyncThingInfo.ApiKey
    $RawAddress = Invoke-SyncThingCli $SyncThingExe $SyncThingHome $GuiAddress $ApiKey -Args @("config", "gui", "raw-address", "get") -QuietErrors
    $RawAddress = $RawAddress | Select-Object -First 1
    if ($RawAddress) {
        $RawAddress = $RawAddress.Trim()
    }
    if (-not $RawAddress) {
        $RawAddress = $GuiAddress
    }
    if ($RawAddress -notmatch '^https?://') {
        $RawAddress = "http://$RawAddress"
    }
    Start-Process $RawAddress
}

function Show-WorkspaceInfo {
    param([string]$WorkspaceRoot, [string]$CloneRoot)
    $CloneName = Split-Path $CloneRoot -Leaf
    WC "`n==============================================================="
    WG "  QUE Workspace Information"
    WC "==============================================================="
    WY "`nWorkspace:"
    Write-Host "  Root: $WorkspaceRoot"
    Write-Host "  Version: $(Get-Content "$WorkspaceRoot\.que\workspace-version" -ErrorAction SilentlyContinue)"
    WY "`nClone:"
    Write-Host "  Name: $CloneName"
    Write-Host "  Root: $CloneRoot"
    $RepoVersion = Get-Content "$WorkspaceRoot\.que\repo\$CloneName\repo-version" -ErrorAction SilentlyContinue
    Write-Host "  Version: $(if ($RepoVersion) { $RepoVersion } else { 'Not set' })"
    WY "`nGit host:"
    Write-Host "  Host: $script:QueForgeHost"
    Write-Host "  Repository: $script:QueForgeOwner/$script:QueForgeRepo"
    $GitUserResult = Invoke-QueGit -WorkingDir $CloneRoot -GitArgs @("config", "user.name") -AllowFailure
    if ($GitUserResult.ExitCode -eq 0) {
        $GitUser = $GitUserResult.Output | Select-Object -First 1
        $GitEmailResult = Invoke-QueGit -WorkingDir $CloneRoot -GitArgs @("config", "user.email") -AllowFailure
        $GitEmail = $GitEmailResult.Output | Select-Object -First 1
        $GitBranchResult = Invoke-QueGit -WorkingDir $CloneRoot -GitArgs @("rev-parse", "--abbrev-ref", "HEAD") -AllowFailure
        if ($GitBranchResult.ExitCode -eq 0) {
            $GitBranch = $GitBranchResult.Output | Select-Object -First 1
            Write-Host "  User: $GitUser <$GitEmail>"
            Write-Host "  Branch: $GitBranch"
        } else {
            Write-Host "  User: $GitUser <$GitEmail>"
            Write-Host "  Branch: (unable to determine)"
        }
    }
    $UProjectPath = Find-UProjectFile -CloneRoot $CloneRoot
    if ($UProjectPath) {
        WY "`nUnreal Engine:"
        Write-Host "  Project: $UProjectPath"
        Write-Host "  Version: $script:QueUnrealEngineVersion"
    } else {
        WY "`nUnreal Engine:"
        Write-Host "  No .uproject file found"
    }
    WY "`nSyncThing:"
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
    WC "`n===============================================================`n"
}

function Show-QueHelp {
    param([string]$DefaultPublishTag)
    WC "`nAvailable commands:"
    Write-Host "  help                     - Show this help text"
    Write-Host "  open                     - Generate project files, build, and launch the editor"
    Write-Host "  build                    - Build the editor target"
    Write-Host "  clean                    - Remove intermediates for a clean rebuild"
    Write-Host "  package                  - Package client/server builds"
    Write-Host "  syncthing                - Open the SyncThing web UI"
    Write-Host "  deps                     - Install or repair prerequisites (MSVC toolchain, Unreal Engine)"
    Write-Host "  info                     - Display workspace and clone info"
    Write-Host "  lfs                      - Replace LFS pointer files with their content (shared store, SyncThing, origin)"
    Write-Host "  new [name]               - Create a new clone from origin/main on que/<you>/<name>"
    Write-Host "  clone [name]             - Duplicate the current clone's state onto que/<you>/<name>"
    Write-Host "  save                     - Commit and back up the current branch (skips repository push checks)"
    Write-Host "  load <branch>            - Load que/<you>/<branch> or que/<owner>/<branch> into a clone (reuses existing if present)"
    Write-Host "  import <branch>          - Merge origin/que/<you>/<branch> or que/<owner>/<branch> into the current branch"
    Write-Host "  update                   - Merge latest origin/main into the current branch"
    Write-Host "  rename <branch>          - Rename current work branch to que/<you>/<branch>"
    Write-Host "  reset                    - Stash changes and reset to origin/main"
    Write-Host "  publish [tag=$DefaultPublishTag] - Run the repository's push checks, merge into main through a pull request, and tag it"
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
        WG "QUE commands loaded"
        return
    }
    # MODE 2: RUN FROM URL - Workspace/Clone Creation
    if ($IsRunFromUrl) {
        $UrlOwner = $null
        $UrlRepo = $null
        $UrlHost = $null
        $ScriptName = $null
        $IsBootstrapScript = $false
        if ($queUrl -match 'githubusercontent\.com/([^/]+)/([^/]+)/[^/]+/(.+)$') {
            $UrlHost = 'github.com'
            $UrlOwner = $matches[1]
            $UrlRepo = $matches[2]
            $ScriptName = $matches[3]
        } elseif ($queUrl -match '^https?://([^/]+)/([^/]+)/([^/]+)/raw/branch/[^/]+/(.+)$') {
            # Forgejo / Gitea raw URL: https://HOST/OWNER/REPO/raw/branch/BRANCH/FILE
            $UrlHost = $matches[1]
            $UrlOwner = $matches[2]
            $UrlRepo = $matches[3]
            $ScriptName = $matches[4]
        }
        if ($UrlHost) { Initialize-QueForgeConfig -ForgeHost $UrlHost }
        if ($ScriptName -eq 'que57.ps1') {
            $IsBootstrapScript = $true
        }
        # Early check: If current folder is not empty and not a QUE workspace, error immediately
        $CurrentFolderIsQueWorkspace = Test-Path ".que"
        if (-not $CurrentFolderIsQueWorkspace) {
            $CurrentItems = Get-ChildItem -Force -ErrorAction SilentlyContinue
            if ($CurrentItems.Count -gt 0) {
                Write-Error "Current folder is not empty. QUE workspace must be initialized in an empty folder."
                WY "Please create and navigate to an empty folder, then run this command again."
                return
            }
        }
        $WorkspaceRoot = Find-QueWorkspace
        if ($WorkspaceRoot) {
            $ExistingOwner = Get-Content "$WorkspaceRoot\.que\forge-owner"
            $ExistingRepo = Get-Content "$WorkspaceRoot\.que\forge-repo"
            if ($UrlOwner -and $UrlRepo -and -not $IsBootstrapScript) {
                if ($ExistingOwner -eq $UrlOwner -and $ExistingRepo -eq $UrlRepo) {
                    WG "Found matching workspace at: $WorkspaceRoot"
                    New-QueClone -WorkspaceRoot $WorkspaceRoot -ShouldClone $true
                } else {
                    Write-Error "Current workspace is for $ExistingOwner/$ExistingRepo, but you're trying to create $UrlOwner/$UrlRepo"
                    WY "Please run this command in a folder outside this workspace to create a new workspace, or within a $UrlRepo workspace to create a new clone."
                    return
                }
            } else {
                Write-Error "Already in a QUE workspace for $ExistingOwner/$ExistingRepo"
                WY "To create a new workspace, run this command outside of an existing workspace."
                return
            }
        } else {
            $CurrentItems = Get-ChildItem -Force -ErrorAction SilentlyContinue
            if ($CurrentItems.Count -gt 0) {
                Write-Error "Current folder is not empty. QUE workspace must be initialized in an empty folder."
                WY "Please create and navigate to an empty folder, then run this command again."
                return
            }
            WC "`nQUE 5.7 - Quick Unreal Engine Project Manager"
            $WorkspaceRoot = (Get-Location).Path
            if ($IsBootstrapScript) {
                ###QUE_CREATION_MODE_BEGIN###
                WG "Setting up a new project workspace...`n"
                $HostInput = Read-Host "Enter git host - GitHub or a Forgejo/Gitea server [$($script:QueForgeHost)]"
                if (-not [string]::IsNullOrWhiteSpace($HostInput)) {
                    Initialize-QueForgeConfig -ForgeHost $HostInput
                }
                WG "Using git host: $($script:QueForgeHost)"
                $CurrentFolderName = Split-Path $WorkspaceRoot -Leaf
                $DefaultRepoName = $CurrentFolderName -replace '[^a-zA-Z0-9_-]', ''
                $ForgeRepo = Read-Host "Enter new repository name [$DefaultRepoName]"
                if ([string]::IsNullOrWhiteSpace($ForgeRepo)) {
                    $ForgeRepo = $DefaultRepoName
                }
                if ([string]::IsNullOrWhiteSpace($ForgeRepo)) {
                    Write-Error "Repository name cannot be empty"
                    return
                }
                WG "Using repository name: $ForgeRepo"
                if ($queToken) {
                    $Token = $queToken
                } else {
                    $SecureToken = Read-Host "Enter $script:QueForgeLabel access token" -AsSecureString
                    $Token = [System.Net.NetworkCredential]::new('', $SecureToken).Password
                }
                $UserInfo = Test-ForgeToken -Token $Token
                if (-not $UserInfo) {
                    Write-QueTokenError
                    return
                }
                WG "Authenticated as: $($UserInfo.login)"
                $ForgeOwner = $UserInfo.login
                New-QueWorkspace -ForgeOwner $ForgeOwner -ForgeRepo $ForgeRepo -Token $Token -UserInfo $UserInfo
                ###QUE_CREATION_MODE_END###
            } elseif ($UrlOwner -and $UrlRepo) {
                WG "Joining project: $UrlOwner/$UrlRepo`n"
                if ($queToken) {
                    $Token = $queToken
                } else {
                    $SecureToken = Read-Host "Enter $script:QueForgeLabel access token" -AsSecureString
                    $Token = [System.Net.NetworkCredential]::new('', $SecureToken).Password
                }
                $UserInfo = Test-ForgeToken -Token $Token
                if (-not $UserInfo) {
                    Write-QueTokenError
                    return
                }
                WG "Authenticated as: $($UserInfo.login)"
                New-QueWorkspace -ForgeOwner $UrlOwner -ForgeRepo $UrlRepo -Token $Token -UserInfo $UserInfo
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
            Import-QueWorkspaceForge $WorkspaceRoot
            WC "Ensuring SyncThing is running..."
            $SyncThingInfo = Ensure-SyncThingRunning -WorkspaceRoot $WorkspaceRoot
            $CurrentDeviceId = $SyncThingInfo.DeviceId
            if ((-not [string]::IsNullOrWhiteSpace($CurrentDeviceId)) -and $script:SyncThingDevices -and ($script:SyncThingDevices -notcontains $CurrentDeviceId)) {
                WY "Adding current device to SyncThing devices list..."
                $script:SyncThingDevices += $CurrentDeviceId
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
                WG "Script updated with current device. Please commit this change to share with team."
            }
            if ($script:SyncThingDevices -and $script:SyncThingDevices.Count -gt 0) {
                Update-SyncThingDevices -WorkspaceRoot $WorkspaceRoot -DeviceIds $script:SyncThingDevices -SyncThingInfo $SyncThingInfo
            }
            $ScriptPath = $PSCommandPath
            $CloneRoot = Split-Path $ScriptPath -Parent
            $CloneName = Split-Path $CloneRoot -Leaf
            Write-UEGitConfigFiles -CloneRoot $CloneRoot
            $global:QueCloneRoot = $CloneRoot
            $global:QueWorkspaceRoot = $WorkspaceRoot
            $global:QueCloneName = $CloneName
            $global:QueLogin = Get-QueLogin -CloneRoot $CloneRoot
            $global:QueDefaultPublishTag = $script:QueDefaultPublishTag

            function global:que {
                param([string]$Command, [string]$Arg)
                if (-not $Command) { Show-QueHelp -DefaultPublishTag $global:QueDefaultPublishTag; return }
                $Command = $Command.ToLower()
                try {
                    switch ($Command) {
                        "open"      { Open-UnrealProject -CloneRoot $global:QueCloneRoot }
                        "build"     { Build-UnrealProject -CloneRoot $global:QueCloneRoot }
                        "clean"     { Clean-UnrealProject -CloneRoot $global:QueCloneRoot }
                        "package"   { Package-UnrealProject -CloneRoot $global:QueCloneRoot }
                        "syncthing" { Open-SyncThingBrowser -WorkspaceRoot $global:QueWorkspaceRoot }
                        "deps"      { Install-AllDependencies }
                        "info"      { Show-WorkspaceInfo -WorkspaceRoot $global:QueWorkspaceRoot -CloneRoot $global:QueCloneRoot }
                        "lfs"       { Sync-QueLfsFiles -CloneRoot $global:QueCloneRoot -WorkspaceRoot $global:QueWorkspaceRoot | Out-Null }
                        "new"       { Invoke-QueNewCommand -WorkspaceRoot $global:QueWorkspaceRoot -CloneName $Arg | Out-Null }
                        "clone"     { Invoke-QueCloneCommand -WorkspaceRoot $global:QueWorkspaceRoot -SourceCloneRoot $global:QueCloneRoot -CloneName $Arg | Out-Null }
                        "save"      { Invoke-QueSaveCommand -CloneRoot $global:QueCloneRoot | Out-Null }
                        "load"      { Invoke-QueLoadCommand -WorkspaceRoot $global:QueWorkspaceRoot -SourceCloneRoot $global:QueCloneRoot -Name $Arg | Out-Null }
                        "import"    { Invoke-QueImportCommand -CloneRoot $global:QueCloneRoot -Name $Arg | Out-Null }
                        "update"    { Invoke-QueUpdateCommand -CloneRoot $global:QueCloneRoot | Out-Null }
                        "rename"    { Invoke-QueRenameCommand -CloneRoot $global:QueCloneRoot -Name $Arg | Out-Null }
                        "reset"     { Invoke-QueResetCommand -CloneRoot $global:QueCloneRoot | Out-Null }
                        "publish"   { Invoke-QuePublishCommand -CloneRoot $global:QueCloneRoot -TagName $Arg | Out-Null }
                        "help"      { Show-QueHelp -DefaultPublishTag $global:QueDefaultPublishTag }
                        "exit"      { exit }
                        default     { Write-Host "Unknown command: $Command. Type 'que help' for a list of commands." -ForegroundColor Red; return }
                    }
                    if ($Command -notin @("exit", "help")) {
                        Ensure-QueCloneOnWorkBranch -CloneRoot $global:QueCloneRoot -SkipIfDirty:$true
                    }
                } catch {
                    Write-Host $_.Exception.Message -ForegroundColor Red
                }
            }

            $QueSubcommands = @('open','build','clean','package','syncthing','deps','info','lfs','new','clone','save','load','import','update','rename','reset','publish','help','exit')
            $QueCompleter = {
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

                $elements = @($commandAst.CommandElements)
                if ($elements.Count -eq 0) { return }

                $currentArgIndex = if ($wordToComplete -eq '' -and $commandAst.Extent.Text -match '\s$') {
                    $elements.Count
                } else {
                    [Math]::Max(0, $elements.Count - 1)
                }

                if ($currentArgIndex -eq 1) {
                    $QueSubcommands | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
                        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                    }
                    return
                }

                if ($currentArgIndex -ne 2 -or $elements.Count -lt 2) { return }

                $subcommand = $elements[1].Value
                if ([string]::IsNullOrWhiteSpace($subcommand)) { return }
                $subcommand = $subcommand.ToLowerInvariant()
                if ($subcommand -notin @('load', 'import')) { return }
                if (-not $global:QueCloneRoot) { return }

                $branchNames = Get-QueRemoteWorkBranchNames -WorkingDir $global:QueCloneRoot
                if (-not $branchNames -or $branchNames.Count -eq 0) { return }

                $completionPrefix = ''
                if ($wordToComplete -like 'origin/que/*') {
                    $completionPrefix = 'origin/que/'
                } elseif ($wordToComplete -like 'que/*') {
                    $completionPrefix = 'que/'
                } elseif ($global:QueLogin) {
                    # Your own branches also complete without the owner, the way you would type them
                    $ownPrefix = "$($global:QueLogin)/"
                    $branchNames = @($branchNames | ForEach-Object {
                        if ($_.StartsWith($ownPrefix, [System.StringComparison]::OrdinalIgnoreCase)) { $_.Substring($ownPrefix.Length) }
                        $_
                    })
                }

                foreach ($branchName in $branchNames) {
                    $completionText = "$completionPrefix$branchName"
                    if ($completionText -like "$wordToComplete*") {
                        [System.Management.Automation.CompletionResult]::new($completionText, $completionText, 'ParameterValue', $completionText)
                    }
                }
            }.GetNewClosure()
            Register-ArgumentCompleter -CommandName que -ParameterName Command -ScriptBlock $QueCompleter
            Register-ArgumentCompleter -CommandName que -ParameterName Arg -ScriptBlock $QueCompleter

            WC "`n==============================================================="
            WG "  QUE - $script:QueForgeOwner/$script:QueForgeRepo"
            Ensure-QueCloneOnWorkBranch -CloneRoot $CloneRoot -SkipIfDirty:$true
            WY "  Clone: $CloneName ($(Get-QueCurrentBranch -CloneRoot $CloneRoot))"
            Write-Host "  Workspace: $WorkspaceRoot" -ForegroundColor Gray
            WC "==============================================================="
            WC "Type 'que <command>' or 'que help' for available commands.`n"
            if (-not (Get-UnrealEngineInstallDirectory -EngineVersion $QueUnrealEngineVersion) -or ((Get-QueBuildToolsPath) -and -not (Test-QueMsvcInstalled $QueMsvcComponents))) {
                WY "This machine is missing Unreal Engine $QueUnrealEngineVersion or the MSVC toolchain it builds with. Run 'que deps' to install them.`n"
            }
        }
    }
}

# ----------------------------------------------------------------------------
# SCRIPT ENTRY POINT
# ----------------------------------------------------------------------------
$IsDotSourced = $MyInvocation.InvocationName -eq '.'
# Mode 1 (manual dot-source) skips Invoke-QueMain so helper functions can be
# imported without side effects. The shortcut also dot-sources (so the injected
# `que` function survives into the -NoExit session), but sets $QueLaunchSession
# first so we still run Mode 3 here.
if ((-not $IsDotSourced) -or $QueLaunchSession) {
    Invoke-QueMain
    # The bootstrap one-liner leaves the token in the session as $queToken; forget it.
    Remove-Variable -Name queToken -Scope Global -ErrorAction SilentlyContinue
}

