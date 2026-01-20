# dnstt-helper

<!-- **Languages:** [English](README.md) | [فارسی](README-fa.md) -->

A comprehensive DNS tunnel deployment and client solution with enhanced features, performance optimizations, and cross-platform support.


## Quick Start

### Server Setup

```bash
bash <(curl -Ls https://raw.githubusercontent.com/ArtinDoroudi/dnstt-helper/main/server/dnstt-helper.sh)
```

### Client Download

Download the appropriate client for your platform from [Releases](https://github.com/ArtinDoroudi/dnstt-helper/releases):

| Platform | Binary |
|----------|--------|
| Windows x64 | `dnstt-client-windows-amd64.exe` |
| macOS Intel | `dnstt-client-darwin-amd64` |
| macOS Apple Silicon | `dnstt-client-darwin-arm64` |
| Linux x64 | `dnstt-client-linux-amd64` |
| Linux ARM64 | `dnstt-client-linux-arm64` |

### Basic Usage

```bash
# Connect to your DNSTT server
./dnstt-client -udp DNS_SERVER:53 -pubkey-file server.pub t.example.com 127.0.0.1:7000
```

## Features

### Server Features

- Multi-distribution support (Fedora, Rocky, CentOS, Debian, Ubuntu)
- Custom DNS resolver selection (DoH/DoT support)
- Advanced MTU tuning options
- Configuration profiles (save/load different configs)
- QR code generation for public keys
- Performance monitoring and statistics
- Backup/restore configuration
- Client configuration file generation

### Client Features

- Cross-platform support (Windows, macOS, Linux)
- Automatic MTU detection and tuning
- Multiple DNS resolver support with failover
- Latency-based resolver selection
- JSON/YAML configuration file support
- Auto-detection of DNS servers

### Android Support

- Termius configuration guide
- HTTP Injector / HTTP Custom guides
- Quick start tutorials

## DNS Domain Setup

Before deploying, configure your domain's DNS records:

### Example Configuration

- **Your domain**: `example.com`
- **Server IPv4**: `203.0.113.2`
- **Tunnel subdomain**: `t.example.com`
- **Server hostname**: `tns.example.com`

### Required DNS Records

| Type | Name | Points to |
|------|------|-----------|
| A | `tns.example.com` | `203.0.113.2` |
| AAAA | `tns.example.com` | `2001:db8::2` (optional) |
| NS | `t.example.com` | `tns.example.com` |

**Important**: Wait for DNS propagation (up to 24 hours) before testing.

## Documentation

- [Server Setup Guide](docs/server-setup.md)
- [Client Usage Guide](docs/client-usage.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Android Guides](android/)
  - [Termius Guide](android/termius-guide.md)
  - [SSH Apps Guide](android/ssh-apps-guide.md)
  - [Quick Start](android/quick-start.md)

## Project Structure

```
dnstt-helper/
├── server/              # Server deployment scripts
├── clients/             # Client source and builds
├── android/             # Android configuration guides
├── docs/                # Documentation
├── scripts/             # Build and release scripts
└── .github/workflows/   # CI/CD automation
```

## Building from Source

### Prerequisites

- Go 1.21 or later
- Make (optional)

### Build Clients

```bash
cd clients/builds
./build.sh
```

This will create binaries for all supported platforms in the `dist/` directory.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Acknowledgments

- [dnstt](https://www.bamsoftware.com/software/dnstt/) by David Fifield
- [dnstt-deploy](https://github.com/bugfloyd/dnstt-deploy) for inspiration
- [Dante SOCKS server](https://www.inet.no/dante/) for SOCKS proxy functionality

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

- **Issues**: [GitHub Issues](https://github.com/ArtinDoroudi/dnstt-helper/issues)
- **Discussions**: [GitHub Discussions](https://github.com/ArtinDoroudi/dnstt-helper/discussions)

---

**Made for privacy and security**
