# Changelog

All notable changes to TrackerRadar are documented here.

## [Unreleased]

- File-access and network-event correlation
- Richer operation classification without overstating intent
- Compiled Windows build and signed installer

## [0.5.3-alpha] - 2026-08-05

### Added
- Console-free Windows Script Host launcher while keeping the TrackerRadar WPF window visible
- Compact MalwareRadar and PrivacyRadar product-family links in the sidebar
- Fixed allowlist for the two official HTTPS product pages; no background website access
- SC LABS proprietary freeware license with future commercial and Pro editions reserved
- Dedicated hidden-launcher regression test

### Changed
- Enlarged and clipped the SC LABS mark for a cleaner fit inside its rounded frame
- Scaled the TrackerRadar artwork within its existing rounded product frame
- Kept the CMD launcher as a compatible fallback that delegates to the hidden VBS launcher

### Safety
- Product pages open only after an explicit click in the user's default browser
- No embedded browser, preload, download execution, telemetry or background web request was added
- Monitoring, file-access scanning, firewall control, startup control and rollback behavior are unchanged

### Verified
- Application core: 10/10 passed
- Hidden launcher and window visibility: 7/7 passed
- Localization, parallel keys, Unicode and persistence: 8/8 passed with 146 German and 146 English keys
- Six views, bilingual UI, logo fit and product links: 27/27 passed
- Full regression working set after ten seconds: 179.7 MB
- Full regression private memory after ten seconds: 160.5 MB
- Full regression CPU time after ten seconds: 4.75 seconds
- GUI errors: none

## [0.5.2-alpha] - 2026-08-04

### Changed
- Replaced the Windows default language drop-down with a fully local TrackerRadar dark-theme control
- Added rounded corners, matching teal borders, hover/open states and dark drop-down items
- Aligned the language selector and primary scan button to the same 52-pixel control height
- Enabled WPF layout rounding and device-pixel snapping for cleaner rendering

### Safety
- UI-only change: monitoring, file-access scanning, firewall control, startup control and rollback behavior are unchanged
- Language selection remains local under `data/ui-settings.json`

### Verified
- Application core: 10/10 passed
- Six views and German/English UI switching: 14/14 passed
- Real WPF candidate launch: passed with no GUI errors
- Full regression working set after ten seconds: 175.6 MB
- Full regression private memory after ten seconds: 155.1 MB

## [0.5.1-alpha] - 2026-08-04

### Added
- Complete local German and English interface selection
- Language selector in the application header
- Local persistence of the selected language without an account or cloud service
- Translation of navigation, page titles, table headers, status messages, provider labels and supported confirmation dialogs
- Separate locale files and localization module included in the portable package

### Verified
- Localization files, parallel keys, Unicode and persistence: 8/8 passed
- Bilingual UI and navigation: 14/14 passed
- German and English both reload correctly after a local settings change
- GUI launch: passed with no errors
- Working set after ten seconds: 192.9 MB
- Private memory after ten seconds: 174.7 MB

## [0.5.0-alpha] - 2026-08-04

### Added
- Manual five-second file-access scan for Documents, Desktop, Downloads, OneDrive, Edge profiles and Chrome profiles
- Sixth navigation view for grouped file-access results
- Process name, PID, executable path, folder category, observed operation and grouped event count
- Separate portable scan engine and visible-UAC wrapper

### Privacy and safety
- No document contents or individual file names stored in the summarized result
- Temporary ETL and CSV trace files deleted immediately after processing
- No permanent ETW session, driver, service or background file monitor
- Operation labels limited to observed open and directory-enumeration events

### Verified
- Application core: 10/10 passed
- Access parser and privacy rules: 6/6 passed
- Access UAC wrapper: 3/3 passed
- UI navigation: 6/6 passed
- Real five-second user-folder scan: passed
- Raw ETL and CSV cleanup: passed
- GUI launch: passed with no errors
- Working set after ten seconds: 182.0 MB
- Private memory after ten seconds: 163.3 MB

## [0.4.1-alpha] - 2026-08-03

### Changed
- Prevent duplicate TrackerRadar firewall rules before requesting a new rule
- Verify the exact program rule after creation and verify its absence after undo
- Add a constrained local elevated wrapper for confirmed protected actions
- Explain cancelled or unconfirmed Windows UAC prompts without claiming a change
- Add an isolated copied-`curl.exe` block/undo release test

### Verified
- Monitoring core: 8/8 passed
- Control helper: 9/9 passed
- Elevated-wrapper self-test: 3/3 passed
- UI navigation: 5/5 passed
- GUI launch and resource test: passed
- No residual firewall rule or Change Vault record after cancelled test attempts
- Real firewall effect remains pending because the interactive UAC confirmation was not completed

## [0.4.0-alpha] - 2026-08-03

### Added
- Explicit per-application outbound blocking through Windows Firewall
- Safe disable action for selected startup findings
- Local Change Vault with action status, target and timestamp
- Reversible firewall, Registry startup and Startup-folder changes
- Separate control helper without persistent elevation
- Fifth navigation view for approved changes and rollback

### Safety
- Every control action requires a confirmation dialog
- Protected actions request normal Windows UAC only when executed
- Change records are written as Pending before the Windows action
- Registry value kind is preserved for exact rollback
- No automatic blocking, deletion or Windows component removal

### Verified
- Monitoring core: 8/8 passed
- Control helper: 8/8 passed
- UI navigation: 5/5 passed
- File startup disable and undo: passed
- Registry startup disable and ExpandString rollback: passed
- Request/response interface: passed
- GUI launch: passed with no errors

## [0.3.0-alpha] - 2026-08-03

### Added
- Persistent local baseline for first-seen connection detection
- Local DNS-cache domain resolution and understandable provider context
- Detection of new, changed and removed common startup entries
- Bounded seven-day JSONL history with change-based recording
- Functional Overview, Activities, Findings and History navigation
- Detailed activity view with domain, provider, purpose, IP and first-seen time

### Changed
- Automatic refresh interval increased to 30 seconds to reduce background work
- Self-test expanded from five to eight checks

### Verified
- Baseline does not repeatedly flag the same connection as new
- History is written only when state changes or after 15 minutes
- GUI launch and local report generation pass

## [0.2.2-alpha] - 2026-08-03

### Changed
- Cropped the TrackerRadar product artwork to remove unnecessary internal margins
- Added a shared rounded button template with hover, pressed and disabled states
- Standardized card, navigation and status-panel corner radii
- Clipped data and findings panels to their rounded containers
- Aligned the primary scan button height and spacing

### Verified
- Self-test: 5/5 passed
- GUI launch: passed
- Private memory after 10 seconds: approximately 159.5 MB
- No GUI errors during automated test

## [0.2.1-alpha] - 2026-08-03

### Added
- Official SC LABS and TrackerRadar branding in the application
- Optimized local PNG assets for lower memory usage
- Public repository preparation files

### Verified
- Self-test: 5/5 passed
- GUI launch: passed
- Live scan: passed
- No GUI errors during automated test

## [0.2.0-alpha] - 2026-08-02

- Initial portable PowerShell/WPF alpha
- Process-to-network mapping for active external TCP connections
- Startup entry inventory and basic heuristics
- Local JSON reports without cloud or telemetry
