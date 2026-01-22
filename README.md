# QUE - Quick Unreal Engine Project Manager

QUE (Quick UE) is a single-file PowerShell solution for managing Unreal Engine 5.7 projects with Git, GitLFS, and SyncThing integration.

This is the template repo for generating a new project. A copy of the que script in the generated repo is used to manage copies of that repo.

## Features

- **Single-file architecture**: No modules, no dependencies on external files
- **Fast, Cheap Clones**: Clones in a workspace share LFS depot
- **Fast, Cheap Bootstrapping**: SyncThing shares raw assets and bypasses remote LFS servers
- **Batteries Included**: Completely self-contained with built-in commands to build and package UE projects

## Getting Started

### Prerequisites

- Windows 10/11
- PowerShell 5.1 or later
- GitHub account with Personal Access Token (PAT)

### Create a New UE 5.7 Project

1. Create an empty directory for your workspace
2. Run this command in PowerShell:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ($queScript = (iwr -useb ($queUrl = "https://raw.githubusercontent.com/karlgluck/que/main/que57.ps1")).Content)
```

3. Follow the prompts to:
   - Enter your GitHub Personal Access Token
   - Specify repository name
   - Install dependencies (Git, GitLFS, SyncThing, Visual Studio, etc.)
   - Install Unreal Engine 5.7 via Epic Games Launcher

4. Create your Unreal project inside the clone directory


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
|       +-- que57-project.ps1 # Project management script
|       +-- ProjectName/     # Unreal project
+-- open-2025-11-26-A.lnk    # Shortcut to launch clone
```

## Management Commands

Once your workspace is set up, launch the management terminal using the shortcut or by running `que57-project.ps1`:

- **open** - Generate project files, build, and launch UE editor
- **build** - Build the editor target
- **clean** - Delete intermediate files for full rebuild
- **package** - Create standalone client and server builds
- **syncthing** - Open the SyncThing web UI
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
