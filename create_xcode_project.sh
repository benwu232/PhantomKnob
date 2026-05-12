#!/bin/bash

# 创建项目目录结构
mkdir -p PhantomKnobDetector
cd PhantomKnobDetector

# 创建源代码目录
mkdir -p Sources/PhantomKnobDetector/{App,Model,ViewModel,View/Components,Service,Control,Storage}

# 创建测试目录
mkdir -p Tests/PhantomKnobDetectorTests

# 创建资源目录
mkdir -p Resources

# 创建 Package.swift
cat > Package.swift << 'EOF'
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
EOF

echo "Project structure created successfully!"
