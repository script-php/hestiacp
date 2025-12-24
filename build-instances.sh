#!/bin/bash

# Hestia CP Multipass Build Script
# Build Hestia across multiple Ubuntu versions (focal, jammy, noble)

set -e

# Configuration
REPO_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEBS_PATH="${REPO_PATH}/hestiacp-debs"
MEMORY="4G"
DISK="15G"
CPUS="4"

# Ubuntu versions to build
declare -A UBUNTU_VERSIONS=(
	[focal]="20.04"
	[jammy]="22.04"
	[noble]="24.04"
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
	echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
	echo -e "${GREEN}✓${NC} $1"
}

log_error() {
	echo -e "${RED}✗${NC} $1"
}

log_warning() {
	echo -e "${YELLOW}⚠${NC} $1"
}

# Check if multipass is installed
check_multipass() {
	if ! command -v multipass &> /dev/null; then
		log_error "multipass is not installed. Please install it first."
		exit 1
	fi
	log_success "multipass found"
}

# Check if instance exists
instance_exists() {
	local instance_name="$1"
	multipass list | grep -q "$instance_name" && return 0 || return 1
}

# Create a new instance
create_instance() {
	local distro="$1"
	local instance_name="hestia-dev-${distro}"

	log_info "Creating instance: $instance_name"

	if instance_exists "$instance_name"; then
		log_warning "Instance $instance_name already exists"
		return 0
	fi

	multipass launch \
		--name "$instance_name" \
		--memory "$MEMORY" \
		--disk "$DISK" \
		--cpus "$CPUS" \
		"${distro}" || {
		log_error "Failed to create instance $instance_name"
		return 1
	}

	log_success "Created instance: $instance_name"

	# Mount the repository
	mount_instance "$distro"
}

# Mount repository to instance
mount_instance() {
	local distro="$1"
	local instance_name="hestia-dev-${distro}"
	local mount_path="/home/ubuntu/hestiacp"

	log_info "Mounting repository to $instance_name"

	multipass mount "${REPO_PATH}" "${instance_name}:${mount_path}" || {
		log_error "Failed to mount repository to $instance_name"
		return 1
	}

	log_success "Mounted to $instance_name"
}

# Install build dependencies
install_dependencies() {
	local distro="$1"
	local instance_name="hestia-dev-${distro}"

	log_info "Installing dependencies on $instance_name"

	multipass exec "$instance_name" -- sudo bash -c '
		apt-get update
		apt-get install -y jq libjq1
	' || {
		log_error "Failed to install dependencies on $instance_name"
		return 1
	}

	log_success "Dependencies installed on $instance_name"
}

# Build Hestia on instance
build_hestia() {
	local distro="$1"
	local instance_name="hestia-dev-${distro}"
	local mount_path="/home/ubuntu/hestiacp"

	log_info "Building Hestia on $instance_name"

	multipass exec "$instance_name" -- bash -c "
		cd ${mount_path}/src
		sudo ./hst_autocompile.sh --all --noinstall --keepbuild '~localsrc'
	" || {
		log_error "Build failed on $instance_name"
		return 1
	}

	log_success "Build completed on $instance_name"
}

# Copy debs from instance to host
copy_debs() {
	local distro="$1"
	local instance_name="hestia-dev-${distro}"
	local source="/tmp/hestiacp-src/deb"
	local dest="${DEBS_PATH}/${distro}/"

	log_info "Copying debs from $instance_name to host"

	# Create destination directory if it doesn't exist
	mkdir -p "$dest"

	# Use multipass transfer (copy files from instance recursively)
	multipass transfer -r "${instance_name}:${source}" "$dest" || {
		log_warning "No debs found to copy from $instance_name"
		return 1
	}

	log_success "Debs copied to $dest"
}

# Clean up instance
delete_instance() {
	local distro="$1"
	local instance_name="hestia-dev-${distro}"

	if ! instance_exists "$instance_name"; then
		log_warning "Instance $instance_name does not exist"
		return 0
	fi

	log_info "Deleting instance: $instance_name"

	multipass delete "$instance_name" --purge || {
		log_error "Failed to delete instance $instance_name"
		return 1
	}

	log_success "Deleted instance: $instance_name"
}

# List instances
list_instances() {
	log_info "Current instances:"
	multipass list
}

# Setup instance (create + mount + dependencies)
setup_instance() {
	local distro="$1"

	create_instance "$distro"
	install_dependencies "$distro"
}

# Full build workflow
full_build() {
	local distro="$1"

	setup_instance "$distro"
	build_hestia "$distro"
	copy_debs "$distro"
}

# Build all distros
build_all() {
	local parallel="${1:-false}"

	log_info "Starting builds for all distributions"

	if [ "$parallel" = "true" ]; then
		log_info "Building in parallel mode"
		for distro in "${!UBUNTU_VERSIONS[@]}"; do
			full_build "$distro" &
		done
		wait
		log_success "All parallel builds completed"
	else
		log_info "Building sequentially"
		for distro in "${!UBUNTU_VERSIONS[@]}"; do
			full_build "$distro"
		done
		log_success "All sequential builds completed"
	fi
}

# Create a test instance
create_test_instance() {
	local distro="${1:-focal}"
	local instance_name="hestia-test-${distro}"

	log_info "Creating test instance: $instance_name"

	if instance_exists "$instance_name"; then
		log_warning "Test instance $instance_name already exists"
		return 0
	fi

	multipass launch \
		--name "$instance_name" \
		--memory "$MEMORY" \
		--disk "$DISK" \
		--cpus "$CPUS" \
		"${distro}" || {
		log_error "Failed to create test instance $instance_name"
		return 1
	}

	log_success "Created test instance: $instance_name"
}

