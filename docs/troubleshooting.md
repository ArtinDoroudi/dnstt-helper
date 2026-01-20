# Troubleshooting Guide

Solutions for common issues with dnstt-helper.

## Quick Diagnostics

### Server-Side Checks

```bash
# 1. Is the service running?
systemctl status dnstt-server

# 2. Is it listening on the correct port?
ss -ulnp | grep 5300

# 3. Are iptables rules in place?
iptables -t nat -L PREROUTING -n -v | grep 5300

# 4. Can DNS reach the server?
tcpdump -i any port 53 -n
```

### Client-Side Checks

```bash
# 1. Can you reach any DNS server?
dig @8.8.8.8 google.com

# 2. Can DNS queries reach your server?
dig @8.8.8.8 test.t.example.com

# 3. Is the local port available?
ss -tlnp | grep 7000  # Linux
netstat -an | findstr 7000  # Windows
```

## Server Issues

### Service Won't Start

**Symptoms**: `systemctl start dnstt-server` fails

**Check logs**:
```bash
journalctl -u dnstt-server -n 50 --no-pager
```

**Common causes**:

1. **Binary not found**:
   ```bash
   ls -la /usr/local/bin/dnstt-server
   # If missing, re-run installation
   dnstt-helper
   # Choose option 1 to reinstall
   ```

2. **Key file permissions**:
   ```bash
   ls -la /etc/dnstt/*.key
   # Should be owned by dnstt user, mode 600
   chown dnstt:dnstt /etc/dnstt/*.key
   chmod 600 /etc/dnstt/*.key
   ```

3. **Port already in use**:
   ```bash
   ss -ulnp | grep 5300
   # Kill conflicting process or change port
   ```

4. **User doesn't exist**:
   ```bash
   id dnstt
   # If missing, create it
   useradd -r -s /bin/false dnstt
   ```

### DNS Queries Not Reaching Server

**Symptoms**: Client can't connect, no activity in server logs

**Check iptables**:
```bash
# View NAT rules
iptables -t nat -L PREROUTING -v -n

# Should see rule like:
# REDIRECT udp -- 0.0.0.0/0 0.0.0.0/0 udp dpt:53 redir ports 5300
```

**If rules are missing**:
```bash
# Re-configure
dnstt-helper
# Choose option 1 to reconfigure
```

**Check firewall**:
```bash
# UFW
ufw status

# Firewalld
firewall-cmd --list-all

# Ensure UDP 53 and 5300 are allowed
```

### DNS Records Not Propagated

**Symptoms**: `dig` queries return NXDOMAIN or wrong server

**Verify records**:
```bash
# Check NS record
dig +short NS t.example.com

# Should return: tns.example.com

# Check A record for NS
dig +short tns.example.com

# Should return your server IP
```

**If records are wrong**:
1. Check your DNS provider's control panel
2. Verify NS record points to your hostname
3. Verify A record points to server IP
4. Wait up to 24-48 hours for propagation

**Force DNS refresh** (at client):
```bash
# Linux (systemd-resolved)
resolvectl flush-caches

# macOS
sudo dscacheutil -flushcache

# Windows
ipconfig /flushdns
```

### High CPU or Memory Usage

**Check resource usage**:
```bash
top -p $(pgrep dnstt-server)
```

**Common causes**:
1. Too many concurrent connections
2. MTU mismatch causing retransmissions
3. Attack/scan traffic

**Solutions**:
1. Monitor with `journalctl -u dnstt-server -f`
2. Adjust MTU settings
3. Add rate limiting in firewall

## Client Issues

### Connection Refused

**Symptoms**: "connection refused" when connecting to local port

**Is the client running?**:
```bash
ps aux | grep dnstt-client
```

**Check if port is listening**:
```bash
ss -tlnp | grep 7000
```

**Is another process using the port?**:
```bash
lsof -i :7000
# If so, use a different port
./dnstt-client ... 127.0.0.1:7001
```

### DNS Resolution Fails

**Symptoms**: Client starts but can't establish tunnel

**Test DNS resolver**:
```bash
dig @8.8.8.8 google.com
```

**Test your domain**:
```bash
dig @8.8.8.8 t.example.com NS
```

**Try different resolvers**:
```bash
# Google
./dnstt-client -udp 8.8.8.8:53 ...

# Cloudflare
./dnstt-client -udp 1.1.1.1:53 ...

# OpenDNS
./dnstt-client -udp 208.67.222.222:53 ...
```

