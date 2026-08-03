# Security Policy

TrackerRadar is currently an early local alpha and is not a replacement for antivirus, EDR or professional incident response.

## Control model

- Monitoring runs without persistent administrator rights.
- No control action is executed automatically.
- Firewall and protected startup actions require explicit confirmation and a visible Windows UAC prompt.
- The control helper accepts local request files only; it does not open a network port.
- Every supported action writes rollback information to the local Change Vault before modifying Windows.
- The current alpha only supports outbound firewall blocking and selected startup disable/undo operations.

## Reporting a vulnerability

When the public GitHub repository is enabled, use GitHub Private Vulnerability Reporting. Do not publish exploit details, personal scan data or machine-specific paths in a public issue.

If private reporting is not yet available, open a minimal issue requesting a private contact channel without disclosing technical exploit details.

## Supported versions

Only the newest tagged alpha is evaluated. Older development snapshots are unsupported.
