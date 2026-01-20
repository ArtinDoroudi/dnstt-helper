# Android Quick Start Guide

Get connected to your DNSTT server on Android in 5 minutes.

## What You Need

1. **Android phone** with internet connection
2. **DNSTT server** already set up (run `dnstt-helper` on your server)
3. **Server info** from setup:
   - Subdomain (e.g., `t.example.com`)
   - Public key (long hex string)
   - SSH credentials (if using SSH mode)

## Quick Setup with HTTP Injector

### Step 1: Install the App

Download [HTTP Injector](https://play.google.com/store/apps/details?id=com.evozi.injector) from Google Play.

### Step 2: Configure DNS Tunnel

1. Open HTTP Injector
2. Tap **☰ Menu** → **DNS Tunnel Settings**
3. Toggle **DNS Tunnel** ON
4. Fill in:
   ```
   NS Domain:  t.example.com      ← Your subdomain
   DNS Server: 8.8.8.8            ← Or your ISP's DNS
   Public Key: [paste your key]   ← From server setup
   ```

### Step 3: Configure SSH (for SSH mode)

1. Go back → Tap **SSH Settings**
2. Fill in:
   ```
   Host:     127.0.0.1
   Port:     7000
   Username: [your SSH username]
   Password: [your SSH password]
   ```

### Step 4: Connect

1. Go back to main screen
2. Tap **START**
3. Wait for connection (may take 10-30 seconds)
4. Once connected, your internet goes through the tunnel

## Quick Setup with DarkTunnel

### Step 1: Install

Download [DarkTunnel](https://play.google.com/store/apps/details?id=net.darktunnel.app) from Google Play.

### Step 2: Configure

1. Open DarkTunnel
2. Select **DNS Tunnel** mode
3. Fill in your settings:
   ```
   NS Domain:    t.example.com
   DNS Server:   8.8.8.8:53
   Public Key:   [your key]
   Local Port:   7000
   ```

4. Enable SSH if needed:
   ```
   SSH Server:   127.0.0.1:7000
   Username:     [your username]
   Password:     [your password]
   ```

### Step 3: Connect

Tap **Connect** and wait for the tunnel to establish.

## Verify Connection

Once connected:

1. Open a browser
2. Go to [whatismyip.com](https://whatismyip.com)
3. Your IP should show your **server's IP**, not your phone's

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Won't connect | Try different DNS: `1.1.1.1` or `8.8.4.4` |
| Slow connection | Ask admin to lower MTU on server |
| Auth failed | Check SSH username/password |
| Keeps disconnecting | Enable "Keep Alive" in app settings |

## Tips

- **Save your config**: Most apps let you export settings
- **Battery**: DNS tunneling uses more battery than normal browsing
- **Wi-Fi first**: Set up on Wi-Fi before trying mobile data
- **Be patient**: First connection may take longer

## Server Modes

Your server can run in two modes:

| Mode | Use Case | Apps Needed |
|------|----------|-------------|
| **SSH** | SSH access + browsing | HTTP Injector, DarkTunnel |
| **SOCKS** | Proxy-only access | SocksLite + DNSTT plugin |

Ask your server admin which mode is configured.

## Next Steps

- Read the [detailed guide](ssh-apps-guide.md) for more options
- Check [Termius guide](termius-guide.md) for SSH client setup
- See [troubleshooting](../docs/troubleshooting.md) if you have issues

## Need Help?

Open an issue: [GitHub Issues](https://github.com/ArtinDoroudi/dnstt-helper/issues)

