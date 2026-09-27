# FineKeys contributor guidance

FineKeys is a Swift/AppKit macOS menu bar app that provides native fine-step behavior for supported brightness and volume media keys.

## Working in this repository

- Run `./scripts/test.sh` after changing Swift behavior, event handling, or tests. Fix failures caused by the requested change before finishing.
- Keep the app menu-bar-only and compatible with macOS 13 and later unless the task explicitly changes those product decisions.
- Keep build products, archives, and Xcode per-user state out of version control. `.gitignore` defines the expected exclusions.

## Privacy and input handling

- Treat global input interception as sensitive. Preserve the minimum required Accessibility event-tap scope.
- Do not add keystroke logging, analytics, network access, synthetic key posting, or third-party dependencies unless the user explicitly requests them.
- Preserve normal behavior for unsupported media keys, playback keys, mute, and explicit modifier shortcuts unless a task specifically changes it.

## Distribution and documentation

- FineKeys is configured for direct distribution, with App Sandbox disabled. Do not claim Mac App Store eligibility or weaken signing and notarization checks without current Apple documentation and explicit approval.
- Update `README.md` when user-visible behavior, setup, compatibility, privacy, or release instructions change.
- Update `VALIDATION.md` when a change adds or alters a manual release or device-validation requirement.
