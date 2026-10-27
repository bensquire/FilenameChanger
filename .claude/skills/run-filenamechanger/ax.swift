// Reads and presses FilenameChanger's controls through the Accessibility API,
// which sees what System Events can't: SwiftUI puts a control's label in
// AXDescription or AXHelp, and System Events reports both as "button".
// Compiled by driver.sh on first use; run as `ax <command> [args]`, with the
// app's bundle identifier in FILENAMECHANGER_BUNDLE_ID.
import AppKit
import ApplicationServices

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

func attribute(_ element: AXUIElement, _ name: String) -> Any? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
    return value
}

func text(_ element: AXUIElement, _ name: String) -> String {
    switch attribute(element, name) {
    case let string as String: string
    case let number as NSNumber: number.stringValue
    default: ""
    }
}

func role(_ element: AXUIElement) -> String { text(element, kAXRoleAttribute) }

func children(_ element: AXUIElement) -> [AXUIElement] {
    attribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
}

/// What a person would call the element: its title, else its description, else
/// a text's words, else the first line of its help.
func label(_ element: AXUIElement) -> String {
    var names = [kAXTitleAttribute, kAXDescriptionAttribute]
    if role(element) == kAXStaticTextRole { names.append(kAXValueAttribute) }
    for name in names {
        let value = text(element, name)
        if !value.isEmpty { return value }
    }
    return text(element, kAXHelpAttribute).components(separatedBy: "\n")[0]
}

/// Every element under `root` in window order, with its depth. The toolbar is
/// left out unless asked for: it holds Add, Remove and Clear, not the rename.
func walk(_ root: AXUIElement, toolbar: Bool = true) -> [(element: AXUIElement, depth: Int)] {
    var found: [(AXUIElement, Int)] = []
    func visit(_ element: AXUIElement, _ depth: Int) {
        if !toolbar, role(element) == kAXToolbarRole { return }
        found.append((element, depth))
        for child in children(element) { visit(child, depth + 1) }
    }
    visit(root, 0)
    return found
}

func elements(_ root: AXUIElement, roles: Set<String>, toolbar: Bool = true) -> [AXUIElement] {
    walk(root, toolbar: toolbar).map(\.element).filter { roles.contains(role($0)) }
}

guard AXIsProcessTrusted() else { fail("This terminal needs Accessibility permission.") }
let bundleID = ProcessInfo.processInfo.environment["FILENAMECHANGER_BUNDLE_ID"] ?? ""
guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first else {
    fail("FilenameChanger is not running; run: driver.sh launch")
}
let appElement = AXUIElementCreateApplication(app.processIdentifier)
guard let window = (attribute(appElement, kAXWindowsAttribute) as? [AXUIElement])?.first else {
    fail("FilenameChanger has no window")
}

/// The front window's sheet if one is showing, since its controls are the ones a
/// person can reach; otherwise the window.
let scope = children(window).first { role($0) == "AXSheet" } ?? window

func press(_ element: AXUIElement) {
    let result = AXUIElementPerformAction(element, kAXPressAction as CFString)
    guard result == .success else { fail("Pressing failed: AXError \(result.rawValue)") }
}

/// The control of one of `roles` given by its label, or by its number in window
/// order, or (for a pop-up) by its current value.
func find(_ key: String, roles: Set<String>, what: String) -> AXUIElement {
    let candidates = elements(scope, roles: roles)
    if let number = Int(key) {
        guard candidates.indices.contains(number - 1) else { fail("There are \(candidates.count) \(what)s.") }
        return candidates[number - 1]
    }
    let match =
        candidates.first { label($0) == key }
        ?? candidates.first { role($0) == kAXPopUpButtonRole && text($0, kAXValueAttribute) == key }
    guard let match else {
        let names = candidates.map(label).filter { !$0.isEmpty }
        fail("No \(what) \"\(key)\". Named ones: \(names.joined(separator: " | "))")
    }
    return match
}

