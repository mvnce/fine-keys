import CoreGraphics

enum MediaKey: Int {
    case volumeUp = 0, volumeDown = 1, brightnessUp = 2, brightnessDown = 3
}

enum KeyPolicy {
    static func flags(key: Int, flags: CGEventFlags, volume: Bool, brightness: Bool) -> CGEventFlags {
        guard let key = MediaKey(rawValue: key) else { return flags }
        let selected: Bool
        switch key {
        case .volumeUp, .volumeDown: selected = volume
        case .brightnessUp, .brightnessDown: selected = brightness
        }
        let explicit: CGEventFlags = [.maskShift, .maskAlternate, .maskCommand, .maskControl]
        guard selected, flags.intersection(explicit).isEmpty else { return flags }
        return flags.union([.maskShift, .maskAlternate])
    }
}
