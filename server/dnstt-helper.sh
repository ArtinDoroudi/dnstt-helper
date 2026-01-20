#!/bin/bash

# dnstt-helper Server Setup Script
# Enhanced DNSTT server deployment with advanced features
# Supports Fedora, Rocky, CentOS, Debian, Ubuntu

set -e

# ============================================================================
# GLOBAL VARIABLES
# ============================================================================

# Version
VERSION="1.0.0"

# URLs
DNSTT_BASE_URL="https://dnstt.network"
SCRIPT_URL="https://raw.githubusercontent.com/ArtinDoroudi/dnstt-helper/main/server/dnstt-helper.sh"
GITHUB_RELEASES="https://github.com/ArtinDoroudi/dnstt-helper/releases"

# Directories
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/dnstt"
SYSTEMD_DIR="/etc/systemd/system"
PROFILES_DIR="${CONFIG_DIR}/profiles"
BACKUP_DIR="${CONFIG_DIR}/backups"

# Files
CONFIG_FILE="${CONFIG_DIR}/dnstt-server.conf"
SCRIPT_INSTALL_PATH="/usr/local/bin/dnstt-helper"

# Defaults
DNSTT_PORT="5300"
DNSTT_USER="dnstt"
DEFAULT_MTU="1232"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# Global state
UPDATE_AVAILABLE=false
CURRENT_PROFILE=""

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_question() {
    echo -ne "${BLUE}[?]${NC} $1"
}

print_header() {
    echo -e "\n${CYAN}${BOLD}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}  $1${NC}"
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════════════${NC}\n"
}

print_section() {
    echo -e "\n${MAGENTA}${BOLD}─── $1 ───${NC}\n"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root"
        exit 1
    fi
}

# ============================================================================
# OS AND ARCHITECTURE DETECTION
# ============================================================================

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        OS_ID=$ID
        OS_VERSION=$VERSION_ID
    else
        print_error "Cannot detect OS"
        exit 1
    fi

    # Determine package manager
    if command -v dnf &> /dev/null; then
        PKG_MANAGER="dnf"
    elif command -v yum &> /dev/null; then
        PKG_MANAGER="yum"
    elif command -v apt &> /dev/null; then
        PKG_MANAGER="apt"
    else
        print_error "Unsupported package manager"
        exit 1
    fi

    print_status "Detected OS: $OS ($OS_ID $OS_VERSION)"
    print_status "Package manager: $PKG_MANAGER"
}

detect_arch() {
    local arch
    arch=$(uname -m)
    case $arch in
        x86_64)
            ARCH="amd64"
            ;;
        aarch64|arm64)
            ARCH="arm64"
            ;;
        armv7l|armv6l)
            ARCH="arm"
            ;;
        i386|i686)
            ARCH="386"
            ;;
        *)
            print_error "Unsupported architecture: $arch"
            exit 1
            ;;
    esac
    print_status "Detected architecture: $ARCH"
}

# ============================================================================
# DEPENDENCY MANAGEMENT
# ============================================================================

install_dependencies() {
    local packages=("$@")
    print_status "Installing dependencies: ${packages[*]}"

    case $PKG_MANAGER in
        dnf|yum)
            $PKG_MANAGER install -y "${packages[@]}"
            ;;
        apt)
            apt update
            apt install -y "${packages[@]}"
            ;;
    esac
}

check_required_tools() {
    print_status "Checking required tools..."

    local required_tools=("curl" "jq")
    local missing_tools=()

    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done

    # Check for iptables
    if ! command -v "iptables" &> /dev/null; then
        case $PKG_MANAGER in
            dnf|yum)
                missing_tools+=("iptables" "iptables-services")
                ;;
            apt)
                missing_tools+=("iptables" "iptables-persistent")
                ;;
        esac
    fi

    # Check for qrencode (optional but recommended)
    if ! command -v "qrencode" &> /dev/null; then
        missing_tools+=("qrencode")
    fi

    if [ ${#missing_tools[@]} -gt 0 ]; then
        print_status "Installing missing tools: ${missing_tools[*]}"
        install_dependencies "${missing_tools[@]}"
    else
        print_status "All required tools are available"
    fi
}

# ============================================================================
# CONFIGURATION MANAGEMENT
# ============================================================================

init_config_dirs() {
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$PROFILES_DIR"
    mkdir -p "$BACKUP_DIR"
    
    if id "$DNSTT_USER" &>/dev/null; then
        chown -R "$DNSTT_USER":"$DNSTT_USER" "$CONFIG_DIR"
    fi
    chmod 750 "$CONFIG_DIR"
}

load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        print_status "Loading existing configuration..."
        # shellcheck source=/dev/null
        . "$CONFIG_FILE"
        return 0
    fi
    return 1
}

