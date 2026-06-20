import AppKit

if NSImage(systemSymbolName: "repeat.badge.xmark", accessibilityDescription: nil) != nil {
    print("repeat.badge.xmark EXISTS")
} else {
    print("repeat.badge.xmark DOES NOT EXIST")
}

if NSImage(systemSymbolName: "shuffle.badge.xmark", accessibilityDescription: nil) != nil {
    print("shuffle.badge.xmark EXISTS")
} else {
    print("shuffle.badge.xmark DOES NOT EXIST")
}
