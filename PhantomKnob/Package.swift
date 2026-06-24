// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PhantomKnob",
    platforms: [
        .macOS(.v13)
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
                "Model/",
                "ViewModel/",
                "View/",
                "Service/",
                "Control/",
                "Storage/",
            ]
        ),
        .testTarget(
            name: "PhantomKnobTests",
            dependencies: ["PhantomKnob"],
            path: "PhantomKnobTests"
        )
    ]
)
