# fingbox-familypotter

Docker Compose configuration for the [Fing Agent](https://hub.docker.com/r/fing/fing-agent) network monitoring service, integrated with the [Fing Local API](https://www.fing.com/integrations/local-api/) and Home Assistant.

The physical **Fingbox** device is at `192.168.0.68` and already exposes the Local API on port `49090`. This repository also deploys a software-based **Fing Agent** container for additional monitoring from the Docker host.

---

## Prerequisites

- Docker Desktop installed and running on Windows.
- The [Fing mobile app](https://www.fing.com/) (iOS / Android) logged in to your Fing account — required for agent activation and API key retrieval.
- A Fing Starter or Premium subscription (one agent included with Starter).

---

## Quick start

### 1. Clone and configure

```powershell
git clone https://github.com/FamilyPotter/fingbox-familypotter.git
cd fingbox-familypotter
Copy-Item .env.example .env
```

Edit `.env` and fill in your values (see [Obtaining the API key](#obtaining-the-api-key) below).

### 2. Start the Fing Agent

```powershell
docker compose up -d
```

The container runs with `network_mode: host` and `NET_ADMIN` capability so it can ARP-scan the LAN. The Local API is then available at `http://localhost:49090`.

### 3. Activate via the Fing app

On first run the container registers as an unactivated agent:

1. Open the Fing app and go to **Network > Agents**.
2. Tap the new agent that appears (it will show as pending activation).
3. Follow the in-app prompts to activate it.
4. Once active, retrieve the API key (see below).

---

## Obtaining the API key

The API key is generated on the agent and surfaced through the Fing mobile app:

**For the Docker-based Fing Agent:**

1. In the Fing app, navigate to **Network > Agents**.
2. Tap your running agent (the one on this Docker host).
3. Tap **Settings > Local API**.
4. Copy the displayed API key into your `.env` file as `FING_API_KEY`.

**For the physical Fingbox at `192.168.0.68`:**

1. In the Fing app, tap the **Fingbox** device listed under your network.
2. Tap **Settings > Local API**.
3. Copy the API key — it may be the same key or a separate one depending on your Fing account.

Keep the API key confidential — it grants read access to your live network device data.

---

## Local API reference (v1.1.0)

The Fing Local API is a free, locally-published HTTP API. All endpoints require the API key as a `auth` query parameter.

### Base URLs

| Agent | URL |
|-------|-----|
| Fing Agent (Docker host) | `http://localhost:49090/1/` |
| Fingbox (physical) | `http://192.168.0.68:49090/1/` |

### `GET /devices`

Returns all devices discovered on the local network.

```
GET http://<host>:49090/1/devices?auth=<api_key>
```

**Response (200):**

```json
{
  "networkId": "wifi-12345812839223",
  "devices": [
    {
      "mac":          "00:11:22:33:44:55",
      "ip":           ["192.168.0.1"],
      "state":        "UP",
      "name":         "Bedroom Chromecast",
      "type":         "STREAMING_DONGLE",
      "make":         "Google",
      "model":        "Chromecast",
      "contactId":    "67363e09-5ad6-40d0-883f-3e17254eec7a",
      "first_seen":   "2020-04-24T12:54:21.634Z",
      "last_changed": "2020-06-11T12:01:23.164Z"
    }
  ]
}
```

Device fields:

| Field | Type | Description |
|-------|------|-------------|
| `mac` | string | MAC address |
| `ip` | string[] | One or more IP addresses |
| `state` | string | `UP` or `DOWN` |
| `name` | string | Human-readable device name |
| `type` | string | Device category (e.g. `STREAMING_DONGLE`) |
| `make` | string | Manufacturer |
| `model` | string | Model name |
| `contactId` | uuid | Reference to the Fing contact that owns this device |
| `first_seen` | ISO 8601 | When the device was first discovered |
| `last_changed` | ISO 8601 | Last state change timestamp |

**Error codes:**

| Code | Meaning |
|------|---------|
| 400 | Invalid input |
| 401 | Unauthorised — invalid or missing API key |
| 503 | Service error — agent not running or unavailable |

### `GET /people` — Fing Desktop only

> **Not supported** by Fing Agent (Docker) or Fingbox. Calls to this endpoint will return a 503 service error on those agents.

### Quick test (PowerShell)

```powershell
# Load the key from .env
$key = (Get-Content .env | Where-Object { $_ -match "^FING_API_KEY=" }) -replace "^FING_API_KEY=",""

# Query the Docker agent
Invoke-RestMethod "http://localhost:49090/1/devices?auth=$key"

# Query the physical Fingbox
Invoke-RestMethod "http://192.168.0.68:49090/1/devices?auth=$key"
```

---

## Home Assistant integration

The Fing integration (introduced in **Home Assistant 2025.11**) provides device tracker entities for each discovered network device, enabling presence detection automations.

### Setup

1. In Home Assistant, go to **Settings > Devices & Services**.
2. Click **Add Integration** and search for **Fing**.
3. Enter the connection details:

| Field | Docker Agent | Physical Fingbox |
|-------|-------------|-----------------|
| Host | Docker host LAN IP | `192.168.0.68` |
| Port | `49090` | `49090` |
| API Key | From `.env` | From Fing app |

4. Home Assistant will create a **device tracker** entity for each device Fing has discovered.

### What you get

- `device_tracker.<device_name>` entities with state `home` / `not_home` based on `UP`/`DOWN` status.
- Attributes on each entity: MAC address, IP addresses, device type, make, model, `first_seen`, `last_changed`.
- Usable in **automations** and **presence detection** (e.g. notify when an unknown device joins the network, or trigger scenes when a family member's phone comes online).

### Troubleshooting

- Confirm the Fing Agent container is running: `docker compose ps`
- Verify the Local API is reachable: `Invoke-RestMethod "http://localhost:49090/1/devices?auth=<key>"`
- Ensure the Local API version is 1.1.0 or newer (check the Fing app under agent settings).
- Check that the port and IP entered in Home Assistant match the actual agent.

---

## File structure

```
fingbox-familypotter/
├── docker-compose.yml   # Fing Agent service definition
├── .env.example         # Environment variable template
├── .env                 # Your real values (gitignored)
├── .gitignore
└── README.md
```

---

## Related links

- [Fing Agent on Docker Hub](https://hub.docker.com/r/fing/fing-agent)
- [Fing Local API documentation](https://www.fing.com/integrations/local-api/)
- [Home Assistant Fing integration](https://www.home-assistant.io/integrations/fing)
- [Fing Help Center — Installing Fing Agent](https://help.fing.com/hc/en-us/articles/14429872073244)
