# ghsync

A shell script to keep all your GitHub repositories synced locally.

## Features

- Clones any GitHub repos missing from `~/Projects`
- Pulls latest changes for existing repos
- Automatically stashes and restores local changes during pull
- Warns about local folders without git or without a remote origin
- Colored output for easy scanning

## Requirements

- [GitHub CLI](https://cli.github.com/) (`gh`) installed and authenticated
- Git

## Usage

```bash
./sync.sh
```

## Configuration

Copy `.env.template` to `.env` and customize as needed:

```bash
cp .env.template .env
```

| Variable              | Default          | Description                             |
| --------------------- | ---------------- | --------------------------------------- |
| `PROJECTS_DIR`        | `$HOME/Projects` | Directory where repositories are stored |
| `REPO_LIMIT`          | `200`            | Maximum number of repositories to fetch |
| `CHECK_LOCAL_FOLDERS` | `true`           | Check for folders without git/origin    |

## What it does

1. Fetches your GitHub repository list via `gh repo list`
2. For each repo:
   - If missing locally: clones it to `~/Projects/<repo-name>`
   - If exists: stashes local changes, pulls, then restores stash
3. Scans `~/Projects` for folders that:
   - Have no git initialized
   - Have no remote origin configured

Folders with non-GitHub remotes (GitLab, Bitbucket, etc.) are not flagged.