/// The rename at a glance: the sheet's words if one is up, else each pop-up and
/// field, every row as "[x] old -> new", and the count under the list.
func state() {
    let all = walk(scope, toolbar: false).map(\.element)
    if scope != window {
        print("sheet: " + all.filter { role($0) == kAXStaticTextRole }.map(label).joined(separator: " | "))
        let buttons = all.filter { role($0) == kAXButtonRole }.map(label).filter { !$0.isEmpty }
        print("sheet buttons: " + buttons.joined(separator: " | "))
        return
    }
    for element in all {
        switch role(element) {
        case kAXPopUpButtonRole, kAXTextFieldRole:
            let kind = role(element) == kAXTextFieldRole ? "field" : "pop-up"
            let name = label(element).isEmpty ? "" : "\"\(label(element))\" "
            print("\(kind) \(name)= \"\(text(element, kAXValueAttribute))\"")
        case kAXRowRole:
            let cells = walk(element).map(\.element)
            let included = cells.first { role($0) == kAXCheckBoxRole }.map {
                text($0, kAXValueAttribute) == "1"
            }
            let names = cells.filter { role($0) == kAXStaticTextRole }.map { text($0, kAXValueAttribute) }
            print("\(included == false ? "[ ]" : "[x]") \(names.joined(separator: " -> "))")
        case kAXStaticTextRole where label(element).contains(" to rename"):
            print(label(element))
        default:
            break
        }
    }
}

let arguments = Array(CommandLine.arguments.dropFirst())
switch (arguments.first, arguments.count) {
case ("state", 1):
    state()
case ("tree", 1):
    // One line per element: indent, role, label, value, and "(disabled)".
    for (element, depth) in walk(scope) {
        var line = String(repeating: "  ", count: depth) + role(element)
        let name = label(element)
        if !name.isEmpty { line += " \"\(name)\"" }
        let value = text(element, kAXValueAttribute)
        if !value.isEmpty, value != name { line += " = \(value)" }
        if (attribute(element, kAXEnabledAttribute) as? Bool) == false { line += " (disabled)" }
        print(line)
    }
case ("press", 2):
    let pressable: Set<String> = [
        kAXButtonRole, kAXCheckBoxRole, kAXRadioButtonRole, kAXMenuButtonRole, kAXPopUpButtonRole,
    ]
    press(find(arguments[1], roles: pressable, what: "control"))
case ("pick", 3):
    let popUp = find(arguments[1], roles: [kAXPopUpButtonRole], what: "pop-up")
    press(popUp)
    // The menu's items appear once it has opened.
    var items: [AXUIElement] = []
    for _ in 0..<20 where items.isEmpty {
        usleep(50_000)
        items = elements(popUp, roles: [kAXMenuItemRole])
    }
    guard let item = items.first(where: { text($0, kAXTitleAttribute) == arguments[2] }) else {
        AXUIElementPerformAction(popUp, kAXCancelAction as CFString)
        let titles = items.map { text($0, kAXTitleAttribute) }.filter { !$0.isEmpty }
        fail("No item \"\(arguments[2])\". Items: \(titles.joined(separator: " | "))")
    }
    press(item)
case ("focus", 2):
    let field = find(arguments[1], roles: [kAXTextFieldRole], what: "text field")
    AXUIElementSetAttributeValue(field, kAXFocusedAttribute as CFString, kCFBooleanTrue)
case ("value", 2):
    print(text(find(arguments[1], roles: [kAXTextFieldRole], what: "text field"), kAXValueAttribute))
case ("window", 1):
    // The window's number for `screencapture -l`, which works off screen too,
    // and whether it is on screen. It is matched by frame: a pop-up leaves a
    // hidden 500 × 500 window behind that captures as blank white.
    var frame = CGRect.zero
    if let value = attribute(window, "AXFrame") as CFTypeRef?, CFGetTypeID(value) == AXValueGetTypeID() {
        // The type ID was just checked, so the cast can't fail.
        // swift-format-ignore: NeverForceUnwrap
        AXValueGetValue(value as! AXValue, .cgRect, &frame)
    }
    let list = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] ?? []
    let ours = list.first { info in
        let bounds = (info[kCGWindowBounds as String] as? NSDictionary).flatMap {
            CGRect(dictionaryRepresentation: $0)
        }
        return info[kCGWindowOwnerPID as String] as? pid_t == app.processIdentifier && bounds == frame
    }
    guard let number = ours?[kCGWindowNumber as String] as? Int else { fail("No window found") }
    print(number, ours?[kCGWindowIsOnscreen as String] as? Bool == true ? "onscreen" : "offscreen")
default:
    fail("usage: ax state | tree | press <control> | pick <pop-up> <item> | focus|value <field> | window")
}
