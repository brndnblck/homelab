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

### Creating New Resources

#### Quick Examples

```bash
# Generate container services
make new service NAME=jellyfin IMAGE=jellyfin/jellyfin:latest PORTS=8096:8096

# Generate scheduled tasks  
make new timer NAME=backup DESCRIPTION="Daily backup" SCHEDULE="*-*-* 02:00:00"

# Generate oneshot system tasks
make new task NAME=deps SCRIPT=init-deps.sh REMAIN_ACTIVE=yes

# Interactive mode (prompts for all values)
make new service  # or timer, task
```

#### Complete Workflow

1. **Generate the service**:
   ```bash
   make new service NAME=jellyfin IMAGE=jellyfin/jellyfin:latest PORTS=8096:8096
   ```

2. **Review the generated template**:
   ```bash
   cat services/container-jellyfin.service.template
   ```

3. **Enable the service** by adding to `systemd.yaml.template`:
   ```yaml
   # Add this section to systemd.yaml.template
   - name: container-jellyfin.service
     enabled: true    # Auto-start on boot
   ```

4. **Build and test**:
   ```bash
   make generate  # Process templates with credentials
   make build     # Create ignition file and validate
   make serve     # Serve for deployment at http://YOUR_IP:8080/latest
   ```

#### Service Types

- **`service`**: Container applications (web apps, media servers, databases)
- **`timer`**: Scheduled tasks with SystemD timer syntax
- **`task`**: One-time setup scripts (dependencies, initialization)

#### Common Patterns

```bash
# Media server with external access
make new service NAME=plex IMAGE=plexinc/pms-docker PORTS=32400:32400

# Internal service (no external ports)  
make new service NAME=radarr IMAGE=linuxserver/radarr

# Daily backup task
make new timer NAME=backup SCHEDULE="*-*-* 04:00:00"

# System initialization task
make new task NAME=setup-storage SCRIPT=init-storage.sh REMAIN_ACTIVE=yes
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
| `make new [service,timer,task]` | Generate new resource templates |
| `make lint` | Run all local linting and validation checks |
| `make lint-yaml` | Lint YAML files with yamllint |
| `make lint-shell` | Lint shell scripts with shellcheck |
| `make validate-butane` | Validate Butane configuration files |
| `make validate-systemd` | Validate SystemD service files |
| `make validate-templates` | Validate that referenced services have template files |
| `make help` | Show available targets with descriptions |

## Project Structure

```
├── .github/workflows/    # CI/CD pipeline
├── profile/             # Shell configuration
├── scripts/             # System scripts  
├── security/            # Credential templates
├── services/            # SystemD service definitions
├── templates/           # Resource generation templates
├── default.env          # Centralized token configuration
├── storage.yaml.template     # File/directory provisioning
├── systemd.yaml.template     # Service management
├── users.yaml.template       # User account template
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

## Troubleshooting

### Common Issues

**Generated service won't start after deployment:**
```bash
# Check if service is enabled in systemd.yaml.template
grep "container-myapp.service" systemd.yaml.template

# If missing, add it:
- name: container-myapp.service
  enabled: true
```

**Build fails with "template not found":**
```bash
# Ensure the template exists
ls services/container-myapp.service.template

# Regenerate if needed
make new service NAME=myapp IMAGE=nginx
```

**Port conflicts or networking issues:**
```bash
# Check for port conflicts in other services
grep "8080:8080" services/*.template

# Verify network configuration
grep "network" services/container-*.template
```

**1Password authentication errors:**
```bash
# Verify 1Password CLI is authenticated
op account list

# Test credential access
op read "op://Private/PLEX_CLAIM/credential"

# Check default.env format
grep "^[A-Z]" default.env
```

**Template validation errors:**
```bash
# Run individual validation steps
make lint-yaml
make validate-butane
make validate-systemd
make validate-templates  # Check for missing service templates

# Check specific service syntax
systemd-analyze verify services/container-app.service.template
```

**Missing template files:**
```bash
# If build fails with missing template references:
make validate-templates  # Shows which templates are missing and how to create them
```



## Code Style Guidelines

- **YAML files**: 2-space indentation, no tabs
- **Shell scripts**: POSIX-compliant, use `#!/bin/sh` shebang
- **File permissions**: Explicit mode settings (0755 for executables, 0644 for configs)
- **Security**: Credentials via templates, never commit secrets
- **Template tokens**: Use `{{TOKEN_NAME}}` format for all placeholders
- **SystemD services**: Follow naming pattern `container-{app}.service` or `task-{name}.service`
- **File paths**: Use absolute paths in configurations (`/var/services/`, `/etc/systemd/system/`)

