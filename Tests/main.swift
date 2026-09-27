import AppKit

var checks = 0
func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    precondition(condition(), message)
    checks += 1
}
let fine: CGEventFlags = [.maskShift, .maskAlternate]
for key in [0, 1, 2, 3] {
    check(KeyPolicy.flags(key: key, flags: [], volume: true, brightness: true) == fine, "Target key must use native fine modifiers")
    check(KeyPolicy.flags(key: key, flags: [], volume: false, brightness: false).isEmpty, "Both off must pass through")
}
check(KeyPolicy.flags(key: 0, flags: [], volume: false, brightness: true).isEmpty, "Brightness toggle must not affect volume")
check(KeyPolicy.flags(key: 2, flags: [], volume: true, brightness: false).isEmpty, "Volume toggle must not affect brightness")
for key in [7, 16, 17, 18, 99] {
    check(KeyPolicy.flags(key: key, flags: [], volume: true, brightness: true).isEmpty, "Unrelated key changed")
}
for modifier: CGEventFlags in [.maskShift, .maskAlternate, .maskControl, .maskCommand, fine] {
    check(KeyPolicy.flags(key: 0, flags: modifier, volume: true, brightness: true) == modifier, "Explicit shortcut changed")
}
for modifier: CGEventFlags in [.maskSecondaryFn, .maskAlphaShift] {
    check(KeyPolicy.flags(key: 2, flags: modifier, volume: true, brightness: true) == fine.union(modifier), "Fn/Caps Lock not preserved")
}
for key in [0, 1, 2, 3, 7, 16] {
    for state in [0xA00, 0xA01, 0xB00] {
        let payload = (key << 16) | state
        let cocoa = NSEvent.otherEvent(with: .systemDefined, location: .zero, modifierFlags: [], timestamp: 1,
            windowNumber: 0, context: nil, subtype: 8, data1: payload, data2: 42)!
        let event = cocoa.cgEvent!
        MediaKeyInterceptor.transform(event, volume: true, brightness: true)
        let result = NSEvent(cgEvent: event)!
        check(result.data1 == payload && result.data2 == 42, "Down/up/repeat payload changed")
        check(event.flags == ([0, 1, 2, 3].contains(key) ? fine : []), "Incorrect event modifiers")
        MediaKeyInterceptor.transform(event, volume: true, brightness: true)
        check(event.flags == ([0, 1, 2, 3].contains(key) ? fine : []), "Transformation must be idempotent")
    }
}
let other = NSEvent.otherEvent(with: .systemDefined, location: .zero, modifierFlags: [], timestamp: 1,
    windowNumber: 0, context: nil, subtype: 0, data1: 0, data2: 0)!.cgEvent!
MediaKeyInterceptor.transform(other, volume: true, brightness: true)
check(other.flags.isEmpty, "Non-media subtype changed")
print("Passed \(checks) checks. Native hardware behavior requires manual validation.")
