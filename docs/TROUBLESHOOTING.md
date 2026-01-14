# Troubleshooting

Common issues and solutions.

## Connection Issues

### "Connection refused" on localhost:8081

**Cause:** Tunnel not running or relay not started.

**Fix:**
1. Check tunnel is running:
   ```bash
   ps aux | grep ssh | grep 8081
   ```
2. Check relay is running (on relay server):
   ```bash
   curl http://localhost:8081/health
   ```
3. Restart tunnel from laptop:
   ```bash
   ssh -R 8081:relay-server:8081 workvm -N &
   ```

### "Relay not responding after 10 seconds"

**Cause:** Tunnel exists but relay not reachable.

**Fix:**
1. Test relay directly on server:
   ```bash
   ssh relay-server 'curl http://localhost:8081/health'
   ```
2. Check firewall allows port 8081:
   ```bash
   ssh relay-server 'ss -tlnp | grep 8081'
   ```

### "gzip: stdin: unexpected end of file"

**Cause:** Bundle download interrupted or timed out.

**Fix:**
1. Test bundle endpoint directly:
   ```bash
   curl -# http://localhost:8081/bundle.tar.gz -o /tmp/test.tar.gz
   ls -la /tmp/test.tar.gz
   tar -tzf /tmp/test.tar.gz | head
   ```
2. Check relay logs for errors:
   ```bash
   docker logs sovereign-relay
   ```

## Port Conflicts

### "Port 8081 already in use"

**Cause:** Previous relay or tunnel still running.

**Fix:**
```bash
# Find what's using the port
ss -tlnp | grep 8081
# or
lsof -i :8081

# Stop existing relay
docker stop sovereign-relay

# Kill orphan SSH tunnels
pkill -f 'ssh.*8081'
```

### "Bind for 0.0.0.0:8081 failed"

**Cause:** Docker container can't bind to port.

**Fix:**
```bash
docker compose -f docker-compose.relay.yml down
docker compose -f docker-compose.relay.yml up -d
```

## SSH Issues

### "Permission denied (publickey)"

**Cause:** SSH key not accepted.

**Fix:**
1. Check key is loaded:
   ```bash
   ssh-add -l
   ```
2. Add key if missing:
   ```bash
   ssh-add ~/.ssh/id_rsa
   ```
3. Verify server has your public key:
   ```bash
   ssh-copy-id user@relay-server
   ```

### Tunnel dies after idle

**Cause:** SSH connection times out.

**Fix:** Use autossh or add keepalive:
```bash
# With autossh
autossh -M 0 -o "ServerAliveInterval 30" -R 8081:relay:8081 workvm -N

# Or add to ~/.ssh/config
Host *
    ServerAliveInterval 30
    ServerAliveCountMax 3
```

## Docker Issues

### Container can't access config.json

**Cause:** Volume mount path wrong.

**Fix:**
```bash
# Verify config.json exists
ls -la config.json

# Check volume mount in docker-compose.relay.yml
# Should be: ./config.json:/app/config.json:ro
```

### "No such file: config.json"

**Cause:** Running from wrong directory.

**Fix:**
```bash
cd /path/to/sovereign-agent
docker compose -f docker-compose.relay.yml up -d
```

### Container keeps restarting

**Cause:** Startup error.

**Fix:**
```bash
# Check logs
docker logs sovereign-relay

# Common issues:
# - Invalid JSON in config.json
# - Missing API key
# - Port conflict inside container
```

## Validation Errors

### "Missing required field: .openrouter_api_key"

**Cause:** API key not set (and not in relay client mode).

**Fix for server:**
```bash
# Add API key to config.json
jq '.openrouter_api_key = "sk-or-v1-..."' config.json > tmp.json && mv tmp.json config.json
```

**Fix for client:** Ensure relay mode is configured:
```json
{
  "relay": {
    "enabled": true,
    "mode": "client"
  }
}
```

### "Please replace the placeholder API key"

**Cause:** Using example key value.

**Fix:**
```bash
# Get your key from https://openrouter.ai/keys
# Replace in config.json
```

## Container Networking

### Client in Docker can't reach localhost:8081

**Cause:** Container network isolation.

**Fix option 1:** Use host networking:
```bash
docker run --network host ...
```

**Fix option 2:** Create tunnel from container to host:
```bash
# Find host IP
ip route | grep default | awk '{print $3}'

# Create tunnel (from inside container)
ssh -L 8081:127.0.0.1:8081 user@<host-ip> -N &
```

## OpenCode Issues

### "opencode: command not found"

**Cause:** OpenCode not in PATH.

**Fix:**
```bash
# Add to PATH
export PATH="$HOME/.local/bin:$PATH"

# Or source the profile
source ~/.bashrc
```

### OpenCode can't connect to API

**Cause:** Relay not configured in OpenCode.

**Fix:** Check `~/.config/opencode/config.json`:
```json
{
  "provider": {
    "openrouter": {
      "baseURL": "http://localhost:8081/api/v1"
    }
  }
}
```

## Getting Help

1. Check relay logs: `docker logs sovereign-relay`
2. Check OpenCode logs: `~/.local/share/opencode/logs/`
3. Test endpoints manually:
   ```bash
   curl http://localhost:8081/health
   curl http://localhost:8081/stats
   ```
4. Open an issue: https://github.com/lachlan-jones5/sovereign-agent/issues
