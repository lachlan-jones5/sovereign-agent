# Alternative Setups

Different deployment patterns for Sovereign Agent.

## Direct SSH Tunnel (No Laptop Bridge)

If the Work VM can directly SSH to the relay server:

```
┌──────────────┐         ┌────────────────┐
│   Work VM    │─────────│   Pi/VPS       │
│   OpenCode   │  SSH    │   (relay)      │
│              │  tunnel │   :8081        │
└──────────────┘         └────────────────┘
```

**On Work VM:**

```bash
# Create tunnel
ssh -L 8081:localhost:8081 user@relay-server -N &

# Install
curl -fsSL http://localhost:8081/setup | bash
```

**SSH config (~/.ssh/config):**

```ssh-config
Host relay
    HostName relay-server.example.com
    User pi
    LocalForward 8081 localhost:8081
```

Then just: `ssh relay -N &`

## Standalone Mode (No Relay)

Run everything on one machine with API key local:

```bash
git clone --recurse-submodules https://github.com/lachlan-jones5/sovereign-agent.git
cd sovereign-agent

cp config.json.example config.json
# Edit config.json: add openrouter_api_key, set relay.enabled=false

./install.sh
opencode
```

## Docker Standalone

```bash
git clone --recurse-submodules https://github.com/lachlan-jones5/sovereign-agent.git
cd sovereign-agent

cp config.json.example config.json
# Edit config.json with API key

docker compose run --rm agent
```

## VPS as Relay (Cloud)

Deploy relay to a VPS (DigitalOcean, Linode, etc.):

```bash
# On VPS
ssh root@your-vps.com

# Install Docker
curl -fsSL https://get.docker.com | sh

# Setup relay
OPENROUTER_API_KEY=sk-or-v1-... \
RELAY_HOST=0.0.0.0 \
RELAY_PORT=8081 \
curl -fsSL https://raw.githubusercontent.com/lachlan-jones5/sovereign-agent/master/scripts/setup-relay.sh | bash
```

Then connect via SSH tunnel from anywhere:

```bash
ssh -L 8081:localhost:8081 root@your-vps.com -N &
curl -fsSL http://localhost:8081/setup | bash
```

## Multiple Clients

One relay server can serve multiple clients:

```
┌──────────────┐
│  Client A    │──┐
└──────────────┘  │     ┌────────────────┐
                  ├────▶│   Relay        │────▶ OpenRouter
┌──────────────┐  │     │   :8081        │
│  Client B    │──┘     └────────────────┘
└──────────────┘
```

Each client connects via their own SSH tunnel to the same relay.

## Persistent Tunnels with autossh

Keep tunnels alive automatically:

```bash
# Install autossh
sudo apt install autossh  # Debian/Ubuntu
brew install autossh      # macOS

# Persistent reverse tunnel
autossh -M 0 \
  -o "ServerAliveInterval 30" \
  -o "ServerAliveCountMax 3" \
  -R 8081:relay-server:8081 \
  workvm -N
```

## systemd Service (Linux)

Create `/etc/systemd/system/sovereign-tunnel.service`:

```ini
[Unit]
Description=Sovereign Agent SSH Tunnel
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/autossh -M 0 -o "ServerAliveInterval 30" -R 8081:relay-server:8081 workvm -N
Restart=always
RestartSec=10
User=youruser

[Install]
WantedBy=multi-user.target
```

Enable and start:

```bash
sudo systemctl enable sovereign-tunnel
sudo systemctl start sovereign-tunnel
```

## launchd Service (macOS)

Create `~/Library/LaunchAgents/com.sovereign.tunnel.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.sovereign.tunnel</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/autossh</string>
        <string>-M</string>
        <string>0</string>
        <string>-o</string>
        <string>ServerAliveInterval 30</string>
        <string>-R</string>
        <string>8081:relay-server:8081</string>
        <string>workvm</string>
        <string>-N</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
```

Load:

```bash
launchctl load ~/Library/LaunchAgents/com.sovereign.tunnel.plist
```

## Docker Network Mode

If your Work VM runs dev containers, use host networking:

```bash
# Run container with host networking
docker run --network host -it your-dev-image

# Inside container, localhost:8081 reaches host's tunnel
curl http://localhost:8081/health
```

Or create tunnel from container to host:

```bash
# Find host IP
ip route | grep default | awk '{print $3}'
# Example: 172.17.0.1

# Tunnel from container to host
ssh -L 8081:127.0.0.1:8081 user@172.17.0.1 -N &
```

## See Also

- [Architecture](ARCHITECTURE.md) - System overview
- [Relay Setup](RELAY-SETUP.md) - Detailed relay configuration
