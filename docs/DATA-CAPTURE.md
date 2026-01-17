# Data Capture for Fine-Tuning

The relay server can capture all request/response pairs for later use in fine-tuning models (e.g., using LoRA). This feature saves raw data in JSONL format, which can be post-processed into training datasets.

## Overview

When enabled, the relay intercepts all API requests and responses, capturing:
- Full request body (prompts, system messages, model selection)
- Full response body (completions, including streaming responses)
- Metadata (timestamps, latency, model, token multipliers)

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DATA_CAPTURE_ENABLED` | `false` | Enable capture (also auto-enabled if PATH or URL set) |
| `DATA_CAPTURE_PATH` | `../data/captures.jsonl` | Local JSONL file path |
| `DATA_CAPTURE_FORWARD_URL` | (none) | URL to forward captures in real-time |

### Enable Local Capture

Save all sessions to a local JSONL file:

```bash
DATA_CAPTURE_ENABLED=true bun run main.ts

# Or specify a custom path
DATA_CAPTURE_PATH=/path/to/my-captures.jsonl bun run main.ts
```

### Enable Tunnel Forwarding

Forward captures to a remote device (e.g., your personal machine via SSH tunnel):

```bash
# On client VM - forward to relay running on personal device
DATA_CAPTURE_FORWARD_URL=http://localhost:9090/data/ingest bun run main.ts
```

### Combined Setup

Both local storage and forwarding can be enabled simultaneously:

```bash
DATA_CAPTURE_ENABLED=true \
DATA_CAPTURE_PATH=./data/local-captures.jsonl \
DATA_CAPTURE_FORWARD_URL=http://localhost:9090/data/ingest \
bun run main.ts
```

## Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/data/stats` | GET | Capture statistics (count, file size) |
| `/data/recent` | GET | Recent captures (use `?limit=N`, default 10) |
| `/data/export` | GET | Download all captures as JSONL file |
| `/data/ingest` | POST | Receive forwarded captures from remote relays |

### Examples

```bash
# Check capture status
curl http://localhost:8080/data/stats | jq

# View last 5 captures (summaries)
curl "http://localhost:8080/data/recent?limit=5" | jq

# Download all captures
curl http://localhost:8080/data/export > captures.jsonl

# Count total captures
wc -l captures.jsonl
```

## Data Format

Each line in the JSONL file is a complete session:

```json
{
  "id": "uuid-v4",
  "timestamp": "2025-01-17T10:30:00.000Z",
  "endpoint": "/v1/chat/completions",
  "method": "POST",
  "request": {
    "model": "claude-sonnet-4.5",
    "messages": [
      {"role": "system", "content": "You are a helpful assistant..."},
      {"role": "user", "content": "How do I..."}
    ],
    "stream": true
  },
  "response": "data: {\"choices\":[...]}\n\ndata: [DONE]\n",
  "status": 200,
  "latency_ms": 1523,
  "model": "claude-sonnet-4.5",
  "multiplier": 1,
  "stream": true
}
```

For non-streaming responses, the `response` field contains the parsed JSON object.

## Architecture: Client VM to Personal Device

When running on an untrusted client VM, you may want to forward all captures to your personal device for safe storage:

```
┌─────────────────┐     SSH Tunnel      ┌─────────────────┐
│   Client VM     │◄──────────────────►│ Personal Device │
│                 │                     │                 │
│  ┌───────────┐  │                     │  ┌───────────┐  │
│  │   Relay   │──┼── POST /data/ingest─┼─►│   Relay   │  │
│  │ (capture) │  │                     │  │ (storage) │  │
│  └───────────┘  │                     │  └───────────┘  │
│                 │                     │                 │
│  OpenCode ─────►│                     │  data/          │
│                 │                     │  └─captures.jsonl
└─────────────────┘                     └─────────────────┘
```

### Setup

1. **On Personal Device** - Run relay with local storage only:
   ```bash
   DATA_CAPTURE_ENABLED=true \
   DATA_CAPTURE_PATH=./data/captures.jsonl \
   RELAY_PORT=9090 \
   bun run main.ts
   ```

2. **Create SSH Tunnel** - From client VM to personal device:
   ```bash
   ssh -R 9090:localhost:9090 user@personal-device
   ```

3. **On Client VM** - Run relay with forwarding:
   ```bash
   DATA_CAPTURE_FORWARD_URL=http://localhost:9090/data/ingest \
   bun run main.ts
   ```

Now all coding sessions on the client VM are forwarded to your personal device.

## Post-Processing for Fine-Tuning

The raw JSONL data needs to be transformed into training format. Example Python script:

```python
import json

def process_captures(input_path, output_path):
    with open(input_path) as f, open(output_path, 'w') as out:
        for line in f:
            session = json.loads(line)
            
            # Skip non-chat completions
            if '/chat/completions' not in session['endpoint']:
                continue
            
            request = session['request']
            if not isinstance(request, dict):
                continue
            
            messages = request.get('messages', [])
            
            # Extract instruction (system + user) and output (assistant)
            # Transform to your preferred format
            training_example = {
                'messages': messages,
                'model': session['model'],
                'timestamp': session['timestamp'],
            }
            
            out.write(json.dumps(training_example) + '\n')

process_captures('captures.jsonl', 'training_data.jsonl')
```

## Security Considerations

1. **Captures contain sensitive data** - prompts may include code, credentials, personal info
2. **Store captures securely** - use encrypted storage on personal devices
3. **Don't commit captures** - add `data/` to `.gitignore`
4. **Scrub before training** - remove sensitive data before using for fine-tuning
5. **Tunnel security** - use SSH tunnels, not plain HTTP over internet

## Troubleshooting

### Captures not appearing

1. Check if capture is enabled:
   ```bash
   curl http://localhost:8080/stats | jq .data_capture
   ```

2. Check data directory exists and is writable:
   ```bash
   ls -la data/
   ```

3. Check relay logs for capture errors

### Forward failing

1. Verify tunnel is active:
   ```bash
   curl http://localhost:9090/health
   ```

2. Check target relay has capture enabled:
   ```bash
   curl http://localhost:9090/data/stats
   ```

3. Check for connection errors in relay logs
