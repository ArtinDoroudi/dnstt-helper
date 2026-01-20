# Server Setup Guide

Complete guide for deploying and configuring a DNSTT server using dnstt-helper.

## Prerequisites

### Server Requirements

- **Linux server** with root access
- **Supported distributions**:
  - Ubuntu 18.04+
  - Debian 10+
  - CentOS 7+
  - Rocky Linux 8+
  - Fedora 33+
- **Network**:
  - Public IP address
  - Port 53 UDP accessible (for DNS traffic)
- **Domain** with DNS control

### Domain Setup

Before running the script, configure your DNS records:

#### Example Configuration

- Domain: `example.com`
- Server IP: `203.0.113.2`
- Tunnel subdomain: `t.example.com`
- Server hostname: `tns.example.com`

#### Required DNS Records

| Type | Name | Value | TTL |
|------|------|-------|-----|
| A | `tns.example.com` | `203.0.113.2` | 300 |
| AAAA | `tns.example.com` | `2001:db8::2` | 300 |
| NS | `t.example.com` | `tns.example.com` | 300 |

**Important**: The NS record delegates DNS queries for `t.example.com` to your server.

#### Verification

After adding records, verify propagation:

```bash
# Check A record
dig +short tns.example.com

# Check NS record
dig +short NS t.example.com
```

Wait up to 24 hours for full propagation.

## Installation

### One-Command Install

```bash
bash <(curl -Ls https://raw.githubusercontent.com/ArtinDoroudi/dnstt-helper/main/server/dnstt-helper.sh)
```

This command:
1. Downloads the script
2. Installs to `/usr/local/bin/dnstt-helper`
3. Starts the interactive setup

### Manual Installation

```bash
# Download
curl -Lo /usr/local/bin/dnstt-helper https://raw.githubusercontent.com/ArtinDoroudi/dnstt-helper/main/server/dnstt-helper.sh

# Make executable
chmod +x /usr/local/bin/dnstt-helper

# Run
dnstt-helper
```

## Configuration

### Interactive Setup

The script prompts for:

1. **Nameserver subdomain** (e.g., `t.example.com`)
2. **MTU value** (default: 1232)
3. **Tunnel mode** (SOCKS or SSH)
4. **Custom port** (optional, default: 5300)

### Configuration Options

#### MTU Settings

| Value | Use Case |
|-------|----------|
| 1400 | Stable, high-bandwidth networks |
| 1232 | Standard networks (default) |
| 1200 | Unstable networks |
| 512 | Highly restricted networks |

**Tip**: Start with 1232, lower if you see connection issues.

#### Tunnel Modes

**SOCKS Mode**:
- Provides SOCKS5 proxy on `127.0.0.1:1080`
- Good for general internet access
- Uses Dante SOCKS server

**SSH Mode**:
- Forwards to SSH port (auto-detected)
- Good for secure shell access
- Compatible with SSH apps on mobile

### Advanced Configuration

#### Custom Port

By default, dnstt-server listens on port 5300, with iptables redirecting port 53 → 5300.

To use a different port:
1. Run `dnstt-helper`
2. Choose "Install/Reconfigure"
3. Answer "y" to custom port question
4. Enter your preferred port

#### Multiple Domains

The script supports multiple domains:
- Each domain gets its own key pair
- Only one domain can be active at a time
- Switch between domains using profiles

## Managing the Server

### Menu Options

Run `dnstt-helper` to access the management menu:

```
╔══════════════════════════════════════════════════════════════════╗
║              dnstt-helper Server Management v1.0.0               ║
╚══════════════════════════════════════════════════════════════════╝

Server Management:
  1) Install/Reconfigure dnstt server
  2) Update dnstt-helper script
  3) Check service status
  4) View service logs
  5) Show configuration info

Client Tools:
  6) Generate client config
  7) Show QR code for public key

Advanced:
  8) Manage profiles
  9) Backup/Restore
  10) Performance statistics

  0) Exit
```

### Service Commands

```bash
# Check status
systemctl status dnstt-server

# Start/stop/restart
systemctl start dnstt-server
systemctl stop dnstt-server
systemctl restart dnstt-server

# View logs
journalctl -u dnstt-server -f

# For SOCKS mode, also manage Dante:
systemctl status danted
```

### Profile Management

Save different configurations as profiles:

```bash
dnstt-helper
# Choose option 8 → Manage profiles
# Option 2 → Save current as profile
# Enter profile name
```