### Slow Connection

**Symptoms**: Connection works but is very slow

**Causes and solutions**:

1. **MTU too high**:
   ```bash
   # Try lower MTU
   ./dnstt-client -mtu 512 ...
   ```

2. **DNS server latency**:
   ```bash
   # Test DNS latency
   time dig @8.8.8.8 google.com
   
   # Try a closer DNS server
   ```

3. **Server MTU mismatch**:
   ```bash
   # On server, reconfigure with lower MTU
   dnstt-helper
   # Set MTU to match client
   ```

### Connection Drops Frequently

**Symptoms**: Tunnel disconnects after some time

**Causes**:

1. **Network timeouts**: Some networks drop idle UDP connections
   - Keep traffic active
   - Use a keep-alive mechanism

2. **DNS resolver issues**: Resolver may be rate-limiting
   - Try different resolver
   - Use DoH instead of UDP

3. **Server overloaded**: Check server resources

### "Invalid public key" Error

**Symptoms**: Client reports key error

**Solutions**:

1. **Verify key file exists and is readable**:
   ```bash
   cat server.pub
   ```

2. **Key format**: Should be a single line of hex characters
   ```
   abc123def456...
   ```

3. **No extra whitespace**: Remove any trailing newlines or spaces

4. **Get fresh key from server**:
   ```bash
   # On server
   cat /etc/dnstt/*_server.pub
   ```

## Android Issues

### DNS Tunnel Won't Connect

1. **Check DNS settings**: Use 8.8.8.8 instead of local DNS
2. **Verify NS domain**: Must match server exactly
3. **Check public key**: Copy carefully, no extra spaces
4. **Try different app**: HTTP Injector, DarkTunnel, etc.

### SSH Connection Fails Through Tunnel

1. **Verify server is in SSH mode** (not SOCKS)
2. **Check SSH credentials**: Username/password correct
3. **Local port matches**: Both apps use same port (e.g., 7000)

### Slow on Mobile Data

1. Lower MTU to 512
2. Use WiFi for better performance
3. Try different DNS server
4. Check mobile data isn't being throttled

## Advanced Diagnostics

### Capture Traffic

**Server-side**:
```bash
# Capture DNS traffic
tcpdump -i any port 53 -w /tmp/dns.pcap

# Analyze
tcpdump -r /tmp/dns.pcap -n
```

**Client-side**:
```bash
# Monitor DNS queries
tcpdump -i any port 53 -n
```

### Verbose Logging

**Enable debug output** (if supported):
```bash
./dnstt-client -v ...  # Check if -v flag is available
```

### Test with curl

Once tunnel is established:
```bash
# SSH mode
ssh -p 7000 user@127.0.0.1

# SOCKS mode
curl --socks5 127.0.0.1:7000 http://httpbin.org/ip
```

## Error Messages

### "FORMERR: requester payload size X is too small"

**Cause**: MTU on client is higher than what DNS resolver supports

**Solution**: Lower MTU to the value shown in the error
```bash
./dnstt-client -mtu 512 ...
```

### "dial udp: network is unreachable"

**Cause**: No network connectivity

**Solution**: Check internet connection, try different DNS server

### "read: connection refused"

**Cause**: Target service (SSH/SOCKS) isn't running on server

**Solution**:
- SSH mode: Ensure SSH is running (`systemctl status sshd`)
- SOCKS mode: Ensure Dante is running (`systemctl status danted`)

### "context deadline exceeded"

**Cause**: DNS queries timing out

**Solution**:
1. Check DNS server is reachable
2. Try different DNS resolver
3. Check server is running

## Getting Help

If you can't resolve your issue:

1. **Gather information**:
   - Server: `dnstt-helper` → option 5 (show config)
   - Server: `journalctl -u dnstt-server -n 100`
   - Client: Full command you're running
   - Client: Any error messages

2. **Check existing issues**:
   [GitHub Issues](https://github.com/ArtinDoroudi/dnstt-helper/issues)

3. **Open new issue** with gathered information

## Common Fixes Summary

| Issue | Quick Fix |
|-------|-----------|
| Service won't start | Check logs, verify permissions |
| No DNS connection | Check iptables, verify DNS records |
| Slow connection | Lower MTU (512) |
| Frequent disconnects | Try DoH instead of UDP |
| Android won't connect | Use 8.8.8.8, check key format |
| SSH fails | Verify server is in SSH mode |
| SOCKS fails | Verify server is in SOCKS mode |

