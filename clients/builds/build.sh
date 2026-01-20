#!/bin/bash

# DNSTT Helper - Client Build Script
# Cross-compiles dnstt-client for multiple platforms

set -e

# ============================================================================
# CONFIGURATION
# ============================================================================

VERSION="${VERSION:-1.0.0}"
BUILD_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$BUILD_DIR")")"
DIST_DIR="${PROJECT_ROOT}/dist"
CLI_DIR="${BUILD_DIR}/../cli"

# DNSTT source repository
DNSTT_REPO="https://www.bamsoftware.com/git/dnstt.git"
DNSTT_BRANCH="master"
DNSTT_SRC_DIR="/tmp/dnstt-src"

# Build mode: "standard" (official dnstt) or "wrapper" (enhanced wrapper)
BUILD_MODE="${BUILD_MODE:-standard}"

# Build targets: OS/ARCH combinations
TARGETS=(
    "linux/amd64"
    "linux/arm64"
    "linux/arm"
    "linux/386"
    "darwin/amd64"
    "darwin/arm64"
    "windows/amd64"
    "windows/386"
)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# ============================================================================
# PREREQUISITE CHECK
# ============================================================================

check_prerequisites() {
    log_step "Checking prerequisites..."

    # Check for Go
    if ! command -v go &> /dev/null; then
        log_error "Go is not installed. Please install Go 1.21 or later."
        log_info "Visit: https://go.dev/doc/install"
        exit 1
    fi

    local go_version
    go_version=$(go version | awk '{print $3}' | sed 's/go//')
    log_info "Found Go version: $go_version"

    # Check for Git
    if ! command -v git &> /dev/null; then
        log_error "Git is not installed. Please install Git."
        exit 1
    fi

    log_info "Prerequisites satisfied"
}

# ============================================================================
# SOURCE MANAGEMENT
# ============================================================================

fetch_dnstt_source() {
    log_step "Fetching DNSTT source code..."

    if [ -d "$DNSTT_SRC_DIR" ]; then
        log_info "Updating existing source..."
        cd "$DNSTT_SRC_DIR"
        git fetch origin
        git checkout "$DNSTT_BRANCH"
        git pull origin "$DNSTT_BRANCH"
    else
        log_info "Cloning DNSTT repository..."
        git clone --branch "$DNSTT_BRANCH" "$DNSTT_REPO" "$DNSTT_SRC_DIR"
    fi

    log_info "Source code ready at: $DNSTT_SRC_DIR"
}

# ============================================================================
# BUILD FUNCTIONS
# ============================================================================

build_target() {
    local os="$1"
    local arch="$2"
    local output_name="dnstt-client-${os}-${arch}"
    
    if [ "$os" = "windows" ]; then
        output_name="${output_name}.exe"
    fi

    local output_path="${DIST_DIR}/${output_name}"

    log_info "Building for ${os}/${arch}..."

    # Set environment for cross-compilation
    export GOOS="$os"
    export GOARCH="$arch"
    export CGO_ENABLED=0

    # Build based on mode
    if [ "$BUILD_MODE" = "wrapper" ]; then
        # Build enhanced wrapper client
        cd "$CLI_DIR"
        go mod download 2>/dev/null || true
        go build -ldflags="-s -w -X main.version=${VERSION}" \
            -trimpath \
            -o "$output_path" \
            .
    else
        # Build standard dnstt-client
        cd "${DNSTT_SRC_DIR}/dnstt-client"
        go build -ldflags="-s -w -X main.version=${VERSION}" \
            -trimpath \
            -o "$output_path" \
            .
    fi

    if [ -f "$output_path" ]; then
        local size
        size=$(du -h "$output_path" | cut -f1)
        log_info "  Built: $output_name ($size)"
    else
        log_error "  Failed to build: $output_name"
        return 1
    fi
}

build_wrapper_target() {
    local os="$1"
    local arch="$2"
    local output_name="dnstt-helper-client-${os}-${arch}"
    
    if [ "$os" = "windows" ]; then
        output_name="${output_name}.exe"
    fi

    local output_path="${DIST_DIR}/${output_name}"

    log_info "Building wrapper for ${os}/${arch}..."

    export GOOS="$os"
    export GOARCH="$arch"
    export CGO_ENABLED=0

    cd "$CLI_DIR"
    go mod download 2>/dev/null || true
    go build -ldflags="-s -w -X main.version=${VERSION}" \
        -trimpath \
        -o "$output_path" \
        .

    if [ -f "$output_path" ]; then
        local size
        size=$(du -h "$output_path" | cut -f1)
        log_info "  Built: $output_name ($size)"
    else
        log_error "  Failed to build: $output_name"
        return 1
    fi
}

build_all() {
    log_step "Building clients for all targets..."

    # Create dist directory
    mkdir -p "$DIST_DIR"

    # Clean old builds
    rm -f "${DIST_DIR}"/dnstt-client-*
    rm -f "${DIST_DIR}"/dnstt-helper-client-*

    local success=0
    local failed=0

    for target in "${TARGETS[@]}"; do
        local os="${target%/*}"
        local arch="${target#*/}"

        if build_target "$os" "$arch"; then
            ((success++))
        else
            ((failed++))
        fi
    done

    echo ""
    log_info "Build complete: $success succeeded, $failed failed"
    
    if [ "$failed" -gt 0 ]; then
        return 1
    fi
}

