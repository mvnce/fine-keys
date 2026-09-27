# FineKeys

A Swift/AppKit menu bar utility that adds macOS's native fine-step modifiers to unmodified volume and display-brightness media-key events. Volume and brightness have independent toggles. No networking, event logging, synthetic key posting, or third-party dependencies.

The application icon uses the refined single-key design. Its source variants are kept in `IconDesign/`, and Xcode compiles the generated multi-resolution `AppIcon` asset catalog into the application.

The setup alert is shown once for each macOS user profile. Setup & Help remains available from the menu, and missing Accessibility permission remains visible in the menu-bar status without reopening the alert on every launch.

## Status

Development build, not a public release. The app builds for Apple Silicon and Intel with a macOS 13.0 deployment target and Hardened Runtime. Native key behavior, older-OS compatibility, Intel execution, and physical sleep/wake behavior still need device testing. The event tap being active only confirms interception is enabled; it cannot prove macOS applied a smaller hardware adjustment.

## Build and test

Open `FineKeys.xcodeproj` in Xcode. The default signature is ad-hoc for local development. From this directory:

```sh
./scripts/test.sh
./scripts/package.sh development
```

Tests exercise modifier policy and unposted system-defined event objects, including down/up/repeat payload preservation. They do not press keys or change volume/brightness. Packaging checks both architectures, bundle minimum OS, and signature integrity. Build outputs go into `.build/` by default; `FINEKEYS_BUILD_DIR` and `FINEKEYS_TEST_DIR` can override it.

## Install locally

Quit any previous FineKeys copy. Unzip the development archive, move FineKeys.app to Applications, and open that copy. Grant Accessibility access to that installed copy using Setup & Help. Ad-hoc development signatures may require removing and re-adding the app in Accessibility after a rebuild. Launch at Login is optional; if approval is pending, the menu links to Login Items and offers cancellation.

## Code map for a Swift learner

- `main.swift`: AppKit lifecycle, menu actions, preferences, and ServiceManagement login items.
- `MediaKeyInterceptor.swift`: event-tap ownership, run-loop delivery, permission polling, health checks, and explicit operational states.
- `KeyPolicy.swift`: pure modifier policy and named media-key codes.
- `Tests/main.swift`: executable regression checks without external test dependencies.

State and callback lifecycle are confined to the main run loop. A borrowed `Unmanaged` pointer bridges the interceptor through the C callback; the app owns the interceptor and invalidates the tap on exit. Failed creation requires explicit retry or wake; permission is polled only while missing. An active tap has a 30-second health check for revocation, plus checks on menu opening and app activation.

## Release gates

Follow `VALIDATION.md` before publishing. Public distribution requires an Apple Developer Program account with a valid Developer ID Application certificate and notarization access. There were no valid signing identities available when this revision was built.

Store notarization credentials in Keychain with Apple's `notarytool store-credentials` workflow. Then run:

```sh
export FINEKEYS_SIGN_IDENTITY='Developer ID Application: Your Name (TEAMID)'
export FINEKEYS_NOTARY_PROFILE='your-keychain-profile'
./scripts/package.sh release
```

The release script builds a universal app, signs it with Hardened Runtime and a secure timestamp, submits it to Apple, staples and validates the ticket, checks Gatekeeper, and only then creates the final ZIP. This credential-dependent path has not been executed. Do not publish the development ZIP as a notarized release.

## Mac App Store

This target deliberately has App Sandbox disabled and is for direct distribution. It is not Mac App Store eligible as configured. Free pricing does not exempt an app from sandboxing. A supported sandboxed implementation of active global media-key modification has not been demonstrated; do not claim Store eligibility or add an unsandboxed helper to bypass the restriction.

Sources:
- https://developer.apple.com/app-store/review/guidelines/#hardware-compatibility
- https://developer.apple.com/documentation/security/protecting-user-data-with-app-sandbox
- https://developer.apple.com/developer-id/

If Store distribution is required, first ask Apple Developer Technical Support whether a sandboxed app may use a `.cgSessionEventTap`, `.defaultTap`, restricted to `.systemDefined` media-key subtype 8, to modify modifier flags in place. Explain that the app does not post synthetic events or record keys. Request a documented supported API/entitlement, then validate the signed sandboxed build on-device. A technical answer does not guarantee App Review approval.
