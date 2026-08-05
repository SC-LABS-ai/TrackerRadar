# Public release checklist

TrackerRadar is prepared for version control but is not ready for a public release yet.

## Required before publishing

- [x] Confirm product name and SC LABS branding for the alpha
- [x] Select proprietary freeware terms and include `LICENSE.md`
- [ ] Verify ownership and redistribution rights for every asset
- [x] Implement and clearly limit the manual user-folder access scan
- [x] Add and verify complete local German and English interface selection
- [x] Match the language selector to the dark rounded TrackerRadar control design
- [x] Fit both sidebar logos into their rounded frames
- [x] Hide the PowerShell console through the verified VBS launcher
- [x] Add explicit MalwareRadar and PrivacyRadar product links without background web access
- [x] Add isolated file and Registry disable/undo tests
- [ ] Complete the prepared UAC firewall block-and-rollback test with the isolated copied `curl.exe` target
- [ ] Run a clean-checkout test on a second Windows machine
- [x] Confirm no usernames, local paths, scan results, tokens or secrets are tracked in the final commit candidate
- [ ] Produce current screenshots from the release build
- [x] Create and verify the final 0.5.3 portable package and SHA-256 file
- [x] Use a portable-only alpha release; installer and code signing are deferred to a later beta or Pro edition
- [ ] Enable GitHub Private Vulnerability Reporting
- [x] Review README, privacy statement, security model and limitations for 0.5
- [ ] Create the public GitHub repository and add its remote only after approval

## Current release status

`0.5.3-alpha` is a local visibility and reversible-control prototype with a verified German and English interface, console-free standard launcher, fitted sidebar branding and explicit links to the related MalwareRadar and PrivacyRadar product pages. The manual five-second access scan is proven for process-to-folder-category association and automatic raw-trace cleanup. It must not be marketed as continuous file monitoring, proof of data exfiltration or complete protection against trackers, malware or backdoors.

Public release remains blocked by the second-machine clean test, asset-rights verification, current post-0.5.3 screenshots and the manual UAC firewall rollback test.
