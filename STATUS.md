# TrackerRadar Alpha — Status

Updated: 2026-08-06, Europe/Berlin

[Official SC LABS website](https://sclabs.uk/)

## Result

TrackerRadar `0.5.5-alpha` is complete as a portable, local Windows alpha. The latest safety pass hardened only the explicitly confirmed firewall control and restore workflow. Network visibility, file-access scanning, startup inspection, history, findings, localization, branding and launcher behaviour remain intact.

## Verified block and restore workflow

- The Activities control is disabled until a valid application is selected.
- TrackerRadar reads the exact deterministic Windows Firewall rule state for the selected executable.
- Without a rule, the control shows **Block internet access**.
- With the exact TrackerRadar rule and its matching applied Change Vault record, it shows **Restore internet access**.
- A rule without a matching safe rollback record is not removed automatically.
- After a failed block attempt, TrackerRadar checks the real rule state again and explicitly reports when nothing changed and no rollback is required.
- The elevated helper waits for its constrained local pointer and request files to avoid short timing-related file-not-found errors after UAC confirmation.

## Wispr Flow investigation

The reported Wispr Flow action was investigated read-only:

- Wispr Flow executable path present: **PASS**
- Wispr Flow running normally: **PASS**
- TrackerRadar firewall rule for Wispr Flow: **not present**
- other Wispr Flow firewall rule: **not present**
- Change Vault record: **not present**
- confirmed state: **Wispr Flow is not blocked**

No firewall rule was created or removed during the Wispr Flow diagnosis.

## Isolated firewall proof

The separate test used only a copied Windows `curl.exe` executable:

- connectivity before blocking: **3/3 targets reachable**
- exact outbound rule created and verified: **PASS**
- connectivity while blocked: **0/3 targets reachable**
- duplicate rule creation prevented: **PASS**
- matching Change Vault action restored access: **PASS**
- connectivity after restore: **3/3 targets reachable**
- residual firewall rule: **none**
- residual test change: **none**

## Verified components

- application core: **10/10 PASS**
- control helper including read-only block-state verification: **10/10 PASS**
- control UAC wrapper: **PASS**
- isolated firewall block and restore test: **PASS**
- file-access parser and privacy rules: **6/6 PASS**
- file-access UAC wrapper: **PASS**
- localization, Unicode and persistence: **8/8 PASS**
- German and English locale keys: **153/153**
- hidden launcher and visible application window: **PASS**
- six views, both languages and safe-control states: **38/38 PASS**
- GUI error output: **empty**

## Latest full regression measurement

- working set after ten seconds: **173.8 MB**
- private memory after ten seconds: **154.4 MB**
- CPU time after ten seconds: **3.59 seconds**
- target below 180 MB working set: **PASS**
- target below 200 MB working set: **PASS**

## Portable package

`Build-Portable.ps1` creates the package only after the application, control helper, UAC wrappers, file-access, localization, launcher and UI gates pass. The matching SHA-256 file is the authoritative integrity reference for the ZIP.

## Public distribution

- Repository: [SC-LABS-ai/TrackerRadar](https://github.com/SC-LABS-ai/TrackerRadar)
- Official publisher: [SC LABS](https://sclabs.uk/)
- Current release: `v0.5.5-alpha`, published as a GitHub prerelease
- Private Vulnerability Reporting: enabled

## Remaining hardening work

- Test the portable package on a second Windows computer.
- Document ownership and redistribution rights for all branding assets.
- Add current `0.5.5-alpha` screenshots.
- Update the TrackerRadar page on the official SC LABS website.

## Assessment

TrackerRadar `0.5.5-alpha` now presents the confirmed firewall state and offers restore only for safely attributable TrackerRadar changes. The isolated firewall-effect test passed with complete rollback and no residual rule. The public alpha is suitable for controlled evaluation while the remaining second-machine, asset-rights and presentation checks are completed.
