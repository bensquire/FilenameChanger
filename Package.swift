// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "FilenameChanger",
    platforms: [.macOS(.v26)],
    targets: [
        // The rename engine: filenames in, proposed names out. Pure Swift,
        // no AppKit — the one piece worth testing in depth, so it imports
        // nothing that needs a window.
        .target(name: "RenameKit", path: "Sources/RenameKit"),
        // App layer as a library so the model is testable; the executable
        // below is just the @main scene declaration.
        .target(
            name: "RenameApp", dependencies: ["RenameKit"], path: "Sources/RenameApp"
        ),
        .executableTarget(
            name: "FilenameChanger", dependencies: ["RenameApp"],
            path: "Sources/FilenameChanger"
        ),
        .testTarget(
            name: "FilenameChangerTests",
            dependencies: ["RenameKit", "RenameApp"],
            path: "Tests/FilenameChangerTests"
        ),
    ]
)
