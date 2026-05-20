<#
.SYNOPSIS
    Upgrades the Hikvision DS-7608NI-E2/8P/A NVR at 192.168.0.15 to firmware
    V3.4.106 build 191009 via the ISAPI /System/updateFirmware endpoint.

.NOTES
    Requires digicap.dav extracted to F:\digicap.dav (already done).
    Uses Windows built-in curl.exe (v8+) with HTTP Digest authentication.
    Run from an elevated PowerShell prompt on PROMAX (192.168.0.68).
#>

$NVR_IP      = "192.168.0.15"
$NVR_USER    = "admin"
$FW_PATH     = "F:\digicap.dav"
$ISAPI_BASE  = "http://$NVR_IP/ISAPI"

# ── Preflight checks ─────────────────────────────────────────────────────────

if (-not (Test-Path $FW_PATH)) {
    Write-Error "Firmware file not found at $FW_PATH. Run the extraction step first."
    exit 1
}

$fwSize = [math]::Round((Get-Item $FW_PATH).Length / 1MB, 1)
Write-Host ""
Write-Host "Hikvision NVR Firmware Upgrade" -ForegroundColor Cyan
Write-Host "  Target : http://$NVR_IP  (DS-7608NI-E2/8P/A)"
Write-Host "  File   : $FW_PATH  ($fwSize MB)"
Write-Host "  Target : V3.4.106 build 191009"
Write-Host ""

# Prompt for password (hidden input)
$secPw   = Read-Host "Enter NVR admin password" -AsSecureString
$BSTR    = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secPw)
$NVR_PW  = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)

$credentials = "${NVR_USER}:${NVR_PW}"

# ── Step 1: Test authentication + read current firmware version ───────────────

Write-Host ""
Write-Host "[1/3] Checking NVR reachability and current firmware..." -ForegroundColor Yellow

$deviceInfoXml = curl.exe `
    --silent `
    --show-error `
    --digest `
    --user $credentials `
    --max-time 10 `
    "$ISAPI_BASE/System/deviceInfo" 2>&1

if ($LASTEXITCODE -ne 0 -or $deviceInfoXml -match "401|Unauthorized|Invalid") {
    Write-Error "Authentication failed or NVR unreachable. Check password and that 192.168.0.15 is pingable."
    Write-Host "Raw response: $deviceInfoXml"
    exit 1
}

# Parse firmware version from XML
if ($deviceInfoXml -match "<firmwareVersion>(.*?)</firmwareVersion>") {
    Write-Host "  Current firmware : $($Matches[1])" -ForegroundColor Green
}
if ($deviceInfoXml -match "<firmwareReleasedDate>(.*?)</firmwareReleasedDate>") {
    Write-Host "  Build date       : $($Matches[1])" -ForegroundColor Green
}
if ($deviceInfoXml -match "<model>(.*?)</model>") {
    Write-Host "  Model            : $($Matches[1])" -ForegroundColor Green
}

# ── Step 2: Confirm ────────────────────────────────────────────────────────

Write-Host ""
Write-Host "[2/3] Ready to upload firmware." -ForegroundColor Yellow
Write-Host "      The NVR will reboot automatically after the upload completes (~3-5 min)."
Write-Host "      Do NOT power off the NVR during this process." -ForegroundColor Red
Write-Host ""
$confirm = Read-Host "Type YES to proceed"
if ($confirm -ne "YES") {
    Write-Host "Aborted." -ForegroundColor Gray
    exit 0
}

# ── Step 3: Upload firmware via ISAPI PUT ─────────────────────────────────────
#
# Hikvision ISAPI firmware upgrade:
#   PUT /ISAPI/System/updateFirmware
#   Content-Type: multipart/form-data
#   Field name: FirmwareUpdate  (file: digicap.dav, type: application/octet-stream)
#
# The NVR verifies the digicap.dav header internally, then reboots.
# HTTP response 200 = accepted; NVR then goes offline while flashing (~3-5 min).

Write-Host ""
Write-Host "[3/3] Uploading firmware to NVR (this may take 1-2 minutes)..." -ForegroundColor Yellow
Write-Host ""

$response = curl.exe `
    --digest `
    --user $credentials `
    --request PUT `
    --form "FirmwareUpdate=@${FW_PATH};type=application/octet-stream" `
    --max-time 300 `
    --progress-bar `
    --write-out "`n--- HTTP Status: %{http_code} ---`n" `
    "$ISAPI_BASE/System/updateFirmware" 2>&1

Write-Host $response

# Interpret result
if ($response -match "HTTP Status: 200") {
    Write-Host ""
    Write-Host "SUCCESS — Firmware accepted. The NVR is now rebooting." -ForegroundColor Green
    Write-Host ""
    Write-Host "Wait 3-5 minutes, then verify at http://$NVR_IP"
    Write-Host "Expected: V3.4.106 build 191009"
    Write-Host ""

    # Poll until NVR comes back
    Write-Host "Polling for NVR to come back online..." -ForegroundColor Yellow
    $came_back = $false
    for ($i = 1; $i -le 20; $i++) {
        Start-Sleep -Seconds 15
        $ping = Test-Connection $NVR_IP -Count 1 -Quiet -ErrorAction SilentlyContinue
        if ($ping) {
            Start-Sleep -Seconds 10  # give web server a moment
            $newInfo = curl.exe --silent --digest --user $credentials --max-time 8 "$ISAPI_BASE/System/deviceInfo" 2>&1
            if ($newInfo -match "<firmwareVersion>(.*?)</firmwareVersion>") {
                Write-Host ""
                Write-Host "NVR is back online!" -ForegroundColor Green
                Write-Host "  New firmware : $($Matches[1])"
                if ($newInfo -match "<firmwareReleasedDate>(.*?)</firmwareReleasedDate>") {
                    Write-Host "  Build date   : $($Matches[1])"
                }
                $came_back = $true
                break
            }
        }
        Write-Host "  [$i] Still rebooting... ($($i * 15)s elapsed)"
    }

    if (-not $came_back) {
        Write-Host "NVR did not respond within 5 minutes. Check it manually at http://$NVR_IP"
    }

} elseif ($response -match "HTTP Status: 40[013]") {
    Write-Host ""
    Write-Host "FAILED — Authentication or permissions error (HTTP $($Matches[0]))." -ForegroundColor Red
    Write-Host "Ensure you are logged in as 'admin' (not an operator account)."
} elseif ($response -match "HTTP Status: 5") {
    Write-Host ""
    Write-Host "FAILED — NVR returned a server error. The firmware file may be incompatible," -ForegroundColor Red
    Write-Host "or the NVR may already be on this version."
} else {
    Write-Host ""
    Write-Host "Unexpected response — check the output above." -ForegroundColor Yellow
    Write-Host "If the NVR went offline immediately it may still be flashing — wait 5 min and check." -ForegroundColor Yellow
}
