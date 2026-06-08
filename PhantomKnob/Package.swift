// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PhantomKnob",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "PhantomKnob",
            targets: ["PhantomKnob"]
        )
    ],
    targets: [
        .target(
            name: "PhantomKnob",
            path: ".",
            sources: [
                "App/PhantomKnobApp.swift",
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
            name: "PhantomKnobTests",
            dependencies: ["PhantomKnob"],
            path: "PhantomKnobTests"
        )
    ]
)
