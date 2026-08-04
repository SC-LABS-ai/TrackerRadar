# Privacy

TrackerRadar is designed as a local-first Windows application.

## Current alpha behavior

- No user account
- No cloud backend
- No analytics, advertising or product telemetry
- No automatic upload of scan results
- Reports, baseline data, history and Change Vault records are written locally under `data/`
- Change Vault records may contain local executable paths, startup names and Registry locations needed for rollback
- Control requests and responses remain local and are removed after processing
- HTTPS payloads are not decrypted

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