# Install panel on test instance
install_panel_on_test() {
	local distro="${1:-focal}"
	local instance_name="hestia-test-${distro}"
	local branch="${2:-main}"
	local hostname="${3:-test.script-php.ro}"
	local username="${4:-yoyo}"
	local email="${5:-test@script-php.ro}"
	local password="${6:-illegall}"

	if ! instance_exists "$instance_name"; then
		log_error "Test instance $instance_name does not exist. Create it first with: $0 test create $distro"
		return 1
	fi

	log_info "Installing panel on test instance $instance_name"
	log_info "  Hostname: $hostname"
	log_info "  Username: $username"
	log_info "  Email: $email"

	# Download installer on test instance
	multipass exec "$instance_name" -- bash -c "
		wget -O /tmp/hst-install-ubuntu.sh https://raw.githubusercontent.com/script-php/hestiacp/refs/heads/${branch}/install/hst-install-ubuntu.sh
	" || {
		log_error "Failed to download installer on test instance"
		return 1
	}

	# Run installer on test instance
	multipass exec "$instance_name" -- bash -c "
		sudo bash /tmp/hst-install-ubuntu.sh --hostname '${hostname}' --username '${username}' --email '${email}' --password '${password}'
	" || {
		log_error "Failed to install panel on test instance"
		return 1
	}

	log_success "Panel installed on $instance_name"
	log_info "Access the instance with: $0 test shell $distro"
}

# Access test instance shell
access_test_instance() {
	local distro="${1:-focal}"
	local instance_name="hestia-test-${distro}"

	if ! instance_exists "$instance_name"; then
		log_error "Test instance $instance_name does not exist"
		return 1
	fi

	log_info "Accessing shell on $instance_name (type 'exit' to disconnect)"
	multipass shell "$instance_name"
}

# Delete test instance
delete_test_instance() {
	local distro="${1:-focal}"
	local instance_name="hestia-test-${distro}"

	if ! instance_exists "$instance_name"; then
		log_warning "Test instance $instance_name does not exist"
		return 0
	fi

	log_info "Deleting test instance: $instance_name"

	multipass delete "$instance_name" --purge || {
		log_error "Failed to delete test instance $instance_name"
		return 1
	}

	log_success "Deleted test instance: $instance_name"
}

# Show usage
show_usage() {
	cat << EOF
${BLUE}Hestia CP Multipass Build Tool${NC}

Usage: $0 [COMMAND] [OPTIONS]

Commands:
  create <distro>           Create instance for distro (focal, jammy, noble)
  setup <distro>            Create + mount + install dependencies
  build <distro>            Build Hestia on instance
  copy-debs <distro>        Copy debs from instance to host
  full <distro>             Setup + build + copy debs
  build-all [parallel]      Build all distros (optional: 'parallel')
  delete <distro>           Delete instance
  delete-all                Delete all instances
  list                      List all instances

  test create <distro>      Create test instance (focal, jammy, noble)
  test install <distro>     Install panel on test instance
  test shell <distro>       Access test instance shell
  test delete <distro>      Delete test instance

  help                      Show this help message

Options:
  --memory SIZE             Memory for instances (default: 4G)
  --disk SIZE               Disk size for instances (default: 15G)
  --cpus COUNT              CPU count for instances (default: 4)

Examples:
  $0 setup focal
  $0 full jammy
  $0 build-all
  $0 build-all parallel
  
  # Testing workflow:
  $0 test create focal
  $0 test install focal
  $0 test shell focal
  $0 test delete focal

EOF
}

# Main script
main() {
	check_multipass

	# Parse options
	while [[ $# -gt 0 ]]; do
		case $1 in
			--memory)
				MEMORY="$2"
				shift 2
				;;
			--disk)
				DISK="$2"
				shift 2
				;;
			--cpus)
				CPUS="$2"
				shift 2
				;;
			create)
				create_instance "$2"
				exit 0
				;;
			setup)
				setup_instance "$2"
				exit 0
				;;
			build)
				build_hestia "$2"
				exit 0
				;;
			copy-debs)
				copy_debs "$2"
				exit 0
				;;
			full)
				full_build "$2"
				exit 0
				;;
			build-all)
				build_all "${2:-false}"
				exit 0
				;;
			delete)
				delete_instance "$2"
				exit 0
				;;
			delete-all)
				for distro in "${!UBUNTU_VERSIONS[@]}"; do
					delete_instance "$distro"
				done
				exit 0
				;;
			test)
				case "$2" in
					create)
						create_test_instance "${3:-focal}"
						exit 0
						;;
					install)
						install_panel_on_test "${3:-focal}"
						exit 0
						;;
					shell)
						access_test_instance "${3:-focal}"
						exit 0
						;;
					delete)
						delete_test_instance "${3:-focal}"
						exit 0
						;;
					*)
						log_error "Unknown test command: $2"
						show_usage
						exit 1
						;;
				esac
				;;
			list)
				list_instances
				exit 0
				;;
			help|--help|-h)
				show_usage
				exit 0
				;;
			*)
				log_error "Unknown command: $1"
				show_usage
				exit 1
				;;
		esac
	done

	show_usage
}

main "$@"
