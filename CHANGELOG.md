# Changelog

All notable changes to TrackerRadar are documented here.

## [Unreleased]

- Full sensitive-file access correlation
- Safe per-application blocking and rollback
- Compiled Windows build and signed installer

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
