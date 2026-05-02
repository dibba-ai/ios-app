---
name: bump-version
description: Bump the iOS app version (MARKETING_VERSION + CURRENT_PROJECT_VERSION) ahead of an App Store / TestFlight upload. Wraps `scripts/set-version.sh`. Trigger when the user says "bump version", "set version", "increment build", "/bump-version", "/set-version", or asks to prepare a release. Use when the user wants to update Xcode project versions, especially before archiving.
allowed-tools: Bash, Read
---

# bump-version

Wraps `scripts/set-version.sh` to bump iOS marketing version + build number across all entries in `ios.xcodeproj/project.pbxproj`.

## When to invoke

- User asks to bump/set/change app version, marketing version, or build number
- User mentions preparing a release, App Store upload, or TestFlight upload
- User invokes `/bump-version`, `/set-version`, or similar

## Usage

The script lives at `scripts/set-version.sh` (executable). Two forms:

```bash
./scripts/set-version.sh <marketing_version>             # auto-increment build
./scripts/set-version.sh <marketing_version> <build>     # explicit build
```

`<marketing_version>` matches `N`, `N.N`, or `N.N.N` (e.g. `1.2.3`, `2.0`).
`<build>` is a positive integer.

## Procedure

1. **Resolve the marketing version.**
   - If the user supplied one (e.g. "bump to 1.2.3"), use it verbatim.
   - If they did NOT, read the current value first so you can suggest a sensible bump:
     ```bash
     grep -m1 -E '^[[:space:]]*MARKETING_VERSION = ' ios.xcodeproj/project.pbxproj
     grep -m1 -E '^[[:space:]]*CURRENT_PROJECT_VERSION = ' ios.xcodeproj/project.pbxproj
     ```
     Then ask the user which segment to bump (patch/minor/major), or propose the next patch and confirm before running.

2. **Decide on the build number.**
   - Default: omit the second arg → script auto-increments build by 1. This is the right move for most uploads.
   - If user explicitly requested a build number ("set build to 42"), pass it as the second arg.

3. **Run the script** from the repo root:
   ```bash
   ./scripts/set-version.sh <marketing_version> [build_number]
   ```
   Capture stdout — the script prints `before -> after` for both fields and the count of pbxproj entries it touched. Show this output to the user.

4. **Verify the change** by inspecting the diff:
   ```bash
   git diff --stat ios.xcodeproj/project.pbxproj
   git diff ios.xcodeproj/project.pbxproj | head -40
   ```
   Confirm the `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` lines moved to the expected values, and that the entry count matches what the script reported (six of each on a stock project — Debug + Release × ios/iosTests/iosUITests).

5. **Optional build sanity check** — only if the user asked for one or you're following the AGENTS.md quality gate. `xcodebuild` is slow; do not run it implicitly.
   ```bash
   xcodebuild -project ios.xcodeproj -scheme ios -configuration Debug \
       -destination 'generic/platform=iOS Simulator' build > /tmp/bump-build.log 2>&1
   grep -E 'BUILD FAILED|BUILD SUCCEEDED' /tmp/bump-build.log | tail -1
   ```

6. **Do not commit or push** unless the user explicitly asks. End with a one-line summary of the change and remind the user the next step is to archive in Xcode and upload to App Store Connect.

## Guardrails

- App Store Connect rejects uploads with `CURRENT_PROJECT_VERSION` ≤ an already-shipped build for the same marketing version. Auto-increment exists to prevent this — do not silently downgrade the build number.
- Marketing version may stay constant across multiple TestFlight builds (e.g. `1.0(1)`, `1.0(2)`, `1.0(3)`); bump only when shipping a new public release.
- The script edits all six pbxproj occurrences. If the entry count printed by the script is not what you expected, stop and surface it to the user — partial edits leave the project in an inconsistent state.
- Never edit `project.pbxproj` directly when the script can do it; the regex is set up to handle every casing the file uses.

## Failure modes

- "project.pbxproj not found" → user is running from outside the repo root or the file moved. Check `pwd` and `ls ios.xcodeproj/project.pbxproj`.
- "marketing version 'X' must look like 1, 1.2, or 1.2.3" → input failed validation. Re-prompt for a valid format.
- Script reports `0 entries` updated → regex did not match. Inspect the pbxproj for unusual formatting before re-running.
