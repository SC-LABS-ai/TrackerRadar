# Privacy

TrackerRadar is designed as a local-first Windows application.

## Current alpha behavior

- No user account
- No cloud backend
- No analytics, advertising or product telemetry
- No automatic upload of scan results
- Reports are written locally to `data/`
- HTTPS payloads are not decrypted
- The alpha does not read document contents

The `data/` directory is excluded from Git so machine-specific scan results are not committed accidentally.

## Public issue safety

Before sharing logs or screenshots, remove usernames, local paths, process IDs, IP addresses and application-specific information.
