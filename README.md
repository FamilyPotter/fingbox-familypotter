# fingbox-familypotter

Docker Compose configuration for the [Fing Agent](https://hub.docker.com/r/fing/fing-agent) network monitoring service, integrated with the [Fing Local API](https://www.fing.com/integrations/local-api/) and Home Assistant.

The software **Fing Agent** runs on the **QNAP TS-264 NAS** (`CALGARYHOUSE`, `192.168.0.150`) via Container Station. The physical **Fingbox v1** is at `192.168.0.144` and independently exposes the same Local API on port `49090`.

---

## Prerequisites

- QNAP Container Station installed on the NAS (available from QNAP App Center).
- The [Fing mobile app](https://www.fing.com/) (iOS / Android) logged in to your Fing account — required for agent activation and API key retrieval.
- A Fing Starter or Premium subscription.

---

## QNAP Container Station setup

### 1. Copy the project to the NAS

Either clone via SSH or upload the files using QNAP File Station to a shared folder, e.g. `/share/fingbox-familypotter/`.

```bash
# Via SSH on the QNAP
git clone https://github.com/FamilyPotter/fingbox-familypotter.git /share/fingbox-familypotter
```

### 2. Create the data directory

```bash
mkdir -p /share/fing-data
```

### 3. Deploy with Container Station

In the QNAP web UI:

1. Open **Container Station**.
2. Go to **Applications** and click **+ Create**.
3. Select **Upload a Compose file** and upload `docker-compose.yml`, or paste its contents directly.
4. Click **Create** — Container Station will pull `fing/fing-agent:latest` and start the container.

Alternatively, deploy via SSH:

```bash
cd /share/fingbox-familypotter
docker compose up -d
```

### 4. Activate via the Fing app

On first run the agent registers as unactivated:

1. Open the Fing app and go to **Network > Agents**.
2. Tap the new agent that appears (shown as pending activation).
3. Follow the in-app prompts to activate it.
4. Once active, retrieve the API key (see below).

---

## Obtaining the API key

The API key is generated on the agent and surfaced through the Fing mobile app.

**For the QNAP-based Fing Agent:**

1. In the Fing app, navigate to **Network > Agents**.
2. Tap the QNAP agent.
3. Tap **Settings > Local API**.
4. Copy the displayed API key into your `.env` file as `FING_API_KEY`.

**For the physical Fingbox at `192.168.0.144`:**

1. In the Fing app, tap the **Fingbox** device listed under your network.
2. Tap **Settings > Local API**.

Current API key: stored in `.env` (gitignored).

Keep the API key confidential — it grants read access to your live network device data.

---

## Local API reference (v1.1.0)

All endpoints require the API key as the `auth` query parameter.

### Base URLs

| Agent | URL |
|-------|-----|
| Fing Agent (QNAP NAS) | `http://192.168.0.150:49090/1/` |
| Fingbox (physical) | `http://192.168.0.144:49090/1/` |

### `GET /devices`

Returns all devices discovered on the local network.

```
GET http://<host>:49090/1/devices?auth=<api_key>
```

**Response (200):**

```json
{
  "networkId": "eth-C0A80000-1890210663F619",
  "devices": [
    {
      "mac":          "00:11:22:33:44:55",
      "ip":           ["192.168.0.1"],
      "state":        "UP",
      "name":         "Main Sky Hub",
      "type":         "ROUTER",
      "make":         "Sky",
      "model":        "Sky Hub",
      "first_seen":   "2020-04-24T12:54:21.634Z",
      "last_changed": "2026-04-23T11:00:00.000Z"
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
| `type` | string | Device category |
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

> **Not supported** by Fing Agent (Docker) or Fingbox. Returns a 503 error on those agents.

### Quick test

```powershell
# From PROMAX Windows PC — query the Fingbox (always available)
Invoke-RestMethod "http://192.168.0.144:49090/1/devices?auth=<api_key>"

# Query the QNAP Fing Agent (once activated)
Invoke-RestMethod "http://192.168.0.150:49090/1/devices?auth=<api_key>"
```

---

## Home Assistant integration

The Fing integration (introduced in **Home Assistant 2025.11**) provides device tracker entities for presence detection automations.

### Setup

In Home Assistant, go to **Settings > Devices & Services > Add Integration > Fing** and enter:

| Field | Fingbox (physical) | Fing Agent (QNAP) |
|-------|-------------------|-------------------|
| Host | `192.168.0.144` | `192.168.0.150` |
| Port | `49090` | `49090` |
| API Key | from Fing app | from Fing app |

Point HA at the **Fingbox** (`192.168.0.144`) for immediate use — it is already active and returning 67 devices.

### What you get

- `device_tracker.<device_name>` entities — state `home` / `not_home` based on UP/DOWN status.
- Attributes: MAC, IP, device type, make/model, `first_seen`, `last_changed`.
- Usable in automations, presence detection, and dashboards.

### Troubleshooting

- Confirm the container is running: `docker compose ps` (via QNAP SSH or Container Station UI)
- Test the Local API: `curl "http://192.168.0.150:49090/1/devices?auth=<key>"`
- Ensure Local API version is 1.1.0+.

---

## Network devices (67 discovered by Fingbox)

Key devices visible on the FamilyPotter network:

| Device | IP | MAC | Status |
|--------|----|-----|--------|
| Fingbox v1 | 192.168.0.144 | F0:23:B9:EB:12:F9 | UP |
| QNAP NAS (CALGARYHOUSE) | 192.168.0.150/151 | 24:5E:BE:6D:25:88/89 | UP |
| PROMAX (Windows PC) | 192.168.0.68 | E8:CF:83:8E:0B:69 | UP |
| Main Sky Hub | 192.168.0.1 | 90:21:06:63:F6:19 | UP |
| Hikvision NVR | 192.168.0.15 | 28:57:BE:86:BF:00 | UP |
| 6× Hikvision cameras | .30/.31/.32/.33/.35/.36 | various | UP/DOWN |
| 5× Sonos devices | .67/.80/.94/.95/.97/.98 | various | UP |
| Sky Q boxes | .51/.73/.91/.197 | various | UP/DOWN |
| Miele dishwasher | 192.168.0.66 | 00:1D:63:75:0A:43 | UP |
| Miele washing machine | 192.168.0.69 | 00:1D:63:CB:7C:76 | UP |

---

## File structure

```
fingbox-familypotter/
├── docker-compose.yml   # Fing Agent — deploy on QNAP Container Station
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
- [QNAP Container Station documentation](https://www.qnap.com/en/software/container-station)
