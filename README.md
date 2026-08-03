<p align="center">
  <img src="assets/branding/trackerradar-logo.png" width="220" alt="TrackerRadar logo">
</p>

# TrackerRadar

**Local-first Windows visibility for unexpected application behaviour.**

TrackerRadar shows which applications maintain external TCP connections, where they connect, and whether they start from unusual locations or register persistent startup entries. The interface is intentionally simple and the current alpha is read-only.

## Status

**Version:** `0.2.2-alpha`  
**State:** local prototype, not a public security release  
**Tested on:** Windows 11 Pro with Windows PowerShell 5.1

## Current capabilities

- Map active external TCP connections to processes
- Show application, PID, target IP, port and executable path
- Highlight script hosts and unusual execution locations
- Inventory common Registry and Startup-folder persistence entries
- Group findings instead of producing an alert flood
- Write a local JSON report to `data\latest-scan.json`
- Refresh automatically every 20 seconds
- Operate without account, cloud backend or product telemetry

## Quick start

No installation is required for the alpha.

1. Download or clone the repository.
2. Double-click `Start-TrackerRadar.cmd`.
3. Select **Jetzt pruefen** to create a fresh local snapshot.

PowerShell execution is limited to the scripts contained in this project. TrackerRadar does not request silent elevation.

## Test

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Test-TrackerRadar-App.ps1
```

The test checks the self-test, live snapshot, WPF launch, GUI errors and memory usage. Machine-specific results are stored in the ignored `data/` directory.

## Portable package

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Build-Portable.ps1
```

This creates an ignored `dist/` folder containing the portable ZIP and a matching SHA-256 file. The package is only created after a successful self-test.

## Current limitations

- It is a momentary view of active external TCP connections, not packet capture.
- It does not decrypt HTTPS traffic.
- Complete per-process file-read monitoring is not implemented yet.
- It does not block, delete or modify Windows components.
- It is not a replacement for antivirus, EDR or incident response.
- It cannot guarantee detection of every tracker, malware sample or backdoor.

## Privacy and security

See [PRIVACY.md](PRIVACY.md) and [SECURITY.md](SECURITY.md). Scan data and local development files are excluded from Git.

## Public release preparation

The repository is structured for later GitHub publication, but no remote is configured and no public push has been performed. See [PUBLIC-RELEASE-CHECKLIST.md](PUBLIC-RELEASE-CHECKLIST.md).

## Rights

Copyright © 2026 SC LABS. All rights reserved. No open-source license has been selected yet. See [NOTICE.md](NOTICE.md).

---

## Kurzbeschreibung auf Deutsch

TrackerRadar ist eine portable, lokale Windows-App im SC-LABS-Design. Sie zeigt aktive externe Verbindungen, ordnet sie Programmen zu und weist auf auffällige Startpfade oder Autostarts hin. Die aktuelle Alpha beobachtet ausschließlich und verändert das System nicht.
