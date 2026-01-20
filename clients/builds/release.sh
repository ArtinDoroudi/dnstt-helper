#!/bin/bash

# DNSTT Helper - Release Script
# Prepares and creates GitHub releases

set -e

# ============================================================================
# CONFIGURATION
# ============================================================================

BUILD_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$BUILD_DIR")")"
DIST_DIR="${PROJECT_ROOT}/dist"

GITHUB_REPO="ArtinDoroudi/dnstt-helper"

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
# VERSION MANAGEMENT
# ============================================================================

get_current_version() {
    if [ -f "${PROJECT_ROOT}/VERSION" ]; then
        cat "${PROJECT_ROOT}/VERSION"
    else
        echo "1.0.0"
    fi
}

set_version() {
    local version="$1"
    echo "$version" > "${PROJECT_ROOT}/VERSION"
    log_info "Version set to: $version"
}

bump_version() {
    local current_version
    current_version=$(get_current_version)
    
    local major minor patch
    IFS='.' read -r major minor patch <<< "$current_version"

    case "$1" in
        major)
            ((major++))
            minor=0
            patch=0
            ;;
        minor)
            ((minor++))
            patch=0
            ;;
        patch|*)
            ((patch++))
            ;;
    esac

    local new_version="${major}.${minor}.${patch}"
    set_version "$new_version"
    echo "$new_version"
}

# ============================================================================
# RELEASE NOTES
# ============================================================================