save_config() {
    print_status "Saving configuration..."

    cat > "$CONFIG_FILE" << EOF
# dnstt-helper Server Configuration
# Generated on $(date)
# Version: $VERSION

# Server Settings
NS_SUBDOMAIN="$NS_SUBDOMAIN"
MTU_VALUE="$MTU_VALUE"
TUNNEL_MODE="$TUNNEL_MODE"
DNSTT_PORT="$DNSTT_PORT"

# Key Files
PRIVATE_KEY_FILE="$PRIVATE_KEY_FILE"
PUBLIC_KEY_FILE="$PUBLIC_KEY_FILE"

# Advanced Settings
CUSTOM_DNS_RESOLVER="$CUSTOM_DNS_RESOLVER"
DOH_ENABLED="$DOH_ENABLED"
DOH_URL="$DOH_URL"
DOT_ENABLED="$DOT_ENABLED"
DOT_ADDRESS="$DOT_ADDRESS"

# Profile
CURRENT_PROFILE="$CURRENT_PROFILE"
EOF

    chmod 640 "$CONFIG_FILE"
    if id "$DNSTT_USER" &>/dev/null; then
        chown root:"$DNSTT_USER" "$CONFIG_FILE"
    fi
    print_status "Configuration saved to $CONFIG_FILE"
}

# ============================================================================
# PROFILE MANAGEMENT
# ============================================================================

