# QUE - Quick Unreal Engine Project Manager

QUE (Quick UE) is a single-file PowerShell solution for managing Unreal Engine 5.7 projects with Git, GitLFS, and SyncThing integration. It works with GitHub and with self-hosted Forgejo/Gitea servers.

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
- An account on GitHub **or** on a Forgejo/Gitea server, with an access token (see below)

### Create a New UE 5.7 Project

1. Create an empty directory for your workspace
2. Run this command in PowerShell:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ($queScript = (iwr -useb ($queUrl = "https://raw.githubusercontent.com/karlgluck/que/main/que57.ps1")).Content)
```

3. Follow the prompts to:
   - Choose the git host (press Enter for GitHub, or type your Forgejo/Gitea hostname)
   - Enter your access token (typed hidden; it is stored encrypted in the workspace and in Windows Credential Manager)
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
|   +-- kauilani/            # Clone directory (random Hawaiian-sounding name)
|       +-- que57-project.ps1 # Project management script
|       +-- ProjectName/     # Unreal project
+-- open-kauilani.lnk        # Shortcut to launch clone
```

## Management Commands

Once your workspace is set up, launch the management terminal using the shortcut or by running `que57-project.ps1`:

- **open** - Generate project files, build, and launch UE editor
- **build** - Build the editor target
- **clean** - Delete intermediate files for full rebuild
- **package** - Create standalone client and server builds
- **syncthing** - Open the SyncThing web UI
- **info** - Display workspace and project information

## Using a self-hosted Forgejo or Gitea server

QUE never hardcodes a hostname. The host is taken from the URL the script was fetched from, or from the prompt when you create a new project with the GitHub one-liner above. Everything else (repository creation, clone URLs, credential storage, LFS) follows from that.

- **New project:** run the one-liner above and answer the `Enter git host` prompt with your server's hostname, e.g. `forge.example.com`.
- **Joining a project:** the project's README carries a one-liner that already points at the right server; just run it.
- **Hosting `que` on your own server too (optional):** mirror this repo there and bootstrap from `https://forge.example.com/OWNER/que/raw/branch/main/que57.ps1` instead. The host is then detected and the prompt defaults to it.

The generated `que57-project.ps1` and each workspace's `.que/gh-host` remember the host, so existing workspaces keep working and older workspaces default to GitHub.

## Creating an access token

Only the person who *creates* a project needs repository-creation rights; people joining need read/write on repositories.

**GitHub**

1. Go to https://github.com/settings/tokens
2. Click "Generate new token (classic)"
3. Select scopes: `repo` (all), `workflow`
4. Generate and copy the token
5. Store it securely - you'll need it for workspace setup

**Forgejo / Gitea**

1. Go to `https://<your host>/user/settings/applications`
2. Generate a new token with scopes `write:repository` and `read:user`; add `write:user` if you will create repositories with QUE (the person starting a project needs it, people joining do not)
3. If the server requires two-factor auth, sign in on the website and enroll it first - tokens only work after that

## License

MIT License - Feel free to fork and customize for your projects!
