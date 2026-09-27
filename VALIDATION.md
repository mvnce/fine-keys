# Release validation

Do not mark a physical test passed based on compilation, tap creation, or local event fixtures.

| Gate | Status | Required evidence |
|---|---|---|
| Universal Release build | Passed | arm64 and x86_64 slices |
| Deployment target | Passed | bundle and binary minimum macOS 13.0 |
| Hardened Runtime | Passed | runtime flag in signature |
| Modifier/event fixtures | Passed | 77 assertions |
| Native key behavior | Pending | physical checks below |
| Login approval flow | Pending device test | enabled, pending approval, cancelled, denied |
| Tap creation/permission failure | Pending device test | correct UI and retry recovery |
| Intel and macOS 13 execution | Pending | hardware/OS test runs |
| Developer ID and notarization | Blocked: signing identity unavailable | signed release, accepted ticket and Gatekeeper check |
| Mac App Store | Not supported by this target | separately proven sandboxed design and review |

## Physical checks

Record the macOS version, keyboard, display, audio output, and whether MonitorControl or another key utility is running. Test away from brightness/volume endpoints.

1. Disable both options. Tap each brightness/volume direction once and note the normal step.
2. Enable both. Each direction should now make a smaller native step, comparable to pressing Option–Shift with FineKeys disabled. Verify an actual change, not just the menu status.
3. Hold each key, release it, and immediately type normally. Repeats should stop on release, with no stuck modifiers.
4. Test volume-only and brightness-only. The unchecked group must use normal steps.
5. Test Option, Shift, Option–Shift, Command, and Control combinations against the app-disabled baseline. Explicit shortcuts must retain their native behavior. Test Fn and Caps Lock as well.
6. Check mute, play/pause, track keys, ordinary typing, and menu interaction.
7. Sleep/wake, reconnect the external keyboard, and switch audio outputs. Controls must recover or report an accurate unavailable state.
8. Revoke Accessibility. Opening the menu should report permission required; otherwise the health check should detect it within roughly 30 seconds. Choose Grant Accessibility Permission and confirm that macOS presents or opens the approval flow. Grant it again and confirm recovery.
9. Enable Launch at Login, follow pending approval if requested, cancel it, and verify the system setting. Test login once enabled and again after disabling it.
10. Repeat with other media-key utilities enabled and disabled. Document unsupported conflicts; do not silently disable another app.
11. Quit FineKeys and verify native keys behave normally. Repeat using the final installed and signed bundle.

## Results

Pending user/device validation. No claims of successful hardware behavior have been made by these automated tests.