list_profiles() {
    print_section "Available Profiles"
    
    if [ ! -d "$PROFILES_DIR" ] || [ -z "$(ls -A "$PROFILES_DIR" 2>/dev/null)" ]; then
        print_warning "No profiles found"
        return 1
    fi

    local i=1
    for profile in "$PROFILES_DIR"/*.conf; do
        if [ -f "$profile" ]; then
            local name
            name=$(basename "$profile" .conf)
            if [ "$name" = "$CURRENT_PROFILE" ]; then
                echo -e "  ${GREEN}$i) $name (active)${NC}"
            else
                echo "  $i) $name"
            fi
            ((i++))
        fi
    done
    return 0
}

save_profile() {
    print_question "Enter profile name: "
    read -r profile_name

    if [ -z "$profile_name" ]; then
        print_error "Profile name cannot be empty"
        return 1
    fi

    # Sanitize profile name
    profile_name=$(echo "$profile_name" | tr -cd '[:alnum:]_-')
    local profile_file="${PROFILES_DIR}/${profile_name}.conf"

    cp "$CONFIG_FILE" "$profile_file"
    echo "PROFILE_NAME=\"$profile_name\"" >> "$profile_file"
    
    CURRENT_PROFILE="$profile_name"
    save_config

    print_status "Profile saved: $profile_name"
}

load_profile() {
    if ! list_profiles; then
        return 1
    fi

    print_question "Enter profile number to load: "
    read -r profile_num

    local i=1
    for profile in "$PROFILES_DIR"/*.conf; do
        if [ -f "$profile" ] && [ "$i" -eq "$profile_num" ]; then
            local name
            name=$(basename "$profile" .conf)
            
            # Backup current config
            backup_config "before_profile_switch"
            
            # Load profile
            cp "$profile" "$CONFIG_FILE"
            load_config
            CURRENT_PROFILE="$name"
            save_config
            
            print_status "Profile loaded: $name"
            print_status "Restarting service with new configuration..."
            restart_services
            return 0
        fi
        ((i++))
    done

    print_error "Invalid profile number"
    return 1
}

delete_profile() {
    if ! list_profiles; then
        return 1
    fi

    print_question "Enter profile number to delete: "
    read -r profile_num

    local i=1
    for profile in "$PROFILES_DIR"/*.conf; do
        if [ -f "$profile" ] && [ "$i" -eq "$profile_num" ]; then
            local name
            name=$(basename "$profile" .conf)
            
            print_question "Are you sure you want to delete profile '$name'? (y/N): "
            read -r confirm
            
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                rm "$profile"
                print_status "Profile deleted: $name"
            else
                print_status "Deletion cancelled"
            fi
            return 0
        fi
        ((i++))
    done

    print_error "Invalid profile number"
    return 1
}

# ============================================================================
# BACKUP MANAGEMENT
# ============================================================================

backup_config() {
    local reason="${1:-manual}"
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="${BACKUP_DIR}/backup_${reason}_${timestamp}.tar.gz"

    print_status "Creating backup..."

    tar -czf "$backup_file" -C "$CONFIG_DIR" \
        --exclude='backups' \
        --exclude='*.tar.gz' \
        . 2>/dev/null || true

    print_status "Backup created: $backup_file"
}

restore_backup() {
    print_section "Available Backups"

    if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A "$BACKUP_DIR"/*.tar.gz 2>/dev/null)" ]; then
        print_warning "No backups found"
        return 1
    fi

    local i=1
    local backups=()
    for backup in "$BACKUP_DIR"/*.tar.gz; do
        if [ -f "$backup" ]; then
            backups+=("$backup")
            local name
            name=$(basename "$backup")
            local size
            size=$(du -h "$backup" | cut -f1)
            echo "  $i) $name ($size)"
            ((i++))
        fi
    done

    print_question "Enter backup number to restore (0 to cancel): "
    read -r backup_num

    if [ "$backup_num" -eq 0 ]; then
        print_status "Restore cancelled"
        return 0
    fi

    local idx=$((backup_num - 1))
    if [ "$idx" -ge 0 ] && [ "$idx" -lt "${#backups[@]}" ]; then
        local selected_backup="${backups[$idx]}"
        
        print_question "This will overwrite current configuration. Continue? (y/N): "
        read -r confirm
        
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            # Backup current first
            backup_config "before_restore"
            
            # Restore
            tar -xzf "$selected_backup" -C "$CONFIG_DIR"
            load_config
            
            print_status "Backup restored successfully"
            print_status "Restarting service..."
            restart_services
        else
            print_status "Restore cancelled"
        fi
    else
        print_error "Invalid backup number"
    fi
}

# ============================================================================
# DNSTT BINARY MANAGEMENT
# ============================================================================

download_dnstt_server() {
    local filename="dnstt-server-linux-${ARCH}"
    local filepath="${INSTALL_DIR}/dnstt-server"

    if [ -f "$filepath" ]; then
        # Check if existing file is a valid binary (not HTML error page)
        if file "$filepath" | grep -q "ELF"; then
            print_status "dnstt-server already exists at $filepath"
            
            print_question "Do you want to re-download? (y/N): "
            read -r redownload
            
            if [[ ! "$redownload" =~ ^[Yy]$ ]]; then
                return 0
            fi
        else
            print_warning "Existing dnstt-server appears corrupted, re-downloading..."
        fi
    fi

    print_status "Downloading dnstt-server from ${DNSTT_BASE_URL}..."

    # Download the binary
    if ! curl -fL -o "/tmp/$filename" "${DNSTT_BASE_URL}/$filename"; then
        print_error "Failed to download dnstt-server"
        exit 1
    fi

    # Verify the downloaded file is actually a binary, not an HTML error page
    if file "/tmp/$filename" | grep -q "HTML\|text"; then
        print_error "Downloaded file appears to be HTML, not a binary."
        print_error "The download URL may be incorrect or the server returned an error."
        rm -f "/tmp/$filename"
        exit 1
    fi

    if ! file "/tmp/$filename" | grep -q "ELF"; then
        print_error "Downloaded file is not a valid Linux binary."
        rm -f "/tmp/$filename"
        exit 1
    fi

    # Download checksums and verify
    print_status "Verifying file integrity..."
    
    if curl -fL -o "/tmp/SHA256SUMS" "${DNSTT_BASE_URL}/SHA256SUMS" 2>/dev/null; then
        cd /tmp
        if sha256sum -c <(grep "$filename" SHA256SUMS) 2>/dev/null; then
            print_status "SHA256 checksum verified"
        else
            print_warning "Checksum verification failed, but binary looks valid. Proceeding..."
        fi
    else
        print_warning "Could not download checksums for verification"
    fi

    chmod +x "/tmp/$filename"
    mv "/tmp/$filename" "$filepath"

    print_status "dnstt-server installed to $filepath"
}

# ============================================================================
# USER AND KEY MANAGEMENT
# ============================================================================

create_dnstt_user() {
    print_status "Setting up dnstt user..."

    if ! id "$DNSTT_USER" &>/dev/null; then
        useradd -r -s /bin/false -d /nonexistent -c "dnstt service user" "$DNSTT_USER"
        print_status "Created user: $DNSTT_USER"
    else
        print_status "User $DNSTT_USER already exists"
    fi

    init_config_dirs
}

generate_keys() {
    local key_prefix
    # shellcheck disable=SC2001
    key_prefix=$(echo "$NS_SUBDOMAIN" | sed 's/\./_/g')
    PRIVATE_KEY_FILE="${CONFIG_DIR}/${key_prefix}_server.key"
    PUBLIC_KEY_FILE="${CONFIG_DIR}/${key_prefix}_server.pub"

    if [[ -f "$PRIVATE_KEY_FILE" && -f "$PUBLIC_KEY_FILE" ]]; then
        print_status "Found existing keys for domain: $NS_SUBDOMAIN"
        
        print_question "Generate new keys? (y/N): "
        read -r regen
        
        if [[ ! "$regen" =~ ^[Yy]$ ]]; then
            chown "$DNSTT_USER":"$DNSTT_USER" "$PRIVATE_KEY_FILE" "$PUBLIC_KEY_FILE"
            chmod 600 "$PRIVATE_KEY_FILE"
            chmod 644 "$PUBLIC_KEY_FILE"
            return 0
        fi
        
        # Backup old keys
        backup_config "before_key_regen"
    fi

    print_status "Generating new keys for domain: $NS_SUBDOMAIN"

    dnstt-server -gen-key -privkey-file "$PRIVATE_KEY_FILE" -pubkey-file "$PUBLIC_KEY_FILE"

    chown "$DNSTT_USER":"$DNSTT_USER" "$PRIVATE_KEY_FILE" "$PUBLIC_KEY_FILE"
    chmod 600 "$PRIVATE_KEY_FILE"
    chmod 644 "$PUBLIC_KEY_FILE"

    print_status "New keys generated"
    print_status "  Private key: $PRIVATE_KEY_FILE"
    print_status "  Public key: $PUBLIC_KEY_FILE"
}

show_public_key() {
    if [ -f "$PUBLIC_KEY_FILE" ]; then
        echo ""
        print_section "Public Key"
        echo -e "${YELLOW}$(cat "$PUBLIC_KEY_FILE")${NC}"
        echo ""
    else
        print_warning "Public key file not found"
    fi
}

generate_qr_code() {
    if ! command -v qrencode &> /dev/null; then
        print_warning "qrencode not installed. Install it for QR code generation."
        return 1
    fi

    if [ ! -f "$PUBLIC_KEY_FILE" ]; then
        print_error "Public key file not found"
        return 1
    fi

    local pubkey
    pubkey=$(cat "$PUBLIC_KEY_FILE")
    local qr_file="${CONFIG_DIR}/${NS_SUBDOMAIN//\./_}_qr.png"

    print_section "QR Code for Public Key"

    # Display in terminal
    echo "$pubkey" | qrencode -t ANSIUTF8

    # Save to file
    echo "$pubkey" | qrencode -o "$qr_file"
    print_status "QR code saved to: $qr_file"
}

# ============================================================================
# NETWORK CONFIGURATION
# ============================================================================

configure_iptables() {
    print_status "Configuring iptables rules..."

    local interface
    interface=$(ip route | grep default | awk '{print $5}' | head -1)
    if [[ -z "$interface" ]]; then
        interface=$(ip link show | grep -E "^[0-9]+: (eth|ens|enp)" | head -1 | cut -d':' -f2 | awk '{print $1}')
        if [[ -z "$interface" ]]; then
            interface="eth0"
            print_warning "Could not detect network interface, using eth0"
        fi
    fi
    print_status "Using network interface: $interface"

    # IPv4 rules
    iptables -I INPUT -p udp --dport "$DNSTT_PORT" -j ACCEPT 2>/dev/null || true
    iptables -t nat -I PREROUTING -i "$interface" -p udp --dport 53 -j REDIRECT --to-ports "$DNSTT_PORT" 2>/dev/null || true

    print_status "IPv4 iptables rules configured"

    # IPv6 rules
    if command -v ip6tables &> /dev/null && [ -f /proc/net/if_inet6 ]; then
        ip6tables -I INPUT -p udp --dport "$DNSTT_PORT" -j ACCEPT 2>/dev/null || true
        ip6tables -t nat -I PREROUTING -i "$interface" -p udp --dport 53 -j REDIRECT --to-ports "$DNSTT_PORT" 2>/dev/null || true
        print_status "IPv6 iptables rules configured"
    fi

    # Save rules
    save_iptables_rules
}

save_iptables_rules() {
    print_status "Saving iptables rules..."

    case $PKG_MANAGER in
        dnf|yum)
            mkdir -p /etc/sysconfig
            iptables-save > /etc/sysconfig/iptables 2>/dev/null || true
            if command -v ip6tables-save &> /dev/null; then
                ip6tables-save > /etc/sysconfig/ip6tables 2>/dev/null || true
            fi
            systemctl enable iptables 2>/dev/null || true
            ;;
        apt)
            mkdir -p /etc/iptables
            iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
            if command -v ip6tables-save &> /dev/null; then
                ip6tables-save > /etc/iptables/rules.v6 2>/dev/null || true
            fi
            systemctl enable netfilter-persistent 2>/dev/null || true
            ;;
    esac
}

configure_firewall() {
    print_status "Configuring firewall..."

    if command -v firewall-cmd &> /dev/null && systemctl is-active --quiet firewalld; then
        firewall-cmd --permanent --add-port="$DNSTT_PORT"/udp
        firewall-cmd --permanent --add-port=53/udp
        firewall-cmd --reload
        print_status "Firewalld configured"
    elif command -v ufw &> /dev/null && ufw status | grep -q "Status: active"; then
        ufw allow "$DNSTT_PORT"/udp
        ufw allow 53/udp
        print_status "UFW configured"
    fi

    configure_iptables
}

# ============================================================================
# DANTE SOCKS PROXY
# ============================================================================

setup_dante() {
    print_status "Setting up Dante SOCKS proxy..."

    case $PKG_MANAGER in
        dnf|yum)
            $PKG_MANAGER install -y dante-server
            ;;
        apt)
            apt install -y dante-server
            ;;
    esac

    local external_interface
    external_interface=$(ip route | grep default | awk '{print $5}' | head -1)
    if [[ -z "$external_interface" ]]; then
        external_interface="eth0"
    fi

    cat > /etc/danted.conf << EOF
# Dante SOCKS server configuration
# Generated by dnstt-helper

logoutput: syslog
user.privileged: root
user.unprivileged: nobody

internal: 127.0.0.1 port = 1080

external: $external_interface

socksmethod: none

compatibility: sameport
extension: bind

client pass {
    from: 127.0.0.0/8 to: 0.0.0.0/0
    log: error
}

socks pass {
    from: 127.0.0.0/8 to: 0.0.0.0/0
    command: bind connect udpassociate
    log: error
}

socks block {
    from: 0.0.0.0/0 to: ::/0
    log: error
}

client block {
    from: 0.0.0.0/0 to: ::/0
    log: error
}
EOF

    systemctl enable danted
    systemctl restart danted

    print_status "Dante SOCKS proxy configured on 127.0.0.1:1080"
}

# ============================================================================
# SYSTEMD SERVICE
# ============================================================================

create_systemd_service() {
    print_status "Creating systemd service..."

    local service_file="${SYSTEMD_DIR}/dnstt-server.service"
    local target_port

    if [ "$TUNNEL_MODE" = "ssh" ]; then
        target_port=$(ss -tlnp | grep sshd | awk '{print $4}' | cut -d':' -f2 | head -1)
        if [[ -z "$target_port" ]]; then
            target_port="22"
        fi
        print_status "Using SSH port: $target_port"
    else
        target_port="1080"
    fi

    if systemctl is-active --quiet dnstt-server; then
        print_status "Stopping existing service..."
        systemctl stop dnstt-server
    fi

    cat > "$service_file" << EOF
[Unit]
Description=dnstt DNS Tunnel Server (dnstt-helper)
After=network.target
Wants=network.target

[Service]
Type=simple
User=$DNSTT_USER
Group=$DNSTT_USER
ExecStart=${INSTALL_DIR}/dnstt-server -udp :${DNSTT_PORT} -privkey-file ${PRIVATE_KEY_FILE} -mtu ${MTU_VALUE} ${NS_SUBDOMAIN} 127.0.0.1:${target_port}
Restart=always
RestartSec=5
KillMode=mixed
TimeoutStopSec=5

# Security
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadOnlyPaths=/
ReadWritePaths=${CONFIG_DIR}
PrivateTmp=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable dnstt-server

    print_status "Systemd service created"
}

start_services() {
    print_status "Starting services..."
    systemctl start dnstt-server
    print_status "dnstt-server started"
}

restart_services() {
    print_status "Restarting services..."
    systemctl restart dnstt-server
    
    if [ "$TUNNEL_MODE" = "socks" ] && systemctl is-enabled --quiet danted 2>/dev/null; then
        systemctl restart danted
    fi
    
    print_status "Services restarted"
}

stop_services() {
    print_status "Stopping services..."
    systemctl stop dnstt-server 2>/dev/null || true
    print_status "Services stopped"
}

# ============================================================================
# USER INPUT
# ============================================================================

get_user_input() {
    local existing_domain=""
    local existing_mtu=""
    local existing_mode=""

    if load_config 2>/dev/null; then
        existing_domain="$NS_SUBDOMAIN"
        existing_mtu="$MTU_VALUE"
        existing_mode="$TUNNEL_MODE"
        print_status "Found existing configuration"
    fi

    # Nameserver subdomain
    while true; do
        if [[ -n "$existing_domain" ]]; then
            print_question "Enter nameserver subdomain (current: $existing_domain): "
        else
            print_question "Enter nameserver subdomain (e.g., t.example.com): "
        fi
        read -r NS_SUBDOMAIN

        if [[ -z "$NS_SUBDOMAIN" && -n "$existing_domain" ]]; then
            NS_SUBDOMAIN="$existing_domain"
        fi

        if [[ -n "$NS_SUBDOMAIN" ]]; then
            break
        fi
        print_error "Please enter a valid subdomain"
    done

    # MTU value
    echo ""
    echo "MTU Recommendations:"
    echo "  1400 - Stable/Fast networks"
    echo "  1232 - Standard networks (default)"
    echo "  1200 - Unstable/Slow networks"
    echo "  512  - Restricted mobile networks"
    echo ""
    
    if [[ -n "$existing_mtu" ]]; then
        print_question "Enter MTU value (current: $existing_mtu): "
    else
        print_question "Enter MTU value (default: $DEFAULT_MTU): "
    fi
    read -r MTU_VALUE

    if [[ -z "$MTU_VALUE" ]]; then
        MTU_VALUE="${existing_mtu:-$DEFAULT_MTU}"
    fi

    # Tunnel mode
    echo ""
    echo "Tunnel Modes:"
    echo "  1) SOCKS proxy - Full internet proxy via Dante"
    echo "  2) SSH mode - Direct SSH tunnel"
    echo ""
    
    while true; do
        if [[ -n "$existing_mode" ]]; then
            local mode_num
            [[ "$existing_mode" == "socks" ]] && mode_num="1" || mode_num="2"
            print_question "Select tunnel mode (current: $mode_num - $existing_mode): "
        else
            print_question "Select tunnel mode (1 or 2): "
        fi
        read -r mode_choice

        if [[ -z "$mode_choice" && -n "$existing_mode" ]]; then
            TUNNEL_MODE="$existing_mode"
            break
        fi

        case $mode_choice in
            1) TUNNEL_MODE="socks"; break ;;
            2) TUNNEL_MODE="ssh"; break ;;
            *) print_error "Invalid choice" ;;
        esac
    done

    # Custom port (advanced)
    echo ""
    print_question "Use custom listen port? (default: $DNSTT_PORT) [y/N]: "
    read -r custom_port_choice
    
    if [[ "$custom_port_choice" =~ ^[Yy]$ ]]; then
        print_question "Enter custom port: "
        read -r custom_port
        if [[ "$custom_port" =~ ^[0-9]+$ ]] && [ "$custom_port" -gt 0 ] && [ "$custom_port" -lt 65536 ]; then
            DNSTT_PORT="$custom_port"
        else
            print_warning "Invalid port, using default: $DNSTT_PORT"
        fi
    fi

    # Summary
    print_section "Configuration Summary"
    echo "  Nameserver subdomain: $NS_SUBDOMAIN"
    echo "  MTU: $MTU_VALUE"
    echo "  Tunnel mode: $TUNNEL_MODE"
    echo "  Listen port: $DNSTT_PORT"
}

# ============================================================================
# CLIENT CONFIGURATION GENERATION
# ============================================================================

generate_client_config() {
    if [ ! -f "$PUBLIC_KEY_FILE" ]; then
        print_error "No server configuration found. Please install/configure first."
        return 1
    fi

    local pubkey
    pubkey=$(cat "$PUBLIC_KEY_FILE")

    print_section "Client Configuration"

    # JSON config
    local json_config="${CONFIG_DIR}/client-config.json"
    cat > "$json_config" << EOF
{
    "domain": "$NS_SUBDOMAIN",
    "local_addr": "127.0.0.1:7000",
    "pubkey": "$pubkey",
    "resolvers": [
        {"type": "udp", "addr": "8.8.8.8:53"},
        {"type": "udp", "addr": "1.1.1.1:53"}
    ],
    "mtu": $MTU_VALUE,
    "failover": true
}
EOF
    print_status "JSON config saved: $json_config"

    # YAML config
    local yaml_config="${CONFIG_DIR}/client-config.yaml"
    cat > "$yaml_config" << EOF
domain: $NS_SUBDOMAIN
local_addr: 127.0.0.1:7000
pubkey: "$pubkey"
resolvers:
  - type: udp
    addr: 8.8.8.8:53
  - type: udp
    addr: 1.1.1.1:53
mtu: $MTU_VALUE
failover: true
EOF
    print_status "YAML config saved: $yaml_config"

    # Command examples
    echo ""
    print_section "Client Connection Commands"
    echo -e "${CYAN}Linux/macOS:${NC}"
    echo "  ./dnstt-client -udp DNS_SERVER:53 -pubkey-file server.pub $NS_SUBDOMAIN 127.0.0.1:7000"
    echo ""
    echo -e "${CYAN}Windows:${NC}"
    echo "  dnstt-client.exe -udp DNS_SERVER:53 -pubkey-file server.pub $NS_SUBDOMAIN 127.0.0.1:7000"
    echo ""
    echo -e "${CYAN}With public key inline:${NC}"
    echo "  ./dnstt-client -udp 8.8.8.8:53 -pubkey $pubkey $NS_SUBDOMAIN 127.0.0.1:7000"
    echo ""

    # Download links
    print_section "Client Downloads"
    echo "Download clients from: ${GITHUB_RELEASES}"
    echo ""
    echo "Available platforms:"
    echo "  - Windows x64: dnstt-client-windows-amd64.exe"
    echo "  - macOS Intel: dnstt-client-darwin-amd64"
    echo "  - macOS ARM: dnstt-client-darwin-arm64"
    echo "  - Linux x64: dnstt-client-linux-amd64"
    echo "  - Linux ARM64: dnstt-client-linux-arm64"
}

# ============================================================================
# STATISTICS AND MONITORING
# ============================================================================

show_stats() {
    print_header "Performance Statistics"

    # Service status
    print_section "Service Status"
    if systemctl is-active --quiet dnstt-server; then
        echo -e "dnstt-server: ${GREEN}Running${NC}"
        
        # Get process info
        local pid
        pid=$(pgrep -f "dnstt-server" | head -1)
        if [ -n "$pid" ]; then
            echo "  PID: $pid"
            echo "  Memory: $(ps -o rss= -p "$pid" | awk '{print int($1/1024)"MB"}')"
            echo "  CPU: $(ps -o %cpu= -p "$pid")%"
            echo "  Uptime: $(ps -o etime= -p "$pid")"
        fi
    else
        echo -e "dnstt-server: ${RED}Stopped${NC}"
    fi

    if [ "$TUNNEL_MODE" = "socks" ]; then
        echo ""
        if systemctl is-active --quiet danted; then
            echo -e "Dante SOCKS: ${GREEN}Running${NC}"
        else
            echo -e "Dante SOCKS: ${RED}Stopped${NC}"
        fi
    fi

    # Network stats
    print_section "Network Statistics"
    echo "Port $DNSTT_PORT UDP connections:"
    ss -u -a | grep -c ":$DNSTT_PORT" || echo "0"

    # iptables stats
    print_section "Firewall Statistics"
    echo "NAT rules for DNS redirect:"
    iptables -t nat -L PREROUTING -v -n 2>/dev/null | grep "$DNSTT_PORT" || echo "No rules found"
}

# ============================================================================
# DISPLAY FUNCTIONS
# ============================================================================

show_configuration_info() {
    print_header "Current Configuration"

    if [ ! -f "$CONFIG_FILE" ]; then
        print_warning "No configuration found. Please install/configure first."
        return 1
    fi

    load_config

    local service_status
    if systemctl is-active --quiet dnstt-server; then
        service_status="${GREEN}Running${NC}"
    else
        service_status="${RED}Stopped${NC}"
    fi

    echo -e "${CYAN}Server Settings:${NC}"
    echo "  Nameserver subdomain: $NS_SUBDOMAIN"
    echo "  MTU: $MTU_VALUE"
    echo "  Tunnel mode: $TUNNEL_MODE"
    echo "  Listen port: $DNSTT_PORT"
    echo -e "  Service status: $service_status"
    echo ""

    if [ -n "$CURRENT_PROFILE" ]; then
        echo -e "${CYAN}Active Profile:${NC} $CURRENT_PROFILE"
        echo ""
    fi

    show_public_key

    echo -e "${CYAN}Management Commands:${NC}"
    echo "  dnstt-helper              - Show this menu"
    echo "  systemctl status dnstt-server"
    echo "  journalctl -u dnstt-server -f"

    if [ "$TUNNEL_MODE" = "socks" ]; then
        echo ""
        echo -e "${CYAN}SOCKS Proxy:${NC}"
        echo "  Address: 127.0.0.1:1080"
        echo "  systemctl status danted"
    fi
}

print_success_box() {
    echo ""
    echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}${BOLD}                    SETUP COMPLETED SUCCESSFULLY!                   ${NC}"
    echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════════════════════${NC}"
    echo ""

    show_configuration_info
    
    echo ""
    echo -e "${CYAN}Next Steps:${NC}"
    echo "  1. Copy the public key above"
    echo "  2. Download client from: ${GITHUB_RELEASES}"
    echo "  3. Run: dnstt-client -udp DNS_SERVER:53 -pubkey-file server.pub $NS_SUBDOMAIN 127.0.0.1:7000"
    echo ""
}

# ============================================================================
# SCRIPT MANAGEMENT
# ============================================================================

install_script() {
    print_status "Installing dnstt-helper script..."

    local temp_script="/tmp/dnstt-helper-new.sh"
    curl -Ls "$SCRIPT_URL" -o "$temp_script"
    chmod +x "$temp_script"

    if [ -f "$SCRIPT_INSTALL_PATH" ]; then
        local current_checksum new_checksum
        current_checksum=$(sha256sum "$SCRIPT_INSTALL_PATH" | cut -d' ' -f1)
        new_checksum=$(sha256sum "$temp_script" | cut -d' ' -f1)

        if [ "$current_checksum" = "$new_checksum" ]; then
            print_status "Script is already up to date"
            rm "$temp_script"
            return 0
        fi
    fi

    cp "$temp_script" "$SCRIPT_INSTALL_PATH"
    rm "$temp_script"

    print_status "Script installed to $SCRIPT_INSTALL_PATH"
}

update_script() {
    print_status "Checking for updates..."

    local temp_script="/tmp/dnstt-helper-latest.sh"
    if ! curl -Ls "$SCRIPT_URL" -o "$temp_script"; then
        print_error "Failed to download latest version"
        return 1
    fi

    local current_checksum latest_checksum
    current_checksum=$(sha256sum "$SCRIPT_INSTALL_PATH" | cut -d' ' -f1)
    latest_checksum=$(sha256sum "$temp_script" | cut -d' ' -f1)

    if [ "$current_checksum" = "$latest_checksum" ]; then
        print_status "Already running the latest version"
        rm "$temp_script"
        return 0
    fi

    print_status "New version available! Updating..."
    chmod +x "$temp_script"
    cp "$temp_script" "$SCRIPT_INSTALL_PATH"
    rm "$temp_script"
    
    print_status "Script updated! Restarting..."
    exec "$SCRIPT_INSTALL_PATH"
}

check_for_updates() {
    if [ "$0" = "$SCRIPT_INSTALL_PATH" ]; then
        local temp_script="/tmp/dnstt-helper-check.sh"
        if curl -Ls "$SCRIPT_URL" -o "$temp_script" 2>/dev/null; then
            local current_checksum latest_checksum
            current_checksum=$(sha256sum "$SCRIPT_INSTALL_PATH" | cut -d' ' -f1)
            latest_checksum=$(sha256sum "$temp_script" | cut -d' ' -f1)

            if [ "$current_checksum" != "$latest_checksum" ]; then
                UPDATE_AVAILABLE=true
            fi
            rm "$temp_script" 2>/dev/null || true
        fi
    fi
}

# ============================================================================
# MENU SYSTEM
# ============================================================================

show_menu() {
    clear
    echo ""
    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║              dnstt-helper Server Management v${VERSION}              ║${NC}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    if [ "$UPDATE_AVAILABLE" = true ]; then
        echo -e "${YELLOW}[UPDATE AVAILABLE]${NC} New version available! Use option 2 to update."
        echo ""
    fi

    echo -e "${BOLD}Server Management:${NC}"
    echo "  1) Install/Reconfigure dnstt server"
    echo "  2) Update dnstt-helper script"
    echo "  3) Check service status"
    echo "  4) View service logs"
    echo "  5) Show configuration info"
    echo ""
    echo -e "${BOLD}Client Tools:${NC}"
    echo "  6) Generate client config"
    echo "  7) Show QR code for public key"
    echo ""
    echo -e "${BOLD}Advanced:${NC}"
    echo "  8) Manage profiles"
    echo "  9) Backup/Restore"
    echo "  10) Performance statistics"
    echo ""
    echo "  0) Exit"
    echo ""
    print_question "Select option: "
}

profile_menu() {
    while true; do
        echo ""
        echo -e "${BOLD}Profile Management:${NC}"
        echo "  1) List profiles"
        echo "  2) Save current as profile"
        echo "  3) Load profile"
        echo "  4) Delete profile"
        echo "  0) Back to main menu"
        echo ""
        print_question "Select option: "
        read -r choice

        case $choice in
            1) list_profiles ;;
            2) save_profile ;;
            3) load_profile ;;
            4) delete_profile ;;
            0) return ;;
            *) print_error "Invalid option" ;;
        esac
    done
}

backup_menu() {
    while true; do
        echo ""
        echo -e "${BOLD}Backup/Restore:${NC}"
        echo "  1) Create backup"
        echo "  2) Restore from backup"
        echo "  0) Back to main menu"
        echo ""
        print_question "Select option: "
        read -r choice

        case $choice in
            1) backup_config "manual" ;;
            2) restore_backup ;;
            0) return ;;
            *) print_error "Invalid option" ;;
        esac
    done
}

handle_menu() {
    while true; do
        show_menu
        read -r choice

        case $choice in
            1)
                return 0  # Continue with installation
                ;;
            2)
                update_script
                ;;
            3)
                echo ""
                if systemctl is-active --quiet dnstt-server; then
                    print_status "dnstt-server is running"
                else
                    print_warning "dnstt-server is not running"
                fi
                systemctl status dnstt-server --no-pager -l 2>/dev/null || true
                ;;
            4)
                print_status "Showing logs (Ctrl+C to exit)..."
                journalctl -u dnstt-server -f
                ;;
            5)
                show_configuration_info
                ;;
            6)
                generate_client_config
                ;;
            7)
                generate_qr_code
                ;;
            8)
                profile_menu
                ;;
            9)
                backup_menu
                ;;
            10)
                show_stats
                ;;
            0)
                print_status "Goodbye!"
                exit 0
                ;;
            *)
                print_error "Invalid option"
                ;;
        esac

        if [ "$choice" != "4" ]; then
            echo ""
            print_question "Press Enter to continue..."
            read -r
        fi
    done
}

# ============================================================================
# MAIN INSTALLATION
# ============================================================================

run_installation() {
    print_header "DNSTT Server Installation"

    detect_os
    detect_arch
    check_required_tools

    get_user_input

    download_dnstt_server
    create_dnstt_user
    generate_keys

    save_config

    configure_firewall

    if [ "$TUNNEL_MODE" = "socks" ]; then
        setup_dante
    else
        if systemctl is-active --quiet danted; then
            print_status "Stopping Dante (switching to SSH mode)..."
            systemctl stop danted
            systemctl disable danted
        fi
    fi

    create_systemd_service
    start_services

    print_success_box
}

# ============================================================================
# MAIN ENTRY POINT
# ============================================================================

main() {
    check_root

    if [ "$0" != "$SCRIPT_INSTALL_PATH" ]; then
        print_status "Installing dnstt-helper..."
        install_script
        print_status "Starting setup..."
        run_installation
    else
        check_for_updates
        handle_menu
        run_installation
    fi
}

# Run
main "$@"

