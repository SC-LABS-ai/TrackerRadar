# Privacy

TrackerRadar is designed as a local-first Windows application.

Official publisher: [SC LABS](https://sclabs.uk/)

## Current alpha behavior

- No user account
- No cloud backend
- No analytics, advertising or product telemetry
- No automatic upload of scan results
- Reports, baseline data, history and Change Vault records are written locally under `data/`
- The selected interface language (`de` or `en`) is stored locally in `data/ui-settings.json`; no profile or account data is required
- Change Vault records may contain local executable paths, startup names and Registry locations needed for rollback
- Control requests and responses remain local and are removed after processing
- HTTPS payloads are not decrypted

## External product links

The sidebar contains a compact `sclabs.uk` link and the footer contains explicit MalwareRadar and PrivacyRadar product links. TrackerRadar does not preload those pages, embed a browser or contact the website in the background. A normal external browser request occurs only after the user selects one of the links.

## File-access short scan

The file-access feature runs only after the user selects the scan button and confirms the visible Windows UAC prompt.

The summarized result may contain:

- process name
- process ID
- executable path
- monitored folder category
- observed operation category
- grouped event count

TrackerRadar does not store document contents or individual file names in the summarized access-scan result. Temporary ETL and CSV trace files are deleted immediately after local processing. A small local JSON summary and diagnostic log remain under `data/access-scan/`.

Executable paths and diagnostic logs can still contain machine-specific information. The complete `data/` directory is excluded from Git.

## Public issue safety

Before sharing logs or screenshots, remove usernames, local paths, process IDs, IP addresses and application-specific information.
