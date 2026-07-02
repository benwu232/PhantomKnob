import AppKit

let width = 500
let height = 330
let size = NSSize(width: width, height: height)
let image = NSImage(size: size)

image.lockFocus()

// Draw deep dark background
let bgRect = NSRect(origin: .zero, size: size)
let bgGradient = NSGradient(starting: NSColor(red: 0.06, green: 0.06, blue: 0.09, alpha: 1.0),
                            ending: NSColor(red: 0.02, green: 0.02, blue: 0.04, alpha: 1.0))
bgGradient?.draw(in: bgRect, angle: -45)

// Draw grid pattern (subtle background details)
NSColor(white: 1.0, alpha: 0.015).setStroke()
let path = NSBezierPath()
for x in stride(from: 0, to: width, by: 25) {
    path.move(to: NSPoint(x: CGFloat(x), y: 0))
    path.line(to: NSPoint(x: CGFloat(x), y: CGFloat(height)))
}
for y in stride(from: 0, to: height, by: 25) {
    path.move(to: NSPoint(x: 0, y: CGFloat(y)))
    path.line(to: NSPoint(x: CGFloat(width), y: CGFloat(y)))
}
path.stroke()

// Draw circles for app and application placeholders
let circleColor = NSColor(white: 1.0, alpha: 0.03)
circleColor.setFill()
NSColor(white: 1.0, alpha: 0.08).setStroke()

let appCircle = NSBezierPath(ovalIn: NSRect(x: 105, y: 110, width: 90, height: 90))
appCircle.fill()
appCircle.stroke()

let destCircle = NSBezierPath(ovalIn: NSRect(x: 305, y: 110, width: 90, height: 90))
destCircle.fill()
destCircle.stroke()

// Draw drag guide arrow in the center
let arrowPath = NSBezierPath()
arrowPath.move(to: NSPoint(x: 220, y: 160))
arrowPath.line(to: NSPoint(x: 255, y: 160))
arrowPath.line(to: NSPoint(x: 255, y: 168))
arrowPath.line(to: NSPoint(x: 280, y: 155))
arrowPath.line(to: NSPoint(x: 255, y: 142))
arrowPath.line(to: NSPoint(x: 255, y: 150))
arrowPath.line(to: NSPoint(x: 220, y: 150))
arrowPath.close()

// Let's add a gradient to the arrow
let arrowGradient = NSGradient(starting: NSColor(red: 0.04, green: 0.52, blue: 1.0, alpha: 0.9), // Blue
                               ending: NSColor(red: 0.75, green: 0.35, blue: 0.95, alpha: 0.9))  // Purple
arrowGradient?.draw(in: arrowPath, angle: 0)

// Draw placeholder text / typography
let text = "Drag Phantom Knob to Applications to install"
let font = NSFont.systemFont(ofSize: 12, weight: .semibold)
let textColor = NSColor(white: 1.0, alpha: 0.5)
let style = NSMutableParagraphStyle()
style.alignment = .center
let attributes: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: textColor,
    .paragraphStyle: style
]
let textRect = NSRect(x: 20, y: 40, width: width - 40, height: 30)
text.draw(in: textRect, withAttributes: attributes)

image.unlockFocus()

// Save to file
let args = CommandLine.arguments
let outputPath = args.count > 1 ? args[1] : "background.png"

if let tiffData = image.tiffRepresentation,
   let bitmap = NSBitmapImageRep(data: tiffData),
   let pngData = bitmap.representation(using: .png, properties: [:]) {
    try pngData.write(to: URL(fileURLWithPath: outputPath))
    print("Background image generated successfully at: \(outputPath)")
} else {
    print("Error formatting image representation.")
}
