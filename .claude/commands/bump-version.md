---
description: Bump iOS app version (MARKETING_VERSION + CURRENT_PROJECT_VERSION) ahead of an App Store / TestFlight upload
argument-hint: <marketing_version> [build_number]
allowed-tools: Bash, Read
---

Use the `bump-version` skill to bump the iOS app version.

Arguments: `$ARGUMENTS`

## Procedure

1. Parse `$ARGUMENTS`:
   - `<marketing_version>` (required): e.g. `1.2.3` or `2.0`. Must match `N`, `N.N`, or `N.N.N`.
   - `<build_number>` (optional): explicit positive integer. If omitted, the script auto-increments the current build by 1.
   - If `$ARGUMENTS` is empty, read the current values from `Dibba.xcodeproj/project.pbxproj` and ask the user which marketing version to set before running anything.

2. Run the script from the repo root:

   ```bash
   ./scripts/set-version.sh <marketing_version> [build_number]
   ```

   Show the script's stdout (it prints `before -> after` plus the count of pbxproj entries it touched).

3. Verify the diff is sane:

   ```bash
   git diff --stat Dibba.xcodeproj/project.pbxproj
   ```

   Expect 12 line changes (6 marketing + 6 build entries) on a stock project. If the count is off, surface it instead of declaring success.

4. **Do not commit** unless the user explicitly asks.

5. End with a one-liner summary of `before -> after` for both fields and remind the user the next step is to archive in Xcode and upload to App Store Connect.

## Guardrails

- App Store Connect rejects uploads with `CURRENT_PROJECT_VERSION` ≤ an already-shipped build for the same marketing version. Auto-increment exists to avoid this — never silently downgrade.
- Marketing version may stay constant across multiple TestFlight builds; bump only when shipping a new public release.
- The script edits all six pbxproj occurrences (Debug + Release × ios/iosTests/iosUITests). If the entry counts the script reports do not match, stop and surface the mismatch.
- Never edit `project.pbxproj` directly when the script can do it.
