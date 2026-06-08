// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PhantomKnobDetector",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "PhantomKnobDetector",
            targets: ["PhantomKnobDetector"]
        )
    ],
    targets: [
        .target(
            name: "PhantomKnobDetector",
            path: ".",
            sources: [
                "App/PhantomKnobDetectorApp.swift",
                "Model/",
                "ViewModel/",
                "View/",
                "Service/",
                "Control/",
                "Storage/",
            ],
            resources: [
                .process("App/bundled-rules.json")
            ]
        ),
        .testTarget(
            name: "PhantomKnobDetectorTests",
            dependencies: ["PhantomKnobDetector"],
            path: "PhantomKnobDetectorTests"
        )
    ]
)
