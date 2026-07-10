import AppKit
import CoreGraphics
import Foundation

let currentDir = FileManager.default.currentDirectoryPath
let assetsDir = "\(currentDir)/PhantomKnob/Assets.xcassets"
let statusBarDir = "\(assetsDir)/StatusBar"
let appIconSetDir = "\(assetsDir)/AppIcon.appiconset"
let freeAppIconSetDir = "\(assetsDir)/AppIconFree.imageset"

// 1. 辅助函数：绘制右下角红色 FREE 绶带
func drawFreeRibbon(on image: NSImage) -> NSImage? {
    let size = image.size
    let S = size.width
    let freeImage = NSImage(size: size)
    freeImage.lockFocus()
    
    // 绘制原始图标
    image.draw(in: NSRect(origin: .zero, size: size))
    
    // 仅在尺寸大到足以显示绶带时进行绘制 (>= 32)
    if S >= 32 {
        guard let ctx = NSGraphicsContext.current?.cgContext else {
            freeImage.unlockFocus()
            return nil
        }
        ctx.saveGState()
        
        // 移动到右下角合适的中心点进行旋转
        let center = S * 0.78
        ctx.translateBy(x: center, y: S - center)
        ctx.rotate(by: CGFloat.pi / 4.0) // 45度
        
        // 绘制红色绶带底盘
        let ribbonW = S * 0.6
        let ribbonH = S * 0.12
        ctx.setFillColor(NSColor(red: 0.88, green: 0.42, blue: 0.46, alpha: 1.0).cgColor) // `#E06C75`
        ctx.fill(CGRect(x: -ribbonW/2, y: -ribbonH/2, width: ribbonW, height: ribbonH))
        
        // 绘制 "FREE" 白色文本
        let fontName = S >= 64 ? "Helvetica-Bold" : "Helvetica"
        let fontSize = max(5.0, S * 0.075)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont(name: fontName, size: fontSize) ?? NSFont.boldSystemFont(ofSize: fontSize),
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraphStyle
        ]
        let text = "FREE"
        let textRect = CGRect(x: -ribbonW/2, y: -fontSize * 0.6, width: ribbonW, height: fontSize * 1.2)
        text.draw(in: textRect, withAttributes: attrs)
        
        ctx.restoreGState()
    }
    
    freeImage.unlockFocus()
    return freeImage
}

// 2. 辅助函数：绘制右下角斜切单色线 (作为微型 Free 绶带，且将圆周右下角 1/4 空出)
func drawStatusBarSlash(on image: NSImage) -> NSImage? {
    let size = image.size
    let S = size.width
    let freeImage = NSImage(size: size)
    freeImage.lockFocus()
    
    // 绘制原始图标
    image.draw(in: NSRect(origin: .zero, size: size))
    
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        freeImage.unlockFocus()
        return nil
    }
    
    // 1. 在 Cocoa Y-up 坐标系下，使用 clear 模式擦除右下角 (-95° 到 5°) 范围内的圆周线
    ctx.saveGState()
    ctx.setBlendMode(.clear)
    ctx.setLineWidth(max(1.5, S / 16.0 * 2.2)) // 稍微宽于圆周线以确保擦干净
    ctx.setLineCap(.square)
    
    let center = CGPoint(x: S / 2.0, y: S / 2.0)
    let radius = S * 6.0 / 16.0
    ctx.addArc(center: center, radius: radius, startAngle: -67.5 * .pi / 180.0, endAngle: -22.5 * .pi / 180.0, clockwise: false)
    ctx.strokePath()
    ctx.restoreGState()
    
    freeImage.unlockFocus()
    return freeImage
}

// 3. 执行：转换 AppIcon
print("== Processing AppIcons ==")
let fileManager = FileManager.default
if !fileManager.fileExists(atPath: freeAppIconSetDir) {
    try? fileManager.createDirectory(atPath: freeAppIconSetDir, withIntermediateDirectories: true)
}

let appIconContentsPath = "\(appIconSetDir)/Contents.json"
let freeAppIconContentsPath = "\(freeAppIconSetDir)/Contents.json"

// 创建 AppIconFree 的 Contents.json
let appIconFreeJson = """
{
  "images" : [
    {
      "filename" : "icon_512_free.png",
      "idiom" : "mac",
      "scale" : "1x"
    },
    {
      "filename" : "icon_1024_free.png",
      "idiom" : "mac",
      "scale" : "2x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
"""
try? appIconFreeJson.write(toFile: freeAppIconContentsPath, atomically: true, encoding: .utf8)

// 转换最关键的 512px (@1x) 和 1024px (@2x) 尺寸用于 Dock 显示
for size in [512, 1024] {
    let sourceImgPath = "\(appIconSetDir)/icon_\(size).png"
    let destImgPath = "\(freeAppIconSetDir)/icon_\(size)_free.png"
    if let image = NSImage(contentsOfFile: sourceImgPath) {
        if let processed = drawFreeRibbon(on: image) {
            if let tiff = processed.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiff),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                try? pngData.write(to: URL(fileURLWithPath: destImgPath))
                print("Generated: \(destImgPath)")
            }
        }
    }
}

// 4. 执行：转换 StatusBar Icons
print("== Processing StatusBar Icons ==")
let iconNames = ["statusbar_inactive", "statusbar_activated", "statusbar_knobing"]
for name in iconNames {
    let sourceImageSet = "\(statusBarDir)/\(name).imageset"
    let destImageSet = "\(statusBarDir)/\(name)_free.imageset"
    
    if !fileManager.fileExists(atPath: destImageSet) {
        try? fileManager.createDirectory(atPath: destImageSet, withIntermediateDirectories: true)
    }
    
    // 写入 Contents.json
    let contentsJson = """
    {
      "images" : [
        {
          "filename" : "\(name)_free@1x.png",
          "idiom" : "mac",
          "scale" : "1x"
        },
        {
          "filename" : "\(name)_free@2x.png",
          "idiom" : "mac",
          "scale" : "2x"
        }
      ],
      "info" : {
        "author" : "xcode",
        "version" : 1
      },
      "properties" : {
        "template-rendering-intent" : "template"
      }
    }
    """
    try? contentsJson.write(toFile: "\(destImageSet)/Contents.json", atomically: true, encoding: .utf8)
    
    // 生成 @1x 和 @2x 带有切线版本的 png
    for scale in ["@1x", "@2x"] {
        let sourcePng = "\(sourceImageSet)/\(name)\(scale).png"
        let destPng = "\(destImageSet)/\(name)_free\(scale).png"
        if let image = NSImage(contentsOfFile: sourcePng) {
            if let processed = drawStatusBarSlash(on: image) {
                if let tiff = processed.tiffRepresentation,
                   let bitmap = NSBitmapImageRep(data: tiff),
                   let pngData = bitmap.representation(using: .png, properties: [:]) {
                    try? pngData.write(to: URL(fileURLWithPath: destPng))
                    print("Generated: \(destPng)")
                }
            }
        }
    }
}
print("== Asset generation completed successfully! ==")
