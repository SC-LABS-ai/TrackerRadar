# Public release checklist

TrackerRadar is prepared for version control but is not ready for a public release yet.

## Required before publishing

- [x] Confirm product name and SC LABS branding for the alpha
- [ ] Select a license: proprietary source-visible or open source
- [ ] Verify ownership and redistribution rights for every asset
- [ ] Complete sensitive-file access monitoring or clearly limit the claim
- [x] Add isolated file and Registry disable/undo tests
- [ ] Complete a manual UAC firewall block-and-rollback test on a harmless application
- [ ] Run a clean-checkout test on a second Windows machine
- [x] Confirm no usernames, local paths, scan results, tokens or secrets are tracked in the final commit candidate
- [ ] Produce current screenshots from the release build
- [x] Create and verify the reproducible portable package and SHA-256 file
- [ ] Decide whether code signing and an installer are required
- [ ] Enable GitHub Private Vulnerability Reporting
- [ ] Review README, privacy statement and limitations
- [ ] Create the public GitHub repository and add its remote only after approval

## Current release status

`0.4.0-alpha` is a local safe-control prototype. It may be demonstrated as a reversible proof of concept, but it must not yet be marketed as complete protection against trackers, malware or backdoors. Public release remains blocked by the license decision, second-machine clean test and manual UAC firewall rollback test.
