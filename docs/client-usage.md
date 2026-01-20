# Client Usage Guide

Complete guide for using dnstt-helper clients on Windows, macOS, and Linux.

## Download

Download the appropriate binary for your platform from [GitHub Releases](https://github.com/ArtinDoroudi/dnstt-helper/releases).

### Available Binaries

| Platform | Architecture | Filename |
|----------|--------------|----------|
| Windows | x64 | `dnstt-client-windows-amd64.exe` |
| Windows | x86 | `dnstt-client-windows-386.exe` |
| macOS | Intel | `dnstt-client-darwin-amd64` |
| macOS | Apple Silicon | `dnstt-client-darwin-arm64` |
| Linux | x64 | `dnstt-client-linux-amd64` |
| Linux | ARM64 | `dnstt-client-linux-arm64` |
| Linux | ARM (32-bit) | `dnstt-client-linux-arm` |
| Linux | x86 | `dnstt-client-linux-386` |

## Installation

### Linux / macOS

```bash
# Download (example for Linux x64)
curl -LO https://github.com/ArtinDoroudi/dnstt-helper/releases/latest/download/dnstt-client-linux-amd64

# Make executable
chmod +x dnstt-client-linux-amd64

# Optional: Move to PATH
sudo mv dnstt-client-linux-amd64 /usr/local/bin/dnstt-client
```

### Windows

1. Download `dnstt-client-windows-amd64.exe`
2. Optionally rename to `dnstt-client.exe`
3. Open Command Prompt or PowerShell in the download folder

## Basic Usage

### Syntax

```bash
dnstt-client [options] <domain> <local-address>
```

### Required Information

You need from your server:
- **Domain**: Your tunnel subdomain (e.g., `t.example.com`)
- **Public Key**: From server setup (hex string or file)
- **DNS Server**: A DNS resolver that can reach your server

### Simple Connection

```bash
# Linux/macOS
./dnstt-client -udp 8.8.8.8:53 -pubkey-file server.pub t.example.com 127.0.0.1:7000

# Windows
dnstt-client.exe -udp 8.8.8.8:53 -pubkey-file server.pub t.example.com 127.0.0.1:7000
```

This creates a local port `7000` that tunnels to your server.

## Command-Line Options

### Connection Options

| Option | Description | Example |
|--------|-------------|---------|
| `-udp <addr>` | UDP DNS resolver | `-udp 8.8.8.8:53` |
| `-doh <url>` | DNS-over-HTTPS resolver | `-doh https://dns.google/dns-query` |
| `-dot <addr>` | DNS-over-TLS resolver | `-dot dns.google:853` |

### Authentication

| Option | Description | Example |
|--------|-------------|---------|
| `-pubkey <key>` | Public key as hex string | `-pubkey abc123...` |
| `-pubkey-file <file>` | Public key file | `-pubkey-file server.pub` |

### Performance

| Option | Description | Default |
|--------|-------------|---------|
| `-mtu <size>` | Maximum transmission unit | 1232 |

## Finding Your DNS Server

### Linux

```bash
# systemd-resolved
resolvectl status | grep "DNS Servers"

# Traditional
cat /etc/resolv.conf | grep nameserver
```

### macOS

```bash
scutil --dns | grep nameserver
```

### Windows

```cmd
ipconfig /all | findstr "DNS Servers"
```

### Common DNS Servers

| Provider | Address | Use Case |
|----------|---------|----------|
| Google | `8.8.8.8:53` | Reliable, fast |
| Cloudflare | `1.1.1.1:53` | Privacy-focused |
| OpenDNS | `208.67.222.222:53` | Filtering available |
| Router | `192.168.1.1:53` | Local network |
| ISP DNS | Varies | Often fastest |

## Connection Examples

### Basic UDP Connection

```bash
./dnstt-client -udp 8.8.8.8:53 -pubkey-file server.pub t.example.com 127.0.0.1:7000
```

### Using DNS-over-HTTPS (DoH)

```bash
./dnstt-client -doh https://dns.google/dns-query -pubkey-file server.pub t.example.com 127.0.0.1:7000
```

### Using DNS-over-TLS (DoT)

```bash
./dnstt-client -dot dns.google:853 -pubkey-file server.pub t.example.com 127.0.0.1:7000
```

### Inline Public Key

```bash
./dnstt-client -udp 8.8.8.8:53 -pubkey "your-hex-key-here" t.example.com 127.0.0.1:7000
```

### Custom MTU

```bash
./dnstt-client -udp 8.8.8.8:53 -pubkey-file server.pub -mtu 512 t.example.com 127.0.0.1:7000
```

## Using the Tunnel

Once connected, you have a local port that tunnels to your server.

### SSH Mode (Server configured for SSH)

```bash
# Start the tunnel
./dnstt-client -udp 8.8.8.8:53 -pubkey-file server.pub t.example.com 127.0.0.1:7000

# In another terminal, connect via SSH
ssh -p 7000 user@127.0.0.1
```

### SOCKS Mode (Server configured for SOCKS)

```bash
# Start the tunnel
./dnstt-client -udp 8.8.8.8:53 -pubkey-file server.pub t.example.com 127.0.0.1:7000

# The SOCKS proxy is available at 127.0.0.1:7000
# Configure your browser/apps to use this proxy
```

### Creating an SSH Tunnel Through SOCKS

```bash
# First, connect to SSH through the local port
ssh -D 8080 -p 7000 user@127.0.0.1

# This creates a SOCKS proxy on port 8080
```

## Running as a Service

### Linux (systemd)

Create `/etc/systemd/system/dnstt-client.service`:

```ini
[Unit]
Description=DNSTT Client
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/dnstt-client -udp 8.8.8.8:53 -pubkey-file /etc/dnstt/server.pub t.example.com 127.0.0.1:7000
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable dnstt-client
sudo systemctl start dnstt-client
```

### macOS (launchd)

Create `~/Library/LaunchAgents/com.dnstt.client.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.dnstt.client</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/dnstt-client</string>
        <string>-udp</string>
        <string>8.8.8.8:53</string>
        <string>-pubkey-file</string>
        <string>/etc/dnstt/server.pub</string>
        <string>t.example.com</string>
        <string>127.0.0.1:7000</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
```

```bash
launchctl load ~/Library/LaunchAgents/com.dnstt.client.plist
```

### Windows (Task Scheduler)

1. Open Task Scheduler
2. Create Basic Task
3. Set trigger: "At startup"
4. Action: "Start a program"
5. Program: Path to `dnstt-client.exe`
6. Arguments: `-udp 8.8.8.8:53 -pubkey-file C:\path\to\server.pub t.example.com 127.0.0.1:7000`

## Performance Tuning

### MTU Optimization

If you experience slow speeds or disconnections:

1. **Start with default** (1232)
2. **Lower if unstable** (try 1200, then 512)
3. **Higher for fast networks** (try 1400)

```bash
# Test with lower MTU
./dnstt-client -udp 8.8.8.8:53 -pubkey-file server.pub -mtu 512 t.example.com 127.0.0.1:7000
```

### DNS Resolver Selection

Try different resolvers for best performance:

1. **ISP DNS**: Usually fastest for local traffic
2. **Google (8.8.8.8)**: Reliable, well-peered
3. **Cloudflare (1.1.1.1)**: Fast, privacy-focused
4. **Local router**: May cache DNS

### Bandwidth Expectations

DNSTT is designed for bypassing restrictions, not high-speed transfers:

| Use Case | Expected Performance |
|----------|---------------------|
| SSH | Good |
| Web browsing | Moderate |
| Video streaming | Poor |
| Large downloads | Very slow |

## Verifying Your Download

All releases include checksum files. Verify before using:

### Linux/macOS

```bash
# Download checksum file
curl -LO https://github.com/ArtinDoroudi/dnstt-helper/releases/latest/download/SHA256SUMS

# Verify
sha256sum -c SHA256SUMS --ignore-missing
```

### Windows (PowerShell)

```powershell
# Get hash
Get-FileHash dnstt-client-windows-amd64.exe -Algorithm SHA256

# Compare with SHA256SUMS file contents
```

## Troubleshooting

### Connection Fails

1. **Verify DNS resolver works**:
   ```bash
   dig @8.8.8.8 google.com
   ```

2. **Check subdomain**:
   ```bash
   dig @8.8.8.8 t.example.com NS
   ```

3. **Try different DNS servers**

### Slow Performance

1. Lower MTU: `-mtu 512`
2. Try different DNS resolver
3. Check server-side MTU settings

### "Permission denied"

```bash
# Linux/macOS
chmod +x dnstt-client-*

# Or run with full path
./dnstt-client-linux-amd64 ...
```

### Port Already in Use

```bash
# Find what's using the port
lsof -i :7000  # Linux/macOS
netstat -ano | findstr :7000  # Windows

# Use a different port
./dnstt-client ... 127.0.0.1:7001
```

See [Troubleshooting Guide](troubleshooting.md) for more solutions.

## Next Steps

- [Android Setup](../android/quick-start.md)
- [Server Configuration](server-setup.md)
- [Troubleshooting](troubleshooting.md)

