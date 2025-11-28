# Homelab [![CI](https://github.com/brndnblck/homelab/workflows/Validation/badge.svg)](https://github.com/brndnblck/homelab/actions) [![CoreOS](https://img.shields.io/badge/CoreOS-Latest-blue.svg)](https://getfedora.org/en/coreos/) [![Butane](https://img.shields.io/badge/Butane-Config-orange.svg)](https://coreos.github.io/butane/) [![Podman](https://img.shields.io/badge/Podman-Containers-purple.svg)](https://podman.io/) [![YAML Lint](https://img.shields.io/badge/YAML-Linted-green.svg)](https://yamllint.readthedocs.io/) [![ShellCheck](https://img.shields.io/badge/Shell-Checked-brightgreen.svg)](https://www.shellcheck.net/)

A CoreOS homelab configuration using Butane to generate Ignition files for automated server provisioning and container orchestration.

![](https://github.com/brndnblck/homelab/blob/2e5a9913ac7f3b1d400ab06de55c4b98226e84f0/.github/homelab.png)

## Features

- **Automated Provisioning**: Complete CoreOS server setup with Ignition
- **Container Services**: Media server stack (Plex, Radarr, Sonarr, etc.) 
- **Security First**: Credential templating with 1Password integration
- **CI/CD Pipeline**: Automated validation and security scanning
- **Backup System**: Scheduled backups with SystemD timers
- **Network Isolation**: Custom Podman networks with security boundaries
- **Shell Environment**: Custom ZSH profile with Starship prompt

## Getting Started

### Prerequisites

- [1Password CLI](https://developer.1password.com/docs/cli/) installed and authenticated
- [Butane](https://coreos.github.io/butane/) for config transpilation
- Make for build automation

### Setup

1. **Configure credentials**: Update `default.env` with your 1Password item references
2. **Generate configs**: Run `make generate` to process templates with your credentials
3. **Build ignition**: Run `make build` to create the CoreOS ignition file
4. **Serve locally**: Run `make serve` to host the ignition file at `http://YOUR_IP:8080/latest`

### CoreOS Installation

#### Prerequisites
Boot target server from [CoreOS Live ISO](https://getfedora.org/coreos/download/) to access `coreos-installer`.

#### Option 1: Network (Recommended)
1. **Serve ignition**: Run `make serve` on your build machine
2. **Install CoreOS**: From the Live ISO environment, run:
   ```bash
   sudo coreos-installer install /dev/sda --ignition-url http://YOUR_BUILD_MACHINE_IP:8080/latest
   ```

#### Option 2: USB Drive
1. **Copy to USB**: Copy `build/latest` (the ignition JSON file) to a USB drive
2. **Install CoreOS**: From the Live ISO environment, run:
   ```bash
   sudo coreos-installer install /dev/sda --ignition-file /path/to/usb/latest
   ```

### Development

```bash
# Run all validation checks
make lint

# Clean build artifacts
make clean
```

### Local Development

```bash
# Run all linting and validation checks
make lint

# Or run individual checks
make lint-yaml          # YAML syntax and style
make lint-shell         # Shell script analysis  
make validate-butane    # Butane config validation
make validate-systemd   # SystemD service validation
```

## Available Commands

| Command | Description |
|---------|-------------|
| `make build` | Primary build: validates and generates ignition file |
| `make generate` | Generates templates (credentials, users.yaml) using 1Password CLI |
| `make clean` | Cleanup build artifacts and temporary files |
| `make serve` | Builds and serves ignition file locally on port 8080 |
| `make lint` | Run all local linting and validation checks |
| `make lint-yaml` | Lint YAML files with yamllint |
| `make lint-shell` | Lint shell scripts with shellcheck |
| `make validate-butane` | Validate Butane configuration files |
| `make validate-systemd` | Validate SystemD service files |
| `make help` | Show available targets with descriptions |

## Project Structure

```
├── .github/workflows/    # CI/CD pipeline
├── profile/             # Shell configuration
├── scripts/             # System scripts  
├── security/            # Credential templates
├── services/            # SystemD service definitions
├── default.env          # Centralized token configuration
├── storage.yaml.tpl     # File/directory provisioning
├── systemd.yaml.tpl     # Service management
├── users.yaml.tpl       # User account template
└── Makefile            # Build automation
```

## Security

- **Centralized Credentials**: All tokens managed in `default.env` with 1Password references
- **Template Processing**: Dynamic credential injection during build
- **Automated Scanning**: Checkov security analysis in CI pipeline
- **No Secrets in Git**: Credentials resolved at build time, never committed

## Testing & Validation

The CI pipeline automatically validates:

- **YAML Linting**: Syntax and formatting validation
- **Shell Scripts**: ShellCheck analysis for POSIX compliance  
- **Butane Configs**: Ignition generation validation
- **Security Scan**: Secret detection and vulnerability analysis
- **SystemD Services**: Service file validation

## Code Style Guidelines

- **YAML files**: 2-space indentation, no tabs
- **Shell scripts**: POSIX-compliant, use `#!/bin/sh` shebang
- **File permissions**: Explicit mode settings (0755 for executables, 0644 for configs)
- **Security**: Credentials via templates, never commit secrets
- **SystemD services**: Follow naming pattern `container-{app}.service` or `task-{name}.service`
- **File paths**: Use absolute paths in configurations (`/var/services/`, `/etc/systemd/system/`)