generate_release_notes() {
    local version="$1"
    local notes_file="${DIST_DIR}/RELEASE_NOTES.md"

    log_step "Generating release notes..."

    cat > "$notes_file" << EOF
# dnstt-helper v${version}

## Downloads

### Client Binaries

| Platform | Architecture | Download |
|----------|--------------|----------|
| Windows | x64 | \`dnstt-client-windows-amd64.exe\` |
| Windows | x86 | \`dnstt-client-windows-386.exe\` |
| macOS | Intel | \`dnstt-client-darwin-amd64\` |
| macOS | Apple Silicon | \`dnstt-client-darwin-arm64\` |
| Linux | x64 | \`dnstt-client-linux-amd64\` |
| Linux | ARM64 | \`dnstt-client-linux-arm64\` |
| Linux | ARM | \`dnstt-client-linux-arm\` |
| Linux | x86 | \`dnstt-client-linux-386\` |

### Server Installation

\`\`\`bash
bash <(curl -Ls https://raw.githubusercontent.com/${GITHUB_REPO}/main/server/dnstt-helper.sh)
\`\`\`

## Verification

Verify your download using the checksum files:

\`\`\`bash
# Linux/macOS
sha256sum -c SHA256SUMS

# Windows (PowerShell)
Get-FileHash <filename> -Algorithm SHA256
\`\`\`

## Quick Start

1. Download the client for your platform
2. Get your server's public key
3. Run:
   \`\`\`bash
   ./dnstt-client -udp DNS_SERVER:53 -pubkey-file server.pub t.example.com 127.0.0.1:7000
   \`\`\`

## Documentation

- [Server Setup Guide](https://github.com/${GITHUB_REPO}/blob/main/docs/server-setup.md)
- [Client Usage Guide](https://github.com/${GITHUB_REPO}/blob/main/docs/client-usage.md)
- [Android Guides](https://github.com/${GITHUB_REPO}/tree/main/android)
- [Troubleshooting](https://github.com/${GITHUB_REPO}/blob/main/docs/troubleshooting.md)

## Changes

<!-- Add release changes here -->
- Initial release

## Checksums

See \`SHA256SUMS\`, \`SHA1SUMS\`, and \`MD5SUMS\` files for verification.
EOF

    log_info "Release notes generated: $notes_file"
}

# ============================================================================
# GITHUB RELEASE
# ============================================================================

check_gh_cli() {
    if ! command -v gh &> /dev/null; then
        log_error "GitHub CLI (gh) is not installed."
        log_info "Install from: https://cli.github.com/"
        exit 1
    fi

    if ! gh auth status &> /dev/null; then
        log_error "GitHub CLI is not authenticated."
        log_info "Run: gh auth login"
        exit 1
    fi
}

create_github_release() {
    local version="$1"
    local tag="v${version}"

    log_step "Creating GitHub release..."

    check_gh_cli

    # Check if tag exists
    if git rev-parse "$tag" &> /dev/null; then
        log_warn "Tag $tag already exists"
        read -p "Delete and recreate? (y/N): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            git tag -d "$tag" 2>/dev/null || true
            git push origin ":refs/tags/$tag" 2>/dev/null || true
        else
            log_info "Aborting release"
            return 1
        fi
    fi

    # Create tag
    cd "$PROJECT_ROOT"
    git tag -a "$tag" -m "Release $tag"
    git push origin "$tag"

    # Create release
    local release_files=()
    for file in "${DIST_DIR}"/dnstt-client-*; do
        if [ -f "$file" ]; then
            release_files+=("$file")
        fi
    done

    # Add checksum files
    for file in "${DIST_DIR}"/*SUMS; do
        if [ -f "$file" ]; then
            release_files+=("$file")
        fi
    done

    gh release create "$tag" \
        --title "dnstt-helper $tag" \
        --notes-file "${DIST_DIR}/RELEASE_NOTES.md" \
        "${release_files[@]}"

    log_info "Release created: https://github.com/${GITHUB_REPO}/releases/tag/$tag"
}

# ============================================================================
# DRAFT RELEASE
# ============================================================================

create_draft_release() {
    local version="$1"
    local tag="v${version}"

    log_step "Creating draft release..."

    check_gh_cli

    local release_files=()
    for file in "${DIST_DIR}"/dnstt-client-*; do
        if [ -f "$file" ]; then
            release_files+=("$file")
        fi
    done

    for file in "${DIST_DIR}"/*SUMS; do
        if [ -f "$file" ]; then
            release_files+=("$file")
        fi
    done

    gh release create "$tag" \
        --title "dnstt-helper $tag" \
        --notes-file "${DIST_DIR}/RELEASE_NOTES.md" \
        --draft \
        "${release_files[@]}"

    log_info "Draft release created"
    log_info "Review and publish at: https://github.com/${GITHUB_REPO}/releases"
}

# ============================================================================
# FULL RELEASE WORKFLOW
# ============================================================================

full_release() {
    local bump_type="${1:-patch}"
    
    log_step "Starting full release workflow..."

    # Bump version
    local version
    version=$(bump_version "$bump_type")
    log_info "New version: $version"

    # Build
    log_step "Building clients..."
    VERSION="$version" "${BUILD_DIR}/build.sh" all

    # Generate release notes
    generate_release_notes "$version"

    # Show summary
    echo ""
    log_info "Release prepared for v${version}"
    log_info "Built files:"
    ls -la "${DIST_DIR}"/dnstt-client-* 2>/dev/null || true
    echo ""

    read -p "Create GitHub release? (y/N): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        create_github_release "$version"
    else
        log_info "Skipping GitHub release. Run '$0 publish $version' when ready."
    fi
}

# ============================================================================
# HELP
# ============================================================================

show_help() {
    echo "DNSTT Helper - Release Script"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  version               Show current version"
    echo "  bump [type]           Bump version (major|minor|patch)"
    echo "  notes <version>       Generate release notes"
    echo "  publish <version>     Create GitHub release"
    echo "  draft <version>       Create draft GitHub release"
    echo "  full [type]           Full release workflow (build + release)"
    echo "  help                  Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 version            # Show current version"
    echo "  $0 bump patch         # Bump patch version (1.0.0 -> 1.0.1)"
    echo "  $0 bump minor         # Bump minor version (1.0.0 -> 1.1.0)"
    echo "  $0 full patch         # Full release with patch bump"
    echo "  $0 publish 1.0.0      # Create release for v1.0.0"
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    local command="${1:-help}"

    case "$command" in
        version)
            get_current_version
            ;;
        bump)
            bump_version "${2:-patch}"
            ;;
        notes)
            if [ -z "$2" ]; then
                log_error "Please specify a version"
                exit 1
            fi
            mkdir -p "$DIST_DIR"
            generate_release_notes "$2"
            ;;
        publish)
            if [ -z "$2" ]; then
                log_error "Please specify a version"
                exit 1
            fi
            generate_release_notes "$2"
            create_github_release "$2"
            ;;
        draft)
            if [ -z "$2" ]; then
                log_error "Please specify a version"
                exit 1
            fi
            generate_release_notes "$2"
            create_draft_release "$2"
            ;;
        full)
            full_release "${2:-patch}"
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

