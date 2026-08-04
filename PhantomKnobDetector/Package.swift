// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PhantomKnobDetector",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "PhantomKnobDetector", targets: ["PhantomKnobDetector"])
    ],
    targets: [
        .executableTarget(
            name: "PhantomKnobDetector",
            dependencies: [],
            path: "Sources/PhantomKnobDetector",
            resources: [
                .process("Resources")
            ],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "PhantomKnobDetectorTests",
            dependencies: ["PhantomKnobDetector"],
            path: "Tests/PhantomKnobDetectorTests"
        )
    ]
)
