# CLIProxyAPI Update Script

A Python script that automatically downloads and updates the latest version of [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI) on Windows.

## Features

- **Version Check**: Detects currently installed version
- **Auto Update**: Downloads the latest release from GitHub
- **Config Management**: Automatically renames and backs up configuration files
- **Version Verification**: Confirms successful installation

## Usage

```bash
python update_cli_proxy.py
```

## How It Works

1. Checks current installed version via `cli-proxy-api.exe --help`
2. Fetches latest release version from GitHub API
3. Downloads and extracts the Windows ZIP package
4. Renames `config.example.yaml` to `config.yaml` (backs up old config)
5. Verifies installation by running `--help`

## Files

- `update_cli_proxy.py` - Main update script
- `CLIProxyAPI/` - Downloaded binary directory (gitignored)

## Requirements

- Python 3.x
- Windows OS
- Internet connection (for GitHub API and downloads)
