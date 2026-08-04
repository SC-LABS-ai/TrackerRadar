# Public release checklist

TrackerRadar is prepared for version control but is not ready for a public release yet.

## Required before publishing

- [x] Confirm product name and SC LABS branding for the alpha
- [ ] Select a license: proprietary source-visible or open source
- [ ] Verify ownership and redistribution rights for every asset
- [x] Implement and clearly limit the manual user-folder access scan
- [x] Add isolated file and Registry disable/undo tests
- [ ] Complete the prepared UAC firewall block-and-rollback test with the isolated copied `curl.exe` target
- [ ] Run a clean-checkout test on a second Windows machine
- [x] Confirm no usernames, local paths, scan results, tokens or secrets are tracked in the final commit candidate
- [ ] Produce current screenshots from the release build
- [x] Create and verify the final 0.5 portable package and SHA-256 file
- [ ] Decide whether code signing and an installer are required
- [ ] Enable GitHub Private Vulnerability Reporting
- [x] Review README, privacy statement, security model and limitations for 0.5
- [ ] Create the public GitHub repository and add its remote only after approval

## Current release status

`0.5.0-alpha` is a local visibility and reversible-control prototype. The manual five-second access scan is proven for process-to-folder-category association and automatic raw-trace cleanup. It must not be marketed as continuous file monitoring, proof of data exfiltration or complete protection against trackers, malware or backdoors.

Public release remains blocked by the license decision, second-machine clean test, asset-rights verification, current screenshots and the manual UAC firewall rollback test.
