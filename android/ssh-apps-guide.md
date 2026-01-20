# Android SSH Apps Guide for DNSTT

This guide covers various Android apps that can connect to your DNSTT server.

## Overview

To use DNSTT on Android, you need an app that supports DNS tunneling. The general process is:

1. Configure the DNS tunnel with your server's details
2. The app creates a local port that tunnels through DNS
3. You connect to that local port for SSH/SOCKS access

## Supported Apps

### 1. HTTP Injector

**Download**: [Google Play](https://play.google.com/store/apps/details?id=com.evozi.injector)

**Features**:
- DNS Tunnel support
- SSH tunnel
- Payload customization
- SSL/TLS support

**Configuration**:

```
┌─────────────────────────────────────┐
│         HTTP Injector Setup         │
├─────────────────────────────────────┤
│ DNS TUNNEL                          │
│ ├── Enable: ON                      │
│ ├── DNS Server: 8.8.8.8             │
│ ├── NS Domain: t.example.com        │
│ └── Public Key: [your-key]          │
│                                     │
│ SSH                                 │
│ ├── Host: 127.0.0.1                 │
│ ├── Port: 7000                      │
│ ├── Username: [ssh-user]            │
│ └── Password: [ssh-pass]            │
│                                     │
│ PROXY                               │
│ └── Local Port: 8080                │
└─────────────────────────────────────┘
```

**Step-by-step**:

1. Open HTTP Injector
2. Tap the menu icon → Settings → DNS Tunnel
3. Enable DNS Tunnel
4. Enter your settings:
   - NS Domain: `t.example.com`
   - DNS Server: `8.8.8.8` (or your ISP's DNS)
   - Public Key: Paste from server setup
5. Go back and tap SSH Settings
6. Configure SSH:
   - Host: `127.0.0.1`
   - Port: `7000`
   - Username/Password: Your SSH credentials
7. Tap START to connect

---

### 2. HTTP Custom

**Download**: [Google Play](https://play.google.com/store/apps/details?id=xyz.easypro.httpcustom)

**Features**:
- Similar to HTTP Injector
- DNS over HTTPS support
- Custom payloads

**Configuration**:

```
┌─────────────────────────────────────┐
│         HTTP Custom Setup           │
├─────────────────────────────────────┤
│ CONNECTION METHOD                   │
│ └── DNS Tunnel                      │
│                                     │
│ DNS TUNNEL SETTINGS                 │
│ ├── NS Host: t.example.com          │
│ ├── DNS: 8.8.8.8                    │
│ └── Key: [your-public-key]          │
│                                     │
│ SSH SETTINGS                        │
│ ├── Server: 127.0.0.1               │
│ ├── Port: 7000                      │
│ ├── User: [username]                │
│ └── Pass: [password]                │
└─────────────────────────────────────┘
```

---

### 3. DarkTunnel

**Download**: [Google Play](https://play.google.com/store/apps/details?id=net.darktunnel.app)

**Features**:
- Native DNSTT support
- Simple interface
- Auto-reconnect

**Configuration**:

```
┌─────────────────────────────────────┐
│          DarkTunnel Setup           │
├─────────────────────────────────────┤
│ TUNNEL TYPE: DNS                    │
│                                     │
│ DNS SETTINGS                        │
│ ├── NS Domain: t.example.com        │
│ ├── DNS Server: 8.8.8.8:53          │
│ └── Public Key: [your-key]          │
│                                     │
│ LOCAL SETTINGS                      │
│ └── Port: 7000                      │
│                                     │
│ SSH (Optional)                      │
│ ├── Enable: Yes                     │
│ ├── Server: 127.0.0.1:7000          │
│ ├── Username: [user]                │
│ └── Password: [pass]                │
└─────────────────────────────────────┘
```

---

### 4. SocksLite with DNSTT Plugin

**Download**: 
- SocksLite: [APKPure](https://apkpure.com/sockslite/com.sockslite.app)
- DNSTT Plugin: [APKPure](https://apkpure.com/sockslite-dnstt-plugin/com.kiritoprojets.dnsttplugin)

**Features**:
- Native DNSTT plugin
- Works with SOCKS mode
- VPN integration

---

## Quick Comparison

| App | DNS Tunnel | SSH | SOCKS | Ease of Use |
|-----|-----------|-----|-------|-------------|
| HTTP Injector | Yes | Yes | Via SSH | Medium |
| HTTP Custom | Yes | Yes | Via SSH | Medium |
| DarkTunnel | Yes | Yes | No | Easy |
| SocksLite + Plugin | Yes | No | Yes | Medium |

## Choosing the Right App

- **For SSH access**: HTTP Injector or DarkTunnel
- **For SOCKS proxy**: SocksLite with DNSTT plugin
- **For simplicity**: DarkTunnel
- **For customization**: HTTP Injector

## General Configuration Values

Replace these placeholders with your actual values:

| Setting | Example Value | Description |
|---------|--------------|-------------|
| NS Domain | `t.example.com` | Your tunnel subdomain |
| DNS Server | `8.8.8.8` | DNS resolver to use |
| Public Key | `abc123...` | From server setup |
| Local Port | `7000` | Port for local tunnel |
| SSH User | `root` | Your SSH username |
| SSH Pass | `password` | Your SSH password |

## Finding Your DNS Server

The DNS server is used to reach your DNSTT server. Options:

1. **ISP DNS** (usually fastest):
   - Check your router settings
   - Or use: Settings → WiFi → Your Network → DNS

2. **Public DNS**:
   - Google: `8.8.8.8` or `8.8.4.4`
   - Cloudflare: `1.1.1.1` or `1.0.0.1`
   - OpenDNS: `208.67.222.222`

3. **Router IP** (if your router handles DNS):
   - Usually `192.168.1.1` or `192.168.0.1`

## Troubleshooting

### "Connection timeout"

- Check if DNS tunnel connected first
- Try a different DNS server
- Verify your NS subdomain is correct

### "Authentication failed"

- Check SSH username/password
- Ensure server is in SSH mode (not SOCKS)
- Verify SSH is running on server

### "DNS tunnel failed"

- Wait for DNS propagation (up to 24h)
- Check server is running: `systemctl status dnstt-server`
- Try different DNS servers

### Slow speeds

- Lower MTU on server (try 1200 or 512)
- Use your ISP's DNS instead of public DNS
- Check server load and bandwidth

## Using the Connection

Once connected, you can:

1. **Browse the web** through the app's proxy
2. **Use other apps** that support SOCKS/HTTP proxy
3. **SSH** to your server through Termius or JuiceSSH

## Security Tips

1. Use strong, unique SSH passwords
2. Consider SSH key authentication
3. Keep apps updated
4. Don't share configuration files with keys

## Need Help?

- [Troubleshooting Guide](../docs/troubleshooting.md)
- [GitHub Issues](https://github.com/ArtinDoroudi/dnstt-helper/issues)

