# Hestia CP Multipass Build Tool

Automate building Hestia packages across multiple Ubuntu versions (Focal, Jammy, Noble) using Multipass.

## Prerequisites

- [Multipass](https://multipass.run/) installed
- At least 12GB RAM and 45GB disk space (for all 3 instances simultaneously)
- Repository cloned to `~/projects/hestiacp`
- `hestiacp-debs` folder in the repository root

## Quick Start

### Build a single distribution
```bash
./build-instances.sh full focal      # Setup + build + copy debs for Ubuntu 20.04
./build-instances.sh full jammy      # Setup + build + copy debs for Ubuntu 22.04
./build-instances.sh full noble      # Setup + build + copy debs for Ubuntu 24.04
```

### Build all distributions at once
```bash
# Sequential (one after another)
./build-instances.sh build-all

# Parallel (all at the same time)
./build-instances.sh build-all parallel
```

### Custom resource allocation
```bash
./build-instances.sh --memory 8G --disk 20G --cpus 6 full jammy
```

## Commands

| Command | Description |
|---------|-------------|
| `create <distro>` | Create a Multipass instance for the specified distro |
| `setup <distro>` | Create instance + mount repository + install dependencies |
| `build <distro>` | Execute the Hestia build on an instance |
| `copy-debs <distro>` | Copy built .deb files from instance to host |
| `full <distro>` | Complete workflow: setup + build + copy debs |
| `build-all [parallel]` | Build all distros sequentially or in parallel |
| `delete <distro>` | Delete an instance |
| `delete-all` | Delete all instances |
| `list` | List all created instances |
| `help` | Show help message |

## How It Works

### 1. Instance Creation
Creates a Multipass instance with:
- 4GB RAM (configurable)
- 15GB disk space (configurable)
- 4 CPUs (configurable)

### 2. Repository Mounting
Mounts your local repository to `/home/ubuntu/hestiacp` in the instance so changes are reflected in real-time.

### 3. Dependency Installation
Installs required build tools:
- `jq` - JSON query tool
- `libjq1` - JSON C library

### 4. Building
Executes the build process:
```bash
cd /home/ubuntu/hestiacp/src
sudo ./hst_autocompile.sh --all --noinstall --keepbuild '~localsrc'
```

### 5. DEB Collection
Copies built `.deb` files from `/tmp/hestiacp-src/deb/` in the instance to:
- `hestiacp-debs/focal/` (Ubuntu 20.04)
- `hestiacp-debs/jammy/` (Ubuntu 22.04)
- `hestiacp-debs/noble/` (Ubuntu 24.04)

## Usage Examples

### Single build workflow
```bash
# Setup focal instance
./build-instances.sh setup focal

# Build on focal
./build-instances.sh build focal

# Copy debs from focal
./build-instances.sh copy-debs focal

# When done, delete the instance
./build-instances.sh delete focal
```

### Complete parallel build
```bash
# Build all three versions in parallel
./build-instances.sh build-all parallel

# Check the results
ls -la hestiacp-debs/*/
```

### With custom resources for ARM Macs
```bash
./build-instances.sh --memory 12G --disk 20G --cpus 6 build-all parallel
```

## Output Structure

After building, your `hestiacp-debs` folder will have:

```
hestiacp-debs/
├── focal/
│   ├── hestia_*.deb
│   ├── hestia-nginx_*.deb
│   ├── hestia-php_*.deb
│   └── ...
├── jammy/
│   ├── hestia_*.deb
│   └── ...
└── noble/
    ├── hestia_*.deb
    └── ...
```

## Troubleshooting

### Instance already exists
If you get a warning about an existing instance, you can:
- Delete it: `./build-instances.sh delete focal`
- Delete all: `./build-instances.sh delete-all`
- Or just reuse it

### Build fails
Check the build logs by SSHing into the instance:
```bash
multipass shell hestia-dev-focal
cd /home/ubuntu/hestiacp/src
sudo ./hst_autocompile.sh --all --noinstall --keepbuild '~localsrc'
```

### Disk space issues
Increase disk allocation:
```bash
./build-instances.sh --disk 25G full jammy
```

### Slow performance
- Increase memory: `--memory 8G`
- Reduce parallel builds (run sequentially instead)

## Resource Requirements

| Scenario | RAM | Disk |
|----------|-----|------|
| Single build | 4GB | 15GB |
| 2 parallel builds | 8GB | 30GB |
| 3 parallel builds | 12GB | 45GB |

## Clean Up

To free up resources:

```bash
# Delete single instance
./build-instances.sh delete focal

# Delete all instances
./build-instances.sh delete-all

# Verify they're gone
./build-instances.sh list
```

## Advanced: Manual Control

If you need more control, you can interact with instances directly:

```bash
# SSH into an instance
multipass shell hestia-dev-focal

# Run custom commands
multipass exec hestia-dev-focal -- sudo apt-get update

# Copy files manually
multipass transfer /local/file hestia-dev-focal:/remote/path
multipass transfer hestia-dev-focal:/remote/file /local/path
```

## Notes

- The script uses the repository path as the base for mount points
- All outputs are color-coded for easy reading
- Failed commands exit with error code 1
- The script is idempotent - you can run it multiple times safely
