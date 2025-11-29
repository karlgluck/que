# QUE - Quick Unreal Engine Project Manager

QUE (Quick UE) is a single-file PowerShell solution for managing Unreal Engine 5.7 projects with Git, GitLFS, and SyncThing integration.

## Features

- **Single-file architecture**: No modules, no dependencies on external files
- **Workspace management**: Multiple clones sharing LFS storage
- **Team collaboration**: SyncThing-based asset sharing
- **Simple workflow**: Create, build, and manage UE projects with simple commands
- **Self-contained**: All batteries included

## Getting Started

### Prerequisites

- Windows 10/11
- PowerShell 5.1 or later
- GitHub account with Personal Access Token (PAT)

### Create a New UE 5.7 Project

1. Create an empty directory for your workspace
2. Run this command in PowerShell:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ($queScript = (iwr ($queUrl = "https://raw.githubusercontent.com/karlgluck/que/main/que57.ps1")).Content)
```

3. Follow the prompts to:
   - Enter your GitHub Personal Access Token
   - Specify repository name
   - Install dependencies (Git, GitLFS, SyncThing, Visual Studio, etc.)
   - Install Unreal Engine 5.7 via Epic Games Launcher

4. Create your Unreal project inside the clone directory

### Join an Existing Project

Team members joining an existing QUE project should use the project-specific script:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ($queScript = (iwr ($queUrl = "https://raw.githubusercontent.com/USERNAME/REPONAME/main/que-REPONAME.ps1")).Content)
```

## Workspace Structure

```
workspace-root/
+-- .que/                    # Workspace metadata
+-- sync/                    # SyncThing-managed folders
|   +-- git-lfs/lfs/         # Shared LFS storage
|   +-- depot/               # Shared asset depot
+-- env/                     # Environment data (PAT, SyncThing)
+-- repo/                    # Repository clones
|   +-- 2025-11-26-A/        # Clone directory
|       +-- que-project.ps1  # Project management script
|       +-- ProjectName/     # Unreal project
+-- open-2025-11-26-A.lnk    # Shortcut to launch clone
```

## Management Commands

Once your workspace is set up, launch the management terminal using the shortcut or by running `que-REPONAME.ps1`:

- **open** - Generate project files, build, and launch UE editor
- **build** - Build the editor target
- **clean** - Delete intermediate files for full rebuild
- **pull** - Pull latest changes from GitHub (with stashing)
- **push** - Commit all changes and push to GitHub (with rebase)
- **package** - Create standalone client and server builds
- **info** - Display workspace and project information

## Creating GitHub Personal Access Token

1. Go to https://github.com/settings/tokens
2. Click "Generate new token (classic)"
3. Select scopes: `repo` (all), `workflow`
4. Generate and copy the token
5. Store it securely - you'll need it for workspace setup

## Design Philosophy

QUE trades some AutoDevEnv flexibility for simplicity:

- **Embedded files**: Everything in one script (large, but traceable)
- **Manual integration**: Bug fixes don't auto-propagate (prevents accidental breakage)
- **Version-specific**: Each UE version gets its own script
- **Self-contained**: No module updates or external dependencies

## Version Files

The `workspace-version` and `repo-version` files contain integer version numbers (initially "1"). These are for future manual upgrades only - not automatic updates. If you hand-edit the script to add new functionality, you can reference these versions to apply changes in order to older workspaces, then increment the version number.

## License

MIT License - Feel free to fork and customize for your projects!
