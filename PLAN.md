# TrackerRadar Alpha — Lean Product Plan

[Official SC LABS website](https://sclabs.uk/)

## Product decision

TrackerRadar is delivered first as a portable, local Windows application.

- Interface: native WPF interface in the SC LABS visual language
- Runtime: Windows PowerShell 5.1 and the Windows desktop runtime already available on the system
- Installation: not required for the alpha
- Launch: console-free `Start-TrackerRadar.vbs`, with `Start-TrackerRadar.cmd` as a compatible fallback
- Data: stored locally inside the application folder
- Telemetry and cloud backend: none
- Privileges: the main interface runs without persistent administrator rights; protected actions use visible Windows UAC only after explicit confirmation

## Why the alpha remains portable

A portable build keeps installation, update, removal and signing complexity out of the early validation cycle. It can be copied to another Windows computer, verified against its SHA-256 value and removed without leaving a permanent service or background component.

## Current alpha scope

1. Show active external TCP connections by application.
2. Associate destination address, port, process, PID and executable path.
3. Explain common providers and purposes using local information and conservative heuristics.
4. Establish a local baseline and highlight newly observed activity.
5. Detect new, changed and removed common startup entries.
6. Present a small number of grouped findings instead of an event flood.
7. Run a deliberately started five-second file-access scan for selected user-folder categories without storing file contents or individual file names.
8. Provide a complete local German and English interface.
9. Offer explicit, reversible outbound firewall blocking and selected startup disable actions through the Change Vault.
10. Produce local JSON reports, self-tests and resource measurements.

## Deliberate limitations

- No custom kernel driver.
- No TLS interception and no root certificate.
- No analysis of personal file contents.
- No claim of complete or continuous file-read detection.
- No automatic deletion, cleanup or Windows debloat action.
- No claim that every connection or file-system event is malicious.
- No replacement for antivirus, EDR or professional incident response.

## Quality targets

- Working set below 180 MB on the primary test system where practical.
- No permanent CPU polling loop.
- No account, cloud backend or product telemetry.
- No silent elevation.
- Clear language without unnecessary SOC or firewall jargon.
- Every protected change must be explicit, logged and reversible where supported.

## Verification loop

1. Run syntax and component self-tests.
2. Capture a live local snapshot.
3. Start the real WPF interface.
4. Measure CPU and memory use.
5. Review report plausibility and privacy boundaries.
6. Correct errors and unnecessary load.
7. Repeat the complete regression suite.
8. Build the portable ZIP and verify it from a fresh extraction.
9. Confirm the SHA-256 value and absence of residual firewall rules or test artifacts.
10. Document verified results and remaining limitations.

## Remaining hardening work

- Test the portable package on a second Windows computer.
- Document ownership and redistribution rights for all branding assets.
- Add current release screenshots.
- Update the TrackerRadar page on the official SC LABS website.
- Consider a signed installer only after the portable alpha has completed broader validation.
