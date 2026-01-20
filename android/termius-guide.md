# Termius Configuration Guide for DNSTT

This guide explains how to connect to your DNSTT server using Termius on Android.

## Prerequisites

1. **DNSTT server** deployed with SSH mode enabled
2. **Termius app** installed on your Android device
3. **Server public key** from your DNSTT server setup
4. **SSH credentials** for your server

## Important Note

Termius connects via SSH, so your DNSTT server must be configured in **SSH mode** (not SOCKS mode). When setting up your server with `dnstt-helper`, choose option 2 (SSH mode).

## Step-by-Step Setup

### Step 1: Get Your Server Information

From your server setup, you'll need:

- **Nameserver subdomain**: e.g., `t.example.com`
- **Public key**: The key generated during server setup
- **SSH username**: Your server's SSH username
- **SSH password or key**: Authentication credentials

### Step 2: Install Required Apps

You'll need a DNS tunneling app that works with Termius. Options include:

1. **HTTP Injector** (recommended for DNS tunneling)
2. **HTTP Custom**
3. **DarkTunnel**

### Step 3: Configure DNS Tunnel

#### Using HTTP Injector

1. Open HTTP Injector
2. Go to **SSH** settings
3. Configure:
   - **SSH Host**: `127.0.0.1`
   - **SSH Port**: `7000` (or your local port)
   - **Username**: Your SSH username
   - **Password**: Your SSH password

4. Go to **DNS Tunnel** settings
5. Configure:
   - **Enable DNS Tunnel**: ON
   - **DNS Server**: Your ISP's DNS or `8.8.8.8`
   - **NS Domain**: `t.example.com` (your subdomain)
   - **Public Key**: Paste your server's public key

6. Tap **Connect**

### Step 4: Connect Termius

Once the DNS tunnel is active:

1. Open Termius
2. Add a new host:
   - **Alias**: Any name you prefer
   - **Hostname**: `127.0.0.1`
   - **Port**: `7000`
   - **Username**: Your SSH username
   - **Password**: Your SSH password

3. Tap the host to connect

## Alternative: Direct SSH Apps

Some SSH apps have built-in DNS tunnel support:

### HTTP Injector (Full Setup)

```
Settings:
├── SSH
│   ├── Host: 127.0.0.1
│   ├── Port: 7000
│   ├── Username: <your-username>
│   └── Password: <your-password>
├── DNS Tunnel
│   ├── Enabled: Yes
│   ├── DNS Server: 8.8.8.8
│   ├── NS Domain: t.example.com
│   └── Public Key: <your-public-key>
└── Payload Generator
    └── (Leave empty for DNS tunnel)
```

### DarkTunnel

```
Settings:
├── Server Type: DNS Tunnel
├── NS Domain: t.example.com
├── DNS Server: 8.8.8.8:53
├── Public Key: <your-public-key>
└── Local Port: 7000

SSH Settings:
├── Enable SSH: Yes
├── SSH Server: 127.0.0.1:7000
├── Username: <your-username>
└── Password: <your-password>
```

## Troubleshooting

### Connection Fails

1. **Check DNS tunnel status**: Make sure the tunnel is established first
2. **Verify public key**: Ensure you're using the correct key
3. **Check subdomain**: Confirm your NS subdomain is correct
4. **Try different DNS**: Use `8.8.8.8`, `1.1.1.1`, or your ISP's DNS

### Slow Connection

1. Lower the MTU on your server:
   - Run `dnstt-helper` on server
   - Choose "Install/Reconfigure"
   - Set MTU to `1200` or `512`

2. Try a different DNS server closer to your location

### Authentication Failed

1. Verify SSH credentials on your server
2. Check if SSH is running: `systemctl status sshd`
3. Ensure DNSTT server is in SSH mode

### DNS Tunnel Not Working

1. Check server status: `systemctl status dnstt-server`
2. Verify DNS records are properly configured
3. Wait for DNS propagation (up to 24 hours)
4. Test from a different network

## Tips for Better Performance

1. **Use your ISP's DNS**: Usually faster than public DNS
2. **Adjust MTU**: Start with 1232, lower if unstable
3. **Keep screen on**: Some devices throttle background connections
4. **Use Wi-Fi**: More stable than mobile data for initial setup

## Security Considerations

1. Always use strong SSH passwords or key-based authentication
2. Consider changing the default SSH port on your server
3. Keep your server and apps updated
4. Don't share your public key publicly (though it's safe, best practice)

## Need Help?

- Check the [Troubleshooting Guide](../docs/troubleshooting.md)
- Open an issue on [GitHub](https://github.com/ArtinDoroudi/dnstt-helper/issues)

