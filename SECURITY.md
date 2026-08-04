# Security Policy

TrackerRadar is an early local alpha and is not a replacement for antivirus, EDR or professional incident response.

## Control model

- The main interface runs without persistent administrator rights.
- No control action is executed automatically.
- Firewall and protected startup actions require explicit confirmation and a visible Windows UAC prompt.
- The control helper accepts local request files only and does not open a network port.
- Supported control actions write rollback information to the local Change Vault before modifying Windows.
- The current alpha only supports outbound firewall blocking and selected startup disable/undo operations.

## File-access scan model

- The scan starts only after an explicit user action and visible UAC approval.
- It uses a uniquely named, short-lived Windows ETW trace session.
- It does not install a driver, service or permanent background monitor.
- Temporary ETL and CSV files are removed in a `finally` cleanup path.
- The result does not store document contents or individual file names.
- Event labels describe observed Windows events and must not be interpreted as proof that data was copied, uploaded or used maliciously.

## Reporting a vulnerability

When the public GitHub repository is enabled, use GitHub Private Vulnerability Reporting. Do not publish exploit details, personal scan data or machine-specific paths in a public issue.

If private reporting is not yet available, open a minimal issue requesting a private contact channel without disclosing technical exploit details.

## Supported versions

Only the newest tagged alpha is evaluated. Older development snapshots are unsupported.
