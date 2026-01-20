# DNSTT Helper - Clients

Cross-platform CLI clients with performance optimizations.

## Download

Download pre-built binaries from [Releases](https://github.com/ArtinDoroudi/dnstt-helper/releases).

### Available Platforms

| Platform | Architecture | Binary |
|----------|--------------|--------|
| Windows | x64 | `dnstt-client-windows-amd64.exe` |
| Windows | x86 | `dnstt-client-windows-386.exe` |
| macOS | Intel | `dnstt-client-darwin-amd64` |
| macOS | Apple Silicon | `dnstt-client-darwin-arm64` |
| Linux | x64 | `dnstt-client-linux-amd64` |
| Linux | ARM64 | `dnstt-client-linux-arm64` |
| Linux | ARM | `dnstt-client-linux-arm` |
| Linux | x86 | `dnstt-client-linux-386` |

## Usage

### Basic Connection

```bash
# Linux/macOS
chmod +x dnstt-client-*
./dnstt-client -udp DNS_SERVER:53 -pubkey-file server.pub t.example.com 127.0.0.1:7000

# Windows
dnstt-client-windows-amd64.exe -udp DNS_SERVER:53 -pubkey-file server.pub t.example.com 127.0.0.1:7000
```

### With Configuration File

```bash
./dnstt-client -config config.json
```

### Command-Line Options

```
Usage: dnstt-client [options] <domain> <local-addr>

Options:
  -udp <addr>           UDP DNS resolver address (e.g., 8.8.8.8:53)
  -doh <url>            DNS-over-HTTPS resolver URL
  -dot <addr>           DNS-over-TLS resolver address
  -pubkey <key>         Server public key (hex string)
  -pubkey-file <file>   Server public key file
  -mtu <size>           MTU size (default: auto-detect)
  -config <file>        Configuration file (JSON/YAML)
  -resolvers <file>     Multiple resolvers configuration
  -verbose              Enable verbose logging
  -version              Show version information
```

## Configuration File

### JSON Format

```json
{
  "domain": "t.example.com",
  "local_addr": "127.0.0.1:7000",
  "pubkey_file": "server.pub",
  "resolvers": [
    {"type": "udp", "addr": "8.8.8.8:53"},
    {"type": "udp", "addr": "1.1.1.1:53"},
    {"type": "doh", "url": "https://dns.google/dns-query"}
  ],
  "mtu": "auto",
  "failover": true,
  "retry_count": 3,
  "timeout": 10
}
```

### YAML Format

```yaml
domain: t.example.com
local_addr: 127.0.0.1:7000
pubkey_file: server.pub
resolvers:
  - type: udp
    addr: 8.8.8.8:53
  - type: udp
    addr: 1.1.1.1:53
  - type: doh
    url: https://dns.google/dns-query
mtu: auto
failover: true
retry_count: 3
timeout: 10
```

## Finding Your DNS Server

### Linux

```bash
systemd-resolve --status | grep "DNS Servers"
# or
cat /etc/resolv.conf
```

### Windows

```cmd
ipconfig /all | findstr /C:"DNS Servers"
```

### macOS

```bash
scutil --dns | grep nameserver
```

### Common DNS Servers

- Router/Modem: Usually `192.168.1.1:53`
- Google DNS: `8.8.8.8:53`, `8.8.4.4:53`
- Cloudflare: `1.1.1.1:53`, `1.0.0.1:53`

## Performance Features

### Automatic MTU Detection

The client automatically detects optimal MTU based on:
- Network conditions
- DNS resolver capabilities
- Connection stability

### Multi-Resolver Failover

Configure multiple resolvers for reliability:

```json
{
  "resolvers": [
    {"type": "udp", "addr": "8.8.8.8:53", "priority": 1},
    {"type": "udp", "addr": "1.1.1.1:53", "priority": 2},
    {"type": "doh", "url": "https://dns.google/dns-query", "priority": 3}
  ],
  "failover": true
}
```

### Latency-Based Selection

Enable automatic resolver selection based on latency:

```json
{
  "resolver_selection": "latency",
  "latency_threshold_ms": 100
}
```

## Building from Source

### Prerequisites

- Go 1.21 or later

### Build

```bash
cd builds
./build.sh
```

### Build Specific Platform

```bash
GOOS=windows GOARCH=amd64 go build -o dnstt-client-windows-amd64.exe ../cli/
```

## Verifying Downloads

All releases include checksum files. Verify your download:

```bash
# Linux/macOS
sha256sum -c SHA256SUMS

# Windows (PowerShell)
Get-FileHash dnstt-client-windows-amd64.exe | Format-List
```

## Troubleshooting

See [Troubleshooting Guide](../docs/troubleshooting.md) for common issues and solutions.

