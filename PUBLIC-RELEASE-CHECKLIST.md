# Public release checklist

TrackerRadar is published as a clearly labelled public alpha. The remaining items below are follow-up hardening gates, not claims that the alpha is production-ready.

Official publisher: [SC LABS](https://sclabs.uk/)

## Required before publishing

- [x] Confirm product name and SC LABS branding for the alpha
- [x] Select proprietary freeware terms and include `LICENSE.md`
- [ ] Verify ownership and redistribution rights for every asset
- [x] Implement and clearly limit the manual user-folder access scan
- [x] Add and verify complete local German and English interface selection
- [x] Match the language selector to the dark rounded TrackerRadar control design
- [x] Fit both sidebar logos into their rounded frames
- [x] Hide the PowerShell console through the verified VBS launcher
- [x] Place `sclabs.uk` in the sidebar and MalwareRadar/PrivacyRadar links in the footer without background web access
- [x] Add isolated file and Registry disable/undo tests
- [x] Verify the Activities block/restore toggle against the exact firewall-rule state and matching Change Vault record
- [x] Confirm a failed Wispr Flow block attempt left no rule, no Change Vault record and no active block
- [x] Complete the prepared UAC firewall block-and-rollback test with the isolated copied `curl.exe` target
- [ ] Run a clean-checkout test on a second Windows machine
- [x] Confirm no usernames, local paths, scan results, tokens or secrets are tracked in the final commit candidate
- [ ] Produce current screenshots from the release build
- [x] Create and verify the final 0.5.5 portable package and SHA-256 file
- [x] Use a portable-only alpha release; installer and code signing are deferred to a later beta or Pro edition
- [x] Enable GitHub Private Vulnerability Reporting
- [x] Review README, privacy statement, security model and limitations for 0.5
- [x] Create the public GitHub repository and add its remote after explicit approval

## Current release status

`0.5.5-alpha` is a local visibility and reversible-control prototype with a verified German and English interface, console-free standard launcher, fitted branding and a state-aware Activities control. The control offers restore only when the exact TrackerRadar firewall rule and its matching applied Change Vault record both exist. A failed block attempt is rechecked and clearly reports when no verified rule was created. The manual five-second access scan remains limited to process-to-folder-category association and automatic raw-trace cleanup.

The public alpha is available from `https://github.com/SC-LABS-ai/TrackerRadar`. Remaining follow-up work is the second-machine clean test, asset-rights documentation and current post-0.5.5 screenshots. The isolated copied-`curl.exe` UAC firewall block/rollback proof passed with no residual rule.