build_wrappers() {
    log_step "Building wrapper clients for all targets..."

    mkdir -p "$DIST_DIR"

    local success=0
    local failed=0

    for target in "${TARGETS[@]}"; do
        local os="${target%/*}"
        local arch="${target#*/}"

        if build_wrapper_target "$os" "$arch"; then
            ((success++))
        else
            ((failed++))
        fi
    done

    echo ""
    log_info "Wrapper build complete: $success succeeded, $failed failed"
}

build_single() {
    local target="$1"
    local os="${target%/*}"
    local arch="${target#*/}"

    log_step "Building single target: ${os}/${arch}"

    mkdir -p "$DIST_DIR"
    build_target "$os" "$arch"
}

# ============================================================================
# CHECKSUM GENERATION
# ============================================================================

generate_checksums() {
    log_step "Generating checksums..."

    cd "$DIST_DIR"

    # MD5
    if command -v md5sum &> /dev/null; then
        md5sum dnstt-client-* > MD5SUMS 2>/dev/null || true
        log_info "Generated MD5SUMS"
    fi

    # SHA1
    if command -v sha1sum &> /dev/null; then
        sha1sum dnstt-client-* > SHA1SUMS 2>/dev/null || true
        log_info "Generated SHA1SUMS"
    fi

    # SHA256
    if command -v sha256sum &> /dev/null; then
        sha256sum dnstt-client-* > SHA256SUMS 2>/dev/null || true
        log_info "Generated SHA256SUMS"
    fi
}

# ============================================================================
# PACKAGING
# ============================================================================

package_release() {
    log_step "Packaging release..."

    local release_dir="${DIST_DIR}/release-v${VERSION}"
    mkdir -p "$release_dir"

    # Copy binaries
    cp "${DIST_DIR}"/dnstt-client-* "$release_dir/" 2>/dev/null || true
    cp "${DIST_DIR}"/*SUMS "$release_dir/" 2>/dev/null || true

    # Create release archive
    cd "$DIST_DIR"
    tar -czf "dnstt-helper-clients-v${VERSION}.tar.gz" -C "$release_dir" .

    log_info "Release package created: dnstt-helper-clients-v${VERSION}.tar.gz"

    # List contents
    echo ""
    log_info "Release contents:"
    ls -la "$release_dir"
}

# ============================================================================
# CLEANUP
# ============================================================================

clean() {
    log_step "Cleaning build artifacts..."

    rm -rf "$DIST_DIR"
    rm -rf "$DNSTT_SRC_DIR"

    log_info "Cleanup complete"
}

clean_dist() {
    log_step "Cleaning distribution directory..."

    rm -rf "$DIST_DIR"

    log_info "Distribution directory cleaned"
}

# ============================================================================
# LIST FUNCTIONS
# ============================================================================

list_targets() {
    echo "Available build targets:"
    echo ""
    for target in "${TARGETS[@]}"; do
        echo "  $target"
    done
    echo ""
    echo "Usage: $0 build <target>"
    echo "Example: $0 build linux/amd64"
}

list_builds() {
    if [ ! -d "$DIST_DIR" ]; then
        log_warn "No builds found. Run '$0 all' to build."
        return 1
    fi

    echo "Built binaries:"
    echo ""
    ls -la "$DIST_DIR"/dnstt-client-* 2>/dev/null || log_warn "No binaries found"
}

# ============================================================================
# HELP
# ============================================================================

show_help() {
    echo "DNSTT Helper - Client Build Script"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  all             Build standard clients for all platforms"
    echo "  wrappers        Build enhanced wrapper clients for all platforms"
    echo "  both            Build both standard and wrapper clients"
    echo "  build <target>  Build for specific target (e.g., linux/amd64)"
    echo "  checksums       Generate checksum files"
    echo "  package         Package release with checksums"
    echo "  list            List available targets"
    echo "  builds          List built binaries"
    echo "  clean           Clean all build artifacts"
    echo "  clean-dist      Clean distribution directory only"
    echo "  help            Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  VERSION         Set build version (default: 1.0.0)"
    echo "  BUILD_MODE      'standard' or 'wrapper' (default: standard)"
    echo ""
    echo "Examples:"
    echo "  $0 all                    # Build all platforms (standard)"
    echo "  $0 wrappers               # Build wrapper clients"
    echo "  $0 both                   # Build both standard and wrapper"
    echo "  $0 build linux/amd64      # Build Linux x64 only"
    echo "  VERSION=2.0.0 $0 all      # Build with custom version"
    echo "  $0 package                # Create release package"
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    local command="${1:-help}"

    case "$command" in
        all)
            check_prerequisites
            fetch_dnstt_source
            build_all
            generate_checksums
            ;;
        wrappers)
            check_prerequisites
            build_wrappers
            generate_checksums
            ;;
        both)
            check_prerequisites
            fetch_dnstt_source
            build_all
            build_wrappers
            generate_checksums
            ;;
        build)
            if [ -z "$2" ]; then
                log_error "Please specify a target. Use '$0 list' to see available targets."
                exit 1
            fi
            check_prerequisites
            fetch_dnstt_source
            build_single "$2"
            ;;
        checksums)
            generate_checksums
            ;;
        package)
            generate_checksums
            package_release
            ;;
        list)
            list_targets
            ;;
        builds)
            list_builds
            ;;
        clean)
            clean
            ;;
        clean-dist)
            clean_dist
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Unknown command: $command"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

main "$@"