Load a profile:
```bash
# Choose option 8 → Manage profiles
# Option 3 → Load profile
# Select profile number
```

### Backup and Restore

Create a backup:
```bash
dnstt-helper
# Choose option 9 → Backup/Restore
# Option 1 → Create backup
```

Backups are stored in `/etc/dnstt/backups/`

Restore from backup:
```bash
# Choose option 9 → Backup/Restore
# Option 2 → Restore from backup
# Select backup file
```

## File Locations

| Path | Description |
|------|-------------|
| `/usr/local/bin/dnstt-helper` | Management script |
| `/usr/local/bin/dnstt-server` | DNSTT server binary |
| `/etc/dnstt/` | Configuration directory |
| `/etc/dnstt/dnstt-server.conf` | Main configuration |
| `/etc/dnstt/profiles/` | Saved profiles |
| `/etc/dnstt/backups/` | Configuration backups |
| `/etc/dnstt/*_server.key` | Private keys |
| `/etc/dnstt/*_server.pub` | Public keys |
| `/etc/systemd/system/dnstt-server.service` | Systemd service |

## Security

### Firewall Rules

The script automatically configures:

```bash
# Allow DNSTT port
iptables -I INPUT -p udp --dport 5300 -j ACCEPT

# Redirect DNS to DNSTT
iptables -t nat -I PREROUTING -i eth0 -p udp --dport 53 -j REDIRECT --to-ports 5300
```

### Service Security

The systemd service runs with security hardening:

- Non-root user (`dnstt`)
- Read-only filesystem
- Private temp directory
- Protected kernel tunables

### Key Security

- Private keys: `600` permissions, owned by `dnstt` user
- Public keys: `644` permissions (safe to share)
- Configuration: `640` permissions

## Monitoring

### Check Connection Count

```bash
ss -u -a | grep -c ":5300"
```

### View Live Statistics

```bash
dnstt-helper
# Choose option 10 → Performance statistics
```

### Monitor Logs

```bash
# Live logs
journalctl -u dnstt-server -f

# Last 100 lines
journalctl -u dnstt-server -n 100

# Since last boot
journalctl -u dnstt-server -b
```

## Troubleshooting

### Service Won't Start

```bash
# Check detailed status
systemctl status dnstt-server -l

# Check for port conflicts
ss -tulnp | grep 5300

# Verify binary
ls -la /usr/local/bin/dnstt-server

# Check permissions
ls -la /etc/dnstt/
```

### DNS Not Reaching Server

```bash
# Check iptables rules
iptables -t nat -L PREROUTING -v -n | grep 5300

# Test DNS query (from client)
dig @YOUR_SERVER_IP test.t.example.com

# Check if service is listening
ss -ulnp | grep 5300
```

### Connection Issues

1. Verify DNS propagation (wait 24h)
2. Check firewall allows UDP 53
3. Verify NS record points to server
4. Test with different MTU values

See [Troubleshooting Guide](troubleshooting.md) for more solutions.

## Updating

### Update the Script

```bash
dnstt-helper
# Choose option 2 → Update dnstt-helper script
```

Or manually:
```bash
bash <(curl -Ls https://raw.githubusercontent.com/ArtinDoroudi/dnstt-helper/main/server/dnstt-helper.sh)
```

### Update DNSTT Binary

```bash
dnstt-helper
# Choose option 1 → Install/Reconfigure
# Answer "y" when asked to re-download
```

## Uninstallation

To completely remove dnstt-helper:

```bash
# Stop services
systemctl stop dnstt-server
systemctl disable dnstt-server
systemctl stop danted 2>/dev/null
systemctl disable danted 2>/dev/null

# Remove files
rm -f /usr/local/bin/dnstt-helper
rm -f /usr/local/bin/dnstt-server
rm -rf /etc/dnstt/
rm -f /etc/systemd/system/dnstt-server.service
systemctl daemon-reload

# Remove iptables rules (manual)
iptables -t nat -D PREROUTING -i eth0 -p udp --dport 53 -j REDIRECT --to-ports 5300
iptables -D INPUT -p udp --dport 5300 -j ACCEPT
```

## Next Steps

After server setup:

1. [Download clients](../clients/README.md) for your platforms
2. [Configure Android](../android/quick-start.md) if needed
3. Share the public key with users
4. Monitor performance and adjust MTU if needed

