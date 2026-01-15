# Troubleshooting

Common issues and solutions for Sovereign Agent with GitHub Copilot.

## Authentication Issues

### "Not authenticated" or 401 errors

**Cause:** OAuth token not set or expired.

**Fix:**
1. Check authentication status:
   ```bash
   curl http://localhost:8080/auth/status
   ```
2. If not authenticated, start device code flow:
   ```bash
   curl -X POST http://localhost:8080/auth/device
   ```
3. Or visit in browser:
   ```
   http://localhost:8080/auth/device
   ```
4. Follow the GitHub authorization flow

### "Authorization pending" during polling

**Cause:** User hasn't completed GitHub authorization yet.

**Fix:**
1. Go to `https://github.com/login/device`
2. Enter the user code shown on the auth page
3. Authorize "GitHub Copilot"
4. Wait for the relay to detect authorization (polls every 5 seconds)

### Device code expired

**Cause:** Took too long to authorize (15-minute timeout).

**Fix:**
1. Start a new device code flow:
   ```bash
   curl -X POST http://localhost:8080/auth/device
   ```
2. Complete authorization within 15 minutes

### "Copilot access denied" or 403 errors

**Cause:** GitHub account doesn't have Copilot subscription.

**Fix:**
1. Verify Copilot subscription at https://github.com/settings/copilot
2. Subscribe to Copilot Pro ($10/month) or Pro+ ($39/month)
3. Re-authenticate after subscription is active

## Connection Issues

### "Connection refused" on localhost:8080

**Cause:** Tunnel not running or relay not started.

**Fix:**
1. Check tunnel is running:
   ```bash
   ps aux | grep ssh | grep 8080
   ```
2. Check relay is running (on relay server):
   ```bash
   curl http://localhost:8080/health
   ```
3. Restart tunnel from laptop:
   ```bash
   ssh -R 8080:relay-server:8080 devvm -N &
   ```

### "Relay not responding after 10 seconds"

**Cause:** Tunnel exists but relay not reachable.

**Fix:**
1. Test relay directly on server:
   ```bash
   ssh relay-server 'curl http://localhost:8080/health'
   ```
2. Check firewall allows port 8080:
   ```bash
   ssh relay-server 'ss -tlnp | grep 8080'
   ```

### "gzip: stdin: unexpected end of file"

**Cause:** Bundle download interrupted or timed out.

**Fix:**
1. Test bundle endpoint directly:
   ```bash
   curl -# http://localhost:8080/bundle.tar.gz -o /tmp/test.tar.gz
   ls -la /tmp/test.tar.gz
   tar -tzf /tmp/test.tar.gz | head
   ```
2. Check relay logs for errors:
   ```bash
   docker logs sovereign-relay
   ```

## Port Conflicts

### "Port 8080 already in use"

**Cause:** Previous relay or tunnel still running.

**Fix:**
```bash
# Find what's using the port
ss -tlnp | grep 8080
# or
lsof -i :8080

# Stop existing relay
docker stop sovereign-relay

# Kill orphan SSH tunnels
pkill -f 'ssh.*8080'
```

### "Bind for 0.0.0.0:8080 failed"

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
autossh -M 0 -o "ServerAliveInterval 30" -R 8080:relay:8080 devvm -N

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
# Should be: ./config.json:/app/config.json:rw
# Note: :rw (not :ro) so OAuth token can be saved
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
# - Port conflict inside container
```

## API Issues

### "Model not found" errors

**Cause:** Using deprecated or unsupported model.

**Fix:** Check [Models](MODELS.md) for supported models. Deprecated models:
- `claude-sonnet-4` → Use `claude-sonnet-4.5`
- `claude-opus-4` → Use `claude-opus-4.5`
- `gemini-2.5-pro` → Use `gemini-3-pro-preview`

### "Rate limited" or 429 errors

**Cause:** Exceeded premium request quota.

**Fix:**
1. Check usage:
   ```bash
   curl http://localhost:8080/stats | jq '.premiumRequests'
   ```
2. Wait for quota reset (monthly)
3. Or upgrade to Pro+ for more requests
4. Use free models (gpt-5-mini, gpt-4.1, gpt-4o) for non-critical tasks

### Slow responses

**Cause:** Network latency or model processing time.

**Fix:**
1. Check relay health:
   ```bash
   time curl http://localhost:8080/health
   ```
2. If relay is slow, check server resources
3. If API is slow, this is normal for complex prompts
4. Consider using faster models (gpt-5-mini, claude-haiku-4.5)

## Container Networking

### Client in Docker can't reach localhost:8080

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
ssh -L 8080:127.0.0.1:8080 user@<host-ip> -N &
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

**Fix:** Re-run setup from relay:
```bash
curl -fsSL http://localhost:8080/setup | bash
```

This regenerates `~/.config/opencode/config.json` with correct settings.

### Config file issues

**Cause:** Corrupted or outdated config.

**Fix:**
```bash
# Backup and regenerate
mv ~/.config/opencode/config.json ~/.config/opencode/config.json.bak
curl -fsSL http://localhost:8080/setup | bash
```

## Debugging

### Enable debug logging

```bash
# Relay
LOG_LEVEL=debug bun run main.ts

# Or in Docker
docker compose -f docker-compose.relay.yml down
LOG_LEVEL=debug docker compose -f docker-compose.relay.yml up
```

### Check relay logs

```bash
# Docker
docker logs -f sovereign-relay

# Native
tail -f /tmp/sovereign-relay.log
```

### Test API manually

```bash
# Test a simple completion
curl http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-5-mini",
    "messages": [{"role": "user", "content": "Hello"}]
  }'
```

## Getting Help

1. Check relay logs: `docker logs sovereign-relay`
2. Check OpenCode logs: `~/.local/share/opencode/logs/`
3. Test endpoints manually:
   ```bash
   curl http://localhost:8080/health
   curl http://localhost:8080/stats
   curl http://localhost:8080/auth/status
   ```
4. Open an issue: https://github.com/lachlan-jones5/sovereign-agent/issues
