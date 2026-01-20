# DNSTT Helper - Server

Enhanced DNSTT server deployment script with advanced configuration options.

## Quick Install

```bash
bash <(curl -Ls https://raw.githubusercontent.com/ArtinDoroudi/dnstt-helper/main/server/dnstt-helper.sh)
```

## Features

- **Multi-distribution support**: Fedora, Rocky Linux, CentOS, Debian, Ubuntu
- **Custom DNS resolver selection**: DoH/DoT support
- **Advanced MTU tuning**: Automatic and manual options
- **Configuration profiles**: Save/load different configurations
- **QR code generation**: Easy mobile key import
- **Performance monitoring**: Statistics and diagnostics
- **Backup/restore**: Configuration management
- **Client config generation**: Automatic client configuration files

## Post-Installation

After installation, manage your server with:

```bash
dnstt-helper
```

### Menu Options

1. Install/Reconfigure dnstt server
2. Update dnstt-helper script
3. Check service status
4. View service logs
5. Show configuration info
6. Generate client config
7. Manage profiles
8. Performance stats
0. Exit

## Configuration

### MTU Settings

| Network Type | Recommended MTU |
|--------------|-----------------|
| Stable/Fast | 1400 |
| Standard | 1232 (default) |
| Unstable/Slow | 1200 |
| Restricted Mobile | 512 |

### Tunnel Modes

- **SOCKS**: Integrated Dante SOCKS5 proxy on `127.0.0.1:1080`
- **SSH**: Direct SSH tunnel (auto-detects SSH port)

## File Locations

```
/usr/local/bin/dnstt-helper          # Management script
/usr/local/bin/dnstt-server          # Main binary
/etc/dnstt/                          # Configuration directory
├── dnstt-server.conf               # Main configuration
├── profiles/                       # Saved profiles
├── {domain}_server.key             # Private key (per domain)
└── {domain}_server.pub             # Public key (per domain)
/etc/systemd/system/dnstt-server.service  # Systemd service
```

## Service Commands

```bash
# dnstt-server
sudo systemctl status dnstt-server
sudo systemctl start dnstt-server
sudo systemctl stop dnstt-server
sudo systemctl restart dnstt-server
sudo journalctl -u dnstt-server -f

# Dante SOCKS (if using SOCKS mode)
sudo systemctl status danted
sudo systemctl start danted
sudo systemctl stop danted
```

## Troubleshooting

See [Troubleshooting Guide](../docs/troubleshooting.md) for common issues and solutions.

